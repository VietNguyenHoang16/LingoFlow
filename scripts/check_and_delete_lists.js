/**
 * Check and delete empty word type lists.
 *
 * Lists with category in REMOVED_WORD_TYPES that have 0 words left
 * will be deleted from the database.
 */
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const REMOVED_WORD_TYPES = [
  'collocation', 'grammar', 'phrasal_verb', 'idiom', 'interjection', 'pronoun',
];

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

// Load DATABASE_URL from .env.local
const envPath = path.join(process.cwd(), '.env.local');
if (fs.existsSync(envPath)) {
  const content = fs.readFileSync(envPath, 'utf8');
  for (const line of content.split('\n')) {
    const match = line.match(/^DATABASE_URL="(.+)"$/);
    if (match) {
      process.env.DATABASE_URL = match[1];
      pool.options.connectionString = match[1];
    }
  }
}

async function run() {
  const shouldDelete = process.argv.includes('--delete');

  // 1. Check remaining words per list in the removed categories
  const result = await pool.query(
    `SELECT vl.id, vl.name, vl.category, COUNT(vw.id) as word_count
     FROM vocabulary_lists vl
     LEFT JOIN vocabulary_words vw ON vw.list_id = vl.id
     WHERE vl.category = ANY($1)
     GROUP BY vl.id, vl.name, vl.category
     ORDER BY vl.category`,
    [REMOVED_WORD_TYPES],
  );

  console.log('\n=== List Status After Word Deletion ===');
  if (result.rows.length === 0) {
    console.log('  No lists found with removed categories.');
  }
  for (const r of result.rows) {
    console.log(`  id=${r.id} name='${r.name}' category='${r.category}' words=${r.word_count}`);
  }

  // 2. Find empty lists to delete
  const emptyLists = result.rows.filter(r => parseInt(r.word_count) === 0);
  console.log(`\n  Empty lists to delete: ${emptyLists.length}`);

  if (shouldDelete && emptyLists.length > 0) {
    const ids = emptyLists.map(r => r.id);
    const placeholders = ids.map((_, i) => `$${i + 1}`).join(', ');
    const delResult = await pool.query(
      `DELETE FROM vocabulary_lists WHERE id IN (${placeholders}) RETURNING id`,
      ids,
    );
    console.log(`  Lists deleted: ${delResult.rows.length}`);
    console.log(`  Deleted list IDs: ${delResult.rows.map(r => r.id).join(', ')}`);
  }

  // 3. Delete the export JSON files
  if (shouldDelete) {
    const files = fs.readdirSync(process.cwd());
    const exportFiles = files.filter(f => f.startsWith('removed_word_types_export_'));
    console.log(`\n=== Cleaning Up Export Files ===`);
    for (const f of exportFiles) {
      const fullPath = path.join(process.cwd(), f);
      fs.unlinkSync(fullPath);
      console.log(`  Deleted: ${f}`);
    }
    if (exportFiles.length === 0) {
      console.log('  No export files to delete.');
    }
  }

  await pool.end();
}

run().catch((err) => {
  console.error('Error:', err);
  process.exit(1);
});
