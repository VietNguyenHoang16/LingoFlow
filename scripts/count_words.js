const { Pool } = require('pg');
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

(async () => {
  const total = await pool.query('SELECT COUNT(*) FROM vocabulary_words');
  const missing = await pool.query("SELECT COUNT(*) FROM vocabulary_words WHERE example_sentence IS NULL OR example_sentence = ''");
  const hasExamples = await pool.query("SELECT COUNT(*) FROM vocabulary_words WHERE example_sentence IS NOT NULL AND example_sentence != ''");
  console.log(`Total words: ${total.rows[0].count}`);
  console.log(`Missing examples: ${missing.rows[0].count}`);
  console.log(`Has examples: ${hasExamples.rows[0].count}`);
  await pool.end();
})();
