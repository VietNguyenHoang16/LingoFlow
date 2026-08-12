const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  const content = fs.readFileSync(filePath, 'utf8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const idx = trimmed.indexOf('=');
    if (idx === -1) continue;
    const key = trimmed.slice(0, idx);
    const value = trimmed.slice(idx + 1).replace(/^['"]|['"]$/g, '');
    if (!process.env[key]) process.env[key] = value;
  }
}

loadEnvFile(path.resolve(__dirname, '..', '.env.local'));

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

(async () => {
  try {
    const sql = `
      SELECT word, word_type
      FROM vocabulary_words
      WHERE TRIM(word) <> '' AND word LIKE '% %'
      ORDER BY word_type, word;
    `;
    const result = await pool.query(sql);
    console.log('=== Danh sách cụm từ (từ có khoảng trắng) ===\n');
    console.log('Tổng số cụm từ:', result.rows.length);
    console.log('');
    for (const row of result.rows) {
      console.log(`  [${row.word_type}] ${row.word}`);
    }
    process.exit(0);
  } catch (error) {
    console.error('Lỗi kết nối database:', error.message);
    process.exit(1);
  }
})();
