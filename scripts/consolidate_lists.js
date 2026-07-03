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
  console.log('=== Consolidate lists: 1 canonical list per category ===\n');

  const users = await query('SELECT id FROM users ORDER BY id');
  console.log(`Users: ${users.length}\n`);

  let totalListsDeleted = 0;
  let totalWordsMoved = 0;

  for (const user of users) {
    const userId = user.id;
    console.log(`--- User ${userId} ---`);

    for (const cat of CATEGORIES) {
      const existing = await query(
        'SELECT id, name FROM vocabulary_lists WHERE user_id = $1 AND category = $2 ORDER BY id LIMIT 1',
        [userId, cat],
      );

      let canonicalId;
      if (existing.length > 0) {
        canonicalId = existing[0].id;
        console.log(`  ${cat}: giu list ID=${canonicalId} ("${existing[0].name}")`);
      } else {
        const r = await query(
          'INSERT INTO vocabulary_lists (user_id, category, name) VALUES ($1, $2, $3) RETURNING id',
          [userId, cat, cat.charAt(0).toUpperCase() + cat.slice(1)],
        );
        canonicalId = r[0].id;
        console.log(`  ${cat}: tao moi list ID=${canonicalId}`);
      }

      const otherLists = await query(
        'SELECT id, name FROM vocabulary_lists WHERE user_id = $1 AND category = $2 AND id != $3 ORDER BY id',
        [userId, cat, canonicalId],
      );

      for (const other of otherLists) {
        const moved = await query(
          'UPDATE vocabulary_words SET list_id = $1 WHERE list_id = $2',
          [canonicalId, other.id],
        );
        totalWordsMoved += moved.rowCount;
        await query('DELETE FROM vocabulary_lists WHERE id = $1', [other.id]);
        totalListsDeleted++;
        console.log(`    -> gop list ID=${other.id} ("${other.name}") vao canonical (${moved.rowCount} tu)`);
      }
    }
  }

  const wc = await query('SELECT COUNT(*) AS c FROM vocabulary_words WHERE list_id IS NULL');
  if (parseInt(wc[0].c) > 0) {
    console.log(`\nXu ly ${wc[0].c} orphans...`);
    for (const row of await query('SELECT * FROM vocabulary_words WHERE list_id IS NULL')) {
      const types = (row.word_type || '').split(',').map(t => t.trim()).filter(t => CATEGORIES.includes(t));
      const cat = types.length > 0 ? types[0] : 'noun';
      const lists = await query('SELECT id FROM vocabulary_lists WHERE user_id = $1 AND category = $2 LIMIT 1', [row.user_id || 1, cat]);
      if (lists.length > 0) {
        await query('UPDATE vocabulary_words SET list_id = $1 WHERE id = $2', [lists[0].id, row.id]);
      }
    }
  }

  console.log(`\n=== Done! ===`);
  console.log(`Lists deleted: ${totalListsDeleted}`);
  console.log(`Words moved: ${totalWordsMoved}`);

  const summary = await query(`
    SELECT vl.category, COUNT(DISTINCT vw.id) AS word_count, vl.name
    FROM vocabulary_lists vl
    LEFT JOIN vocabulary_words vw ON vw.list_id = vl.id
    GROUP BY vl.id, vl.category, vl.name
    HAVING COUNT(DISTINCT vw.id) > 0
    ORDER BY vl.category
  `);
  console.log(`\nCanonical lists:`);
  for (const row of summary) {
    console.log(`  ${row.category}: ${row.word_count} tu (list: "${row.name}")`);
  }

  await pool.end();
}

main().catch(err => { console.error('Failed:', err.message); process.exit(1); });
