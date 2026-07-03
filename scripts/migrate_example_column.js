const { Pool } = require('pg');
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

(async () => {
  try {
    await pool.query("ALTER TABLE vocabulary_words ADD COLUMN example_sentence TEXT");
    console.log('Column example_sentence added successfully');
  } catch (e) {
    if (e.code === '42701') {
      console.log('Column already exists');
    } else {
      console.error('Error:', e.message);
    }
  }
  await pool.end();
})();
