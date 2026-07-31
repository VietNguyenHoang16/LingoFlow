/**
 * Export and delete removed word types.
 *
 * Usage:
 *   node scripts/export_and_delete_removed_types.js          (export only)
 *   node scripts/export_and_delete_removed_types.js --delete (export + delete)
 *
 * Exports all words whose word_type matches any of the removed types
 * (collocation, grammar, phrasal_verb, idiom, interjection) to a JSON file,
 * then optionally deletes them from the database.
 */
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

// Manually read DATABASE_URL from .env.local
function loadEnv() {
  const envPath = path.join(process.cwd(), '.env.local');
  if (fs.existsSync(envPath)) {
    const content = fs.readFileSync(envPath, 'utf8');
    for (const line of content.split('\n')) {
      const match = line.match(/^DATABASE_URL="(.+)"$/);
      if (match) {
        process.env.DATABASE_URL = match[1];
      }
    }
  }
}
loadEnv();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

const REMOVED_WORD_TYPES = [
  'collocation', 'grammar', 'phrasal_verb', 'idiom', 'interjection', 'pronoun',
];

async function run() {
  const shouldDelete = process.argv.includes('--delete');

  // 1. Export
  const exportResult = await pool.query(
    `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details,
            vw.is_mastered, vw.is_difficult, vw.review_count, vw.correct_streak,
            vw.ease_factor, vw.interval_days, vw.next_review_date, vw.last_reviewed_at,
            vw.mastery_level, vw.lapse_count, vw.word_type, vw.created_at,
            vl.name AS list_name, vl.id AS list_id, vl.category AS list_category
     FROM vocabulary_words vw
     JOIN vocabulary_lists vl ON vw.list_id = vl.id
     WHERE vw.word_type ILIKE ANY(ARRAY[${REMOVED_WORD_TYPES.map((_, i) => `$${i+1}`).join(', ')}])
     ORDER BY vw.created_at DESC`,
    REMOVED_WORD_TYPES,
  );

  const words = exportResult.rows;
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const filename = `removed_word_types_export_${timestamp}.json`;
  const filepath = path.join(process.cwd(), filename);

  const jsonData = JSON.stringify(words, null, 2);
  fs.writeFileSync(filepath, jsonData, 'utf8');

  console.log(`\n=== Export Results ===`);
  console.log(`Total words exported: ${words.length}`);
  console.log(`File saved to: ${filepath}`);

  // Breakdown by type
  const breakdown = {};
  for (const w of words) {
    const types = (w.word_type || '').split(',');
    for (const t of types) {
      const key = t.trim() || '(unknown)';
      breakdown[key] = (breakdown[key] || 0) + 1;
    }
  }
  console.log('\nBreakdown by word_type:');
  for (const [type, count] of Object.entries(breakdown)) {
    console.log(`  ${type}: ${count}`);
  }

  // Breakdown by list
  const listBreakdown = {};
  for (const w of words) {
    const key = `${w.list_category || 'unknown'} / ${w.list_name || 'unknown'}`;
    listBreakdown[key] = (listBreakdown[key] || 0) + 1;
  }
  console.log('\nBreakdown by list:');
  for (const [list, count] of Object.entries(listBreakdown)) {
    console.log(`  ${list}: ${count}`);
  }

  // 2. Delete (only if --delete flag is passed)
  if (shouldDelete) {
    const deleteResult = await pool.query(
      `DELETE FROM vocabulary_words
       WHERE list_id IN (
         SELECT id FROM vocabulary_lists WHERE user_id = ANY(
           SELECT user_id FROM vocabulary_lists WHERE id IN (
             SELECT DISTINCT vw.list_id FROM vocabulary_words vw
             JOIN vocabulary_lists vl ON vw.list_id = vl.id
             WHERE vw.word_type ILIKE ANY(ARRAY[${REMOVED_WORD_TYPES.map((_, i) => `$${i+1}`).join(', ')}])
           )
         )
       )
       AND word_type ILIKE ANY(ARRAY[${REMOVED_WORD_TYPES.map((_, i) => `$${i+1 + REMOVED_WORD_TYPES.length}`).join(', ')}])
       RETURNING id`,
      [...REMOVED_WORD_TYPES, ...REMOVED_WORD_TYPES],
    );

    console.log(`\n=== Delete Results ===`);
    console.log(`Total words deleted: ${deleteResult.rows.length}`);
  }

  await pool.end();
}

run().catch((err) => {
  console.error('Error:', err);
  process.exit(1);
});
