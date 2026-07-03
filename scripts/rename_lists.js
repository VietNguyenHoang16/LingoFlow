const { Pool } = require('pg');
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});
const labels = {
  noun:'Danh từ', verb:'Động từ', adjective:'Tính từ', adverb:'Trạng từ',
  preposition:'Giới từ', conjunction:'Liên từ', pronoun:'Đại từ',
  interjection:'Thán từ', phrasal_verb:'Phrasal Verb', idiom:'Idiom', collocation:'Collocation'
};
async function main() {
  for (const [cat, label] of Object.entries(labels)) {
    await pool.query('UPDATE vocabulary_lists SET name = $1 WHERE category = $2 AND user_id = 1', [label, cat]);
  }
  console.log('Done renaming');
  const r = await pool.query(
    'SELECT category, name, (SELECT COUNT(*) FROM vocabulary_words vw WHERE vw.list_id = vl.id) as wc FROM vocabulary_lists vl WHERE user_id = 1 ORDER BY category'
  );
  for (const row of r.rows) console.log(`${row.category}: ${row.name} (${row.wc} từ)`);
  await pool.end();
}
main().catch(e => { console.error(e); process.exit(1); });
