const { Pool } = require('pg');
const https = require('https');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

const TRANSLATION_API = 'https://api.mymemory.translated.net/get';
const DICTIONARY_API = 'https://api.dictionaryapi.dev/api/v2/entries/en';

async function query(sql, params = []) {
  const result = await pool.query(sql, params);
  return result.rows;
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch {
          resolve(null);
        }
      });
    }).on('error', () => resolve(null));
  });
}

async function getExampleFromDictionary(word) {
  try {
    const data = await fetchJson(`${DICTIONARY_API}/${encodeURIComponent(word)}`);
    if (!data || !Array.isArray(data) || data.length === 0) return null;

    const examples = [];
    for (const entry of data) {
      const meanings = entry.meanings || [];
      for (const m of meanings) {
        const defs = m.definitions || [];
        for (const d of defs) {
          if (d.example && d.example.trim().length > 10) {
            examples.push(d.example.trim());
          }
        }
      }
    }

    // Prefer shorter examples (B1-B2 level), then fallback to any
    const sorted = examples.sort((a, b) => a.length - b.length);
    return sorted.length > 0 ? sorted[0] : null;
  } catch {
    return null;
  }
}

async function translateText(text) {
  try {
    const data = await fetchJson(`${TRANSLATION_API}?q=${encodeURIComponent(text)}&langpair=en|vi`);
    if (data && data.responseStatus === 200) {
      return data.responseData.translatedText || null;
    }
  } catch {}
  return null;
}

async function main() {
  console.log('=== Add example sentences to existing words ===\n');

  const words = await query(
    "SELECT id, word FROM vocabulary_words WHERE (example_sentence IS NULL OR example_sentence = '') ORDER BY id"
  );
  console.log(`Words without example: ${words.length}\n`);

  let added = 0;
  let skipped = 0;
  let errors = 0;

  for (let i = 0; i < words.length; i++) {
    const { id, word } = words[i];
    const progress = `[${i + 1}/${words.length}]`;

    const example = await getExampleFromDictionary(word);

    if (example) {
      await query('UPDATE vocabulary_words SET example_sentence = $1 WHERE id = $2', [example, id]);
      added++;
      console.log(`${progress} OK: "${word}" -> "${example.substring(0, 80)}..."`);
    } else {
      skipped++;
      console.log(`${progress} SKIP: "${word}" - no example found`);
    }

    // Rate limiting: be nice to APIs
    await sleep(200 + Math.random() * 300);
  }

  console.log(`\n=== Done ===`);
  console.log(`Added: ${added}`);
  console.log(`Skipped: ${skipped}`);
  console.log(`Errors: ${errors}`);

  await pool.end();
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
