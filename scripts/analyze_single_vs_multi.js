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
      SELECT
        word_type,
        COUNT(*) FILTER (WHERE TRIM(word) <> '' AND word NOT LIKE '% %') AS single_word_count,
        COUNT(*) FILTER (WHERE TRIM(word) <> '' AND word LIKE '% %') AS multi_word_count,
        COUNT(*) AS total
      FROM vocabulary_words
      GROUP BY word_type
      ORDER BY word_type;
    `;
    const result = await pool.query(sql);
    console.log('=== Phân loại từ đơn vs cụm từ ===\n');
    console.log('word_type | single | multi | total');
    console.log('----------|--------|-------|------');
    let grandSingle = 0, grandMulti = 0, grandTotal = 0;
    for (const row of result.rows) {
      const wc = parseInt(row.single_word_count) || 0;
      const mc = parseInt(row.multi_word_count) || 0;
      const tc = parseInt(row.total) || 0;
      grandSingle += wc; grandMulti += mc; grandTotal += tc;
      console.log(`${String(row.word_type || '').padEnd(9)} | ${String(wc).padStart(6)} | ${String(mc).padStart(5)} | ${tc}`);
    }
    console.log('----------|--------|-------|------');
    console.log(`${'TOTAL'.padEnd(9)} | ${String(grandSingle).padStart(6)} | ${String(grandMulti).padStart(5)} | ${grandTotal}\n`);
    console.log(`Tổng từ đơn: ${grandSingle}`);
    console.log(`Tổng cụm từ: ${grandMulti}`);
    process.exit(0);
  } catch (error) {
    console.error('Lỗi kết nối database:', error.message);
    process.exit(1);
  }
})();
