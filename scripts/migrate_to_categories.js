const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

const CATEGORIES = [
  'noun', 'verb', 'adjective', 'adverb', 'preposition',
  'conjunction', 'pronoun', 'interjection', 'phrasal_verb',
  'idiom', 'collocation', 'grammar',
];

async function query(sql, params = []) {
  const result = await pool.query(sql, params);
  return result.rows;
}

async function main() {
  console.log('=== Migration: Groups/Sets -> Categories/Lists ===\n');

  console.log('1. Creating vocabulary_lists table...');
  await query(`
    CREATE TABLE IF NOT EXISTS vocabulary_lists (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id),
      category VARCHAR(50) NOT NULL,
      name VARCHAR(255) NOT NULL,
      word_count INTEGER DEFAULT 0,
      progress INTEGER DEFAULT 0,
      last_practiced TIMESTAMP,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
  await query(`
    CREATE INDEX IF NOT EXISTS idx_vocabulary_lists_user_category
    ON vocabulary_lists(user_id, category)
  `);

  console.log('2. Adding list_id column...');
  const colCheck = await query(
    "SELECT column_name FROM information_schema.columns WHERE table_name = 'vocabulary_words' AND column_name = 'list_id'",
  );
  if (colCheck.length === 0) {
    await query('ALTER TABLE vocabulary_words ADD COLUMN list_id INTEGER REFERENCES vocabulary_lists(id) ON DELETE CASCADE');
  }

  console.log('3. Migrating sets -> lists...');
  const sets = await query(`
    SELECT vs.*, vg.user_id, vg.name AS group_name
    FROM vocabulary_sets vs
    JOIN vocabulary_groups vg ON vs.group_id = vg.id
    ORDER BY vs.id
  `);
  console.log('   Found ' + sets.length + ' sets');

  let totalLists = 0;
  let totalWords = 0;

  for (const set of sets) {
    const setWords = await query('SELECT * FROM vocabulary_words WHERE set_id = $1', [set.id]);
    const byCat = {};
    for (const word of setWords) {
      const types = (word.word_type || '').split(',').map(t => t.trim()).filter(t => CATEGORIES.includes(t));
      const cats = types.length > 0 ? types : ['noun'];
      for (const cat of cats) {
        if (!byCat[cat]) byCat[cat] = [];
        byCat[cat].push(word);
      }
    }
    for (const [category, words] of Object.entries(byCat)) {
      const r = await query(
        'INSERT INTO vocabulary_lists (user_id, category, name, word_count, progress, last_practiced) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id',
        [set.user_id, category, set.name, words.length, set.progress || 0, set.last_practiced || new Date()],
      );
      totalLists++;
      for (const w of words) {
        await query('UPDATE vocabulary_words SET list_id = $1 WHERE id = $2', [r[0].id, w.id]);
        totalWords++;
      }
    }
  }
  console.log('   Created ' + totalLists + ' lists, assigned ' + totalWords + ' words');

  console.log('4. Orphan words...');
  const orphans = await query('SELECT * FROM vocabulary_words WHERE list_id IS NULL');
  for (const word of orphans) {
    const types = (word.word_type || '').split(',').map(t => t.trim()).filter(t => CATEGORIES.includes(t));
    const cat = types.length > 0 ? types[0] : 'noun';
    let lists = await query('SELECT id FROM vocabulary_lists WHERE user_id = $1 AND category = $2 AND name = $3', [word.user_id || 1, cat, 'Tu vung moi']);
    if (lists.length === 0) {
      const r = await query('INSERT INTO vocabulary_lists (user_id, category, name) VALUES ($1, $2, $3) RETURNING id', [word.user_id || 1, cat, 'Tu vung moi']);
      lists = r;
      totalLists++;
    }
    await query('UPDATE vocabulary_words SET list_id = $1 WHERE id = $2', [lists[0].id, word.id]);
    totalWords++;
  }
  if (orphans.length > 0) console.log('   Assigned ' + orphans.length + ' orphans');

  console.log('5. Dropping old tables...');
  await query('ALTER TABLE vocabulary_words DROP COLUMN IF EXISTS set_id');
  await query('DROP TABLE IF EXISTS vocabulary_sets CASCADE');
  await query('DROP TABLE IF EXISTS vocabulary_groups CASCADE');

  console.log('6. Verification:');
  const lc = await query('SELECT COUNT(*) AS c FROM vocabulary_lists');
  const wc = await query('SELECT COUNT(*) AS c FROM vocabulary_words');
  const oc = await query('SELECT COUNT(*) AS c FROM vocabulary_words WHERE list_id IS NULL');
  console.log('   Lists: ' + lc[0].c + ', Words: ' + wc[0].c + ', Orphans: ' + oc[0].c);
  const bc = await query('SELECT category, COUNT(*) AS c FROM vocabulary_lists GROUP BY category ORDER BY c DESC');
  for (const row of bc) console.log('     ' + row.category + ': ' + row.c);
  console.log('\n=== Migration complete! ===');
}

main().catch(err => { console.error('Migration failed:', err.message); process.exit(1); }).finally(() => pool.end());
