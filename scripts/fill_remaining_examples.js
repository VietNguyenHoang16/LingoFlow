const { Pool } = require('pg');
const https = require('https');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

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

function generateExample(word, definitions, pos) {
  // Try to get a clean short definition
  let def = '';
  for (const d of definitions) {
    if (d.definition && d.definition.length < 120) {
      def = d.definition.replace(/^"|"$/g, '').trim();
      break;
    }
  }

  if (!def) {
    // Fallback templates per part of speech
    const templates = {
      noun: `The ${word} played a crucial role in the situation.`,
      verb: `They decided to ${word} the project as planned.`,
      adjective: `The result was truly ${word} in every way.`,
      adverb: `She handled the situation ${word} and professionally.`,
      preposition: `${word.charAt(0).toUpperCase() + word.slice(1)} the circumstances, we had no other choice.`,
      conjunction: `${word.charAt(0).toUpperCase() + word.slice(1)} it was raining, we stayed indoors.`,
      pronoun: `${word.charAt(0).toUpperCase() + word.slice(1)} is responsible for their own actions.`,
      interjection: `${word.charAt(0).toUpperCase() + word.slice(1)}! I didn't expect to see you here.`,
      phrasal_verb: `She managed to ${word} despite the difficulties.`,
      idiom: `In this situation, ${word} is the perfect expression to use.`,
      collocation: `This is a common ${word} in academic writing.`,
    };
    return templates[pos] || templates.noun.replace(word, word);
  }

  // Clean the definition
  const cleanDef = def.charAt(0).toLowerCase() + def.slice(1).replace(/\.+$/, '');

  // Create natural example from definition
  const patterns = [
    `Something that is ${cleanDef} can be described as ${word}.`,
    `The term "${word}" refers to something ${cleanDef}.`,
  ];

  // Verb-specific patterns
  if (pos === 'verb' || cleanDef.startsWith('to ')) {
    return `You need to ${word} the relevant information before making a decision.`;
  }

  // Adjective patterns
  if (pos === 'adjective') {
    const article = ['a', 'e', 'i', 'o', 'u'].includes(cleanDef[0]) ? 'an' : 'a';
    if (cleanDef.length < 60) {
      return `It was ${article} ${cleanDef} experience that taught us ${word} lesson.`.replace('a a', 'a').replace('a an', 'an');
    }
  }

  // Noun patterns
  if (pos === 'noun' || pos === '') {
    if (cleanDef.length < 60) {
      return `${word.charAt(0).toUpperCase() + word.slice(1)} is ${article(cleanDef)} ${cleanDef} that many people encounter in daily life.`;
    }
  }

  return patterns[0];
}

function article(text) {
  if (!text) return 'a';
  return ['a', 'e', 'i', 'o', 'u'].includes(text[0].toLowerCase()) ? 'an' : 'a';
}

async function main() {
  console.log('=== Fill remaining example sentences ===\n');

  const words = await query(
    "SELECT id, word, word_type FROM vocabulary_words WHERE example_sentence IS NULL OR example_sentence = '' ORDER BY id"
  );
  console.log(`Remaining words without example: ${words.length}\n`);

  let added = 0;
  let skipped = 0;

  for (let i = 0; i < words.length; i++) {
    const { id, word, word_type } = words[i];
    const progress = `[${i + 1}/${words.length}]`;

    // Determine part of speech
    const types = (word_type || '').split(',').map(t => t.trim()).filter(Boolean);
    const pos = types[0] || 'noun';

    // Try to get definition from FreeDictionary API
    let example = null;
    const data = await fetchJson(`${DICTIONARY_API}/${encodeURIComponent(word)}`);

    if (data && Array.isArray(data) && data.length > 0) {
      // Collect all definitions
      const allDefs = [];
      for (const entry of data) {
        const meanings = entry.meanings || [];
        for (const m of meanings) {
          const defs = m.definitions || [];
          for (const d of defs) {
            if (d.example && d.example.trim().length > 10) {
              example = d.example.trim();
              break;
            }
            if (d.definition) {
              allDefs.push({ definition: d.definition, pos: m.partOfSpeech });
            }
          }
          if (example) break;
        }
        if (example) break;
      }

      // If still no example, generate from definitions
      if (!example && allDefs.length > 0) {
        example = generateExample(word, allDefs, pos);
      }
    }

    // Last resort: simple template
    if (!example) {
      const fallbacks = {
        noun: `The concept of ${word} is widely discussed in modern contexts.`,
        verb: `Many people try to ${word} their skills every day.`,
        adjective: `This situation is particularly ${word} for beginners.`,
        adverb: `She completed the task ${word} and efficiently.`,
        phrasal_verb: `It took a while, but he managed to ${word} successfully.`,
        idiom: `This ${word} is commonly used in everyday conversations.`,
        collocation: `${word.charAt(0).toUpperCase() + word.slice(1)} is a useful phrase to know.`,
      };
      example = fallbacks[pos] || `The term "${word}" is used in various contexts.`;
    }

    if (example) {
      await query('UPDATE vocabulary_words SET example_sentence = $1 WHERE id = $2', [example, id]);
      added++;
      console.log(`${progress} OK: "${word}" (${pos}) -> "${example.substring(0, 80)}..."`);
    } else {
      skipped++;
      console.log(`${progress} SKIP: "${word}"`);
    }

    await sleep(200 + Math.random() * 200);
  }

  console.log(`\n=== Done ===`);
  console.log(`Added: ${added}`);
  console.log(`Skipped: ${skipped}`);

  // Final count
  const remaining = await query("SELECT COUNT(*) FROM vocabulary_words WHERE example_sentence IS NULL OR example_sentence = ''");
  console.log(`Still missing: ${remaining[0].count}`);

  await pool.end();
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
