const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

const POS_MAP = {
  'noun': 'noun',
  'verb': 'verb',
  'adjective': 'adjective',
  'adverb': 'adverb',
  'preposition': 'preposition',
  'conjunction': 'conjunction',
  'pronoun': 'pronoun',
  'interjection': 'interjection',
  'exclamation': 'interjection',
};

async function query(sql, params = []) {
  const result = await pool.query(sql, params);
  return result.rows;
}

async function fetchWordType(word) {
  const url = `https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(word)}`;
  const resp = await fetch(url, { signal: AbortSignal.timeout(5000) });
  if (!resp.ok) return null;
  const data = await resp.json();
  if (!Array.isArray(data) || data.length === 0) return null;
  const types = new Set();
  for (const entry of data) {
    const meanings = entry.meanings || [];
    for (const m of meanings) {
      const pos = (m.partOfSpeech || '').toLowerCase().trim();
      const key = POS_MAP[pos];
      if (key) types.add(key);
    }
  }
  return types.size > 0 ? [...types].join(',') : null;
}

async function main() {
  const rows = await query(
    "SELECT id, word FROM vocabulary_words WHERE word_type IS NULL OR word_type = '' ORDER BY id"
  );
  console.log(`Found ${rows.length} words without word_type\n`);

  let classified = 0;
  let failed = 0;

  for (let i = 0; i < rows.length; i++) {
    const { id, word } = rows[i];
    process.stdout.write(`[${i + 1}/${rows.length}] "${word}"... `);
    try {
      const wordType = await fetchWordType(word);
      if (wordType) {
        await query('UPDATE vocabulary_words SET word_type = $1 WHERE id = $2', [wordType, id]);
        console.log(`-> ${wordType}`);
        classified++;
      } else {
        console.log('-> (no type found)');
        failed++;
      }
    } catch (err) {
      console.log(`-> ERROR: ${err.message}`);
      failed++;
    }
    await new Promise(r => setTimeout(r, 200));
  }

  console.log(`\nDone. Classified: ${classified}, Failed/skipped: ${failed}`);
  await pool.end();
}

main().catch(err => { console.error(err); process.exit(1); });
