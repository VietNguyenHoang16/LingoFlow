const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

const PREFIX_PATTERNS = [
  { re: /^\([v]\)\s*\/\s*\([n]\)\s*/i, replace: '(v) ' },
  { re: /^\([n]\)\s*\/\s*\([v]\)\s*/i, replace: '(n) ' },
  { re: /^\(adj\)\s*\/\s*\([n]\)\s*/i, replace: '(adj) ' },
  { re: /^\([n]\)\s*\/\s*\(adj\)\s*/i, replace: '(n) ' },
  { re: /^\(prep\)\s*\/\s*\(adv\)\s*/i, replace: '(prep) ' },
  { re: /^\(adv\)\s*\/\s*\(prep\)\s*/i, replace: '(adv) ' },
  { re: /^\([v]\)\s*\/\s*\(adj\)\s*/i, replace: '(v) ' },
  { re: /^\(adj\)\s*\/\s*\([v]\)\s*/i, replace: '(adj) ' },
  { re: /^\([v]\)\s*\/\s*\([n]\)\s*\/\s*\(adj\)\s*/i, replace: '(v) ' },
  { re: /^\([n]\)\s*\/\s*\([v]\)\s*\/\s*\(adj\)\s*/i, replace: '(n) ' },
  { re: /^\(adj\)\s*\/\s*\([n]\)\s*\/\s*\([v]\)\s*/i, replace: '(adj) ' },
  { re: /^\(v\/n\)\s*/i, replace: '(v) ' },
  { re: /^\(n\/v\)\s*/i, replace: '(n) ' },
  { re: /^\(prep\/adv\)\s*/i, replace: '(prep) ' },
  { re: /^\(adv\/prep\)\s*/i, replace: '(adv) ' },
  { re: /^\(adj\/n\)\s*/i, replace: '(adj) ' },
  { re: /^\(n\/adj\)\s*/i, replace: '(n) ' },
  { re: /^\(v\/adj\)\s*/i, replace: '(v) ' },
  { re: /^\(adj\/v\)\s*/i, replace: '(adj) ' },
  { re: /^\(conj\)\s*/i, replace: '(conj) ' },
  { re: /^\(pron\)\s*/i, replace: '(pron) ' },
  { re: /^\(interj\)\s*/i, replace: '(interj) ' },
  { re: /^\(phrasal_verb\)\s*/i, replace: '(phrasal_verb) ' },
  { re: /^\(idiom\)\s*/i, replace: '(idiom) ' },
  { re: /^\(grammar\)\s*/i, replace: '(grammar) ' },
];

const TYPE_TO_PREFIX = {
  noun: '(n)',
  verb: '(v)',
  adjective: '(adj)',
  adverb: '(adv)',
  preposition: '(prep)',
  conjunction: '(conj)',
  pronoun: '(pron)',
  interjection: '(interj)',
  phrasal_verb: '(phrasal_verb)',
  idiom: '(idiom)',
  grammar: '(grammar)',
};

function cleanPrefix(meaning, wordType) {
  if (!meaning || !meaning.trim()) return meaning;
  let s = meaning.trim();
  let hadCombinedPrefix = false;

  // Try to match known combined/malformed prefixes
  for (const { re, replace } of PREFIX_PATTERNS) {
    if (re.test(s)) {
      s = s.replace(re, '');
      hadCombinedPrefix = true;
      break;
    }
  }

  if (hadCombinedPrefix) {
    const prefix = TYPE_TO_PREFIX[wordType] || '';
    return prefix ? prefix + ' ' + s : s;
  }

  // Check if it starts with a simple POS prefix matching word_type
  const correctPrefix = TYPE_TO_PREFIX[wordType];
  if (correctPrefix && s.startsWith(correctPrefix)) {
    return s; // already correct
  }

  // Check if it has a SIMPLE prefix that doesn't match word_type
  for (const [type, prefix] of Object.entries(TYPE_TO_PREFIX)) {
    if (s.startsWith(prefix) && type !== wordType) {
      // Wrong simple prefix - strip it
      s = s.slice(prefix.length).trim();
      return correctPrefix ? correctPrefix + ' ' + s : s;
    }
  }

  return meaning; // no change
}

async function main() {
  console.log('=== Fix malformed/combined prefixes in meaning ===\n');
  const rows = await pool.query(
    'SELECT id, word, word_type, meaning FROM vocabulary_words ORDER BY id'
  );
  console.log(`Total words: ${rows.rows.length}\n`);

  let fixed = 0;
  let combinedPrefix = 0;
  let wrongSimplePrefix = 0;

  for (const row of rows.rows) {
    const oldMeaning = row.meaning || '';
    const newMeaning = cleanPrefix(oldMeaning, row.word_type);
    if (newMeaning !== oldMeaning) {
      await pool.query('UPDATE vocabulary_words SET meaning = $1 WHERE id = $2', [newMeaning, row.id]);
      fixed++;
      // Determine which case
      const oldTrim = oldMeaning.trim();
      if (/^\([a-z]+\/[a-z]+\)/.test(oldTrim) || /^\([a-z]+\)\s*\/\s*\([a-z]+\)/.test(oldTrim)) {
        combinedPrefix++;
      } else {
        wrongSimplePrefix++;
      }
    }
  }

  console.log(`Fixed: ${fixed}`);
  console.log(`  Combined prefix fixed: ${combinedPrefix}`);
  console.log(`  Wrong simple prefix fixed: ${wrongSimplePrefix}`);

  // Verify final state
  const verify = await pool.query('SELECT COUNT(*)::int as c FROM vocabulary_words');
  console.log(`\nDB total: ${verify.rows[0].c}`);

  await pool.end();
}

main().catch(err => { console.error('Failed:', err.message); process.exit(1); });
