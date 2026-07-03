const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

const CATEGORIES = [
  'noun', 'verb', 'adjective', 'adverb', 'preposition',
  'conjunction', 'pronoun', 'interjection', 'phrasal_verb',
  'idiom', 'collocation', 'grammar',
];

const PREFIX_MAP = {
  '(n)': 'noun',
  '(v)': 'verb',
  '(adj)': 'adjective',
  '(adv)': 'adverb',
  '(prep)': 'preposition',
  '(conj)': 'conjunction',
  '(pron)': 'pronoun',
  '(interj)': 'interjection',
  '(phrasal_verb)': 'phrasal_verb',
  '(idiom)': 'idiom',
  '(grammar)': 'grammar',
};

const REVERSE_MAP = {};
for (const [k, v] of Object.entries(PREFIX_MAP)) REVERSE_MAP[v] = k;

const KNOWN_PREPOSITIONS = new Set([
  'aboard', 'about', 'above', 'across', 'after', 'against', 'along',
  'alongside', 'amid', 'amidst', 'among', 'amongst', 'around', 'at',
  'atop', 'before', 'behind', 'below', 'beneath', 'beside', 'besides',
  'between', 'beyond', 'by', 'concerning', 'considering', 'despite',
  'down', 'during', 'except', 'excepting', 'excluding', 'following',
  'for', 'from', 'given', 'in', 'including', 'inside', 'into',
  'less', 'like', 'minus', 'near', 'next', 'notwithstanding', 'of',
  'off', 'on', 'onto', 'opposite', 'out', 'outside', 'over',
  'past', 'per', 'plus', 'pro', 'regarding', 'round', 'save',
  'since', 'than', 'through', 'throughout', 'till', 'times', 'to',
  'toward', 'towards', 'under', 'underneath', 'unlike', 'until',
  'unto', 'up', 'upon', 'versus', 'via', 'with', 'within', 'without',
  'worth',
]);

const KNOWN_CONJUNCTIONS = new Set([
  'after', 'although', 'and', 'as', 'because', 'before', 'but',
  'for', 'if', 'lest', 'nor', 'once', 'or', 'since', 'so',
  'than', 'that', 'though', 'till', 'unless', 'until', 'when',
  'whenever', 'where', 'whereas', 'wherever', 'whether', 'while',
  'yet',
]);

const KNOWN_PRONOUNS = new Set([
  'i', 'you', 'he', 'she', 'it', 'we', 'they',
  'me', 'him', 'her', 'us', 'them',
  'my', 'your', 'his', 'its', 'our', 'their',
  'mine', 'yours', 'hers', 'ours', 'theirs',
  'myself', 'yourself', 'himself', 'herself', 'itself',
  'ourselves', 'yourselves', 'themselves',
  'who', 'whom', 'whose', 'which', 'what',
  'this', 'that', 'these', 'those',
  'everybody', 'everyone', 'everything',
  'somebody', 'someone', 'something',
  'anybody', 'anyone', 'anything',
  'nobody', 'no one', 'nothing',
]);

const KNOWN_INTERJECTIONS = new Set([
  'ah', 'aha', 'alas', 'aw', 'bravo', 'bye', 'cheers',
  'congratulations', 'darn', 'drat', 'eek', 'eh',
  'eureka', 'goodbye', 'goodness', 'gosh', 'great',
  'ha', 'hallelujah', 'hello', 'hey', 'hi', 'hooray',
  'huh', 'hurray', 'indeed', 'jeez', 'no', 'oh',
  'ooh', 'oops', 'ouch', 'ow', 'oy', 'phew',
  'please', 'really', 'shit', 'shh', 'sorry', 'thanks',
  'there', 'ugh', 'uh', 'uh-oh', 'um', 'voila',
  'welcome', 'well', 'whoa', 'wow', 'yahoo', 'yeah', 'yes',
  'yikes', 'yippee', 'yuck',
]);

const EMPTY_WORD_MAP = {
  'client-facing': 'adjective',
  'dose': 'noun',
  'flap': 'verb',
  'i get it': 'idiom',
  'rip it out': 'phrasal_verb',
  'tight': 'adjective',
};

function extractPosPrefix(text) {
  if (!text) return null;
  const trimmed = text.trim();
  for (const [prefix] of Object.entries(PREFIX_MAP)) {
    if (trimmed.startsWith(prefix)) return PREFIX_MAP[prefix];
  }
  return null;
}

function stripPosPrefix(text) {
  if (!text) return '';
  let t = text.trim();
  for (const [prefix] of Object.entries(PREFIX_MAP)) {
    if (t.startsWith(prefix)) {
      t = t.slice(prefix.length).trim();
      break;
    }
  }
  return t;
}

function extractContentForType(text, targetType) {
  if (!text) return null;
  const prefix = REVERSE_MAP[targetType];
  if (!prefix) return null;
  const lines = text.split('\n').map(l => l.trim()).filter(l => l);
  for (const line of lines) {
    if (line.startsWith(prefix)) return stripPosPrefix(line);
  }
  return null;
}

function bestTypeFromApi(word, wordTypeStr) {
  const types = wordTypeStr.split(',').map(t => t.trim()).filter(t => t && CATEGORIES.includes(t));
  if (types.length === 0) return null;
  if (types.length === 1) return types[0];
  const lower = word.toLowerCase();
  if (types.includes('preposition') && KNOWN_PREPOSITIONS.has(lower)) return 'preposition';
  if (types.includes('conjunction') && KNOWN_CONJUNCTIONS.has(lower)) return 'conjunction';
  if (types.includes('pronoun') && KNOWN_PRONOUNS.has(lower)) return 'pronoun';
  if (types.includes('interjection') && KNOWN_INTERJECTIONS.has(lower)) return 'interjection';
  if (types.includes('verb')) return 'verb';
  if (types.includes('adjective')) return 'adjective';
  if (types.includes('adverb')) return 'adverb';
  return 'noun';
}

async function query(sql, params = []) {
  const result = await pool.query(sql, params);
  return result.rows;
}

async function main() {
  console.log('=== Re-classify: use meaning POS prefix as ground truth ===\n');

  const words = await query(
    'SELECT id, word, word_type, meaning, full_details FROM vocabulary_words ORDER BY id'
  );
  console.log(`Total words: ${words.length}\n`);

  let byMeaning = 0, byApi = 0, byEmpty = 0;
  const typeChanges = {};
  let swappedMeaning = 0;

  for (const w of words) {
    const oldType = (w.word_type || '').trim();
    const oldMeaning = w.meaning || '';
    const oldDetails = w.full_details || '';
    let newType;

    // 1) Determine new word_type
    if (oldType === '') {
      newType = EMPTY_WORD_MAP[w.word.toLowerCase()] || 'noun';
      byEmpty++;
    } else {
      const meaningType = extractPosPrefix(oldMeaning);
      if (meaningType && CATEGORIES.includes(meaningType)) {
        newType = meaningType;
        byMeaning++;
      } else {
        newType = bestTypeFromApi(w.word, oldType);
        byApi++;
      }
    }

    // 2) Update word_type if changed
    if (newType !== oldType) {
      typeChanges[oldType] = typeChanges[oldType] || {};
      typeChanges[oldType][newType] = (typeChanges[oldType][newType] || 0) + 1;
      await query('UPDATE vocabulary_words SET word_type = $1 WHERE id = $2', [newType, w.id]);
    }

    // 3) Fix meaning to match word_type
    const meaningType = extractPosPrefix(oldMeaning);
    let newMeaning = oldMeaning;
    let newDetails = oldDetails;

    if (meaningType && meaningType !== newType) {
      // Meaning has wrong POS prefix - try to swap from full_details
      const correctContent = extractContentForType(oldDetails, newType);
      if (correctContent) {
        const wrongContent = stripPosPrefix(oldMeaning);
        const newPrefix = REVERSE_MAP[newType];
        newMeaning = newPrefix + ' ' + correctContent;
        // Remove the extracted content from full_details
        const detailsLines = oldDetails.split('\n').map(l => l.trim()).filter(l => l);
        const keptLines = detailsLines.filter(l => !l.startsWith(REVERSE_MAP[newType]));
        // Add old meaning content to details if not already there
        const wrongPrefix = REVERSE_MAP[meaningType];
        if (wrongContent && wrongPrefix) {
          keptLines.push(wrongPrefix + ' ' + wrongContent);
        }
        newDetails = keptLines.join('\n');
        swappedMeaning++;
      } else {
        // No matching content in details - just strip wrong prefix
        newMeaning = stripPosPrefix(oldMeaning);
      }
      await query(
        'UPDATE vocabulary_words SET meaning = $1, full_details = $2 WHERE id = $3',
        [newMeaning, newDetails, w.id]
      );
    }
  }

  console.log(`\nClassification source:`);
  console.log(`  By meaning prefix: ${byMeaning}`);
  console.log(`  By API heuristic:  ${byApi}`);
  console.log(`  By empty map:      ${byEmpty}`);
  console.log(`  Total:             ${byMeaning + byApi + byEmpty}`);

  console.log(`\nType changes:`);
  for (const [from, tos] of Object.entries(typeChanges)) {
    for (const [to, count] of Object.entries(tos)) {
      console.log(`  ${from.padEnd(15)} -> ${to.padEnd(15)} ${count}`);
    }
  }

  console.log(`\nMeaning swapped (wrong POS → correct POS): ${swappedMeaning}`);

  // Final distribution
  const dist = await query('SELECT word_type, COUNT(*)::int as cnt FROM vocabulary_words GROUP BY word_type ORDER BY cnt DESC');
  console.log(`\n=== Final Distribution ===`);
  let total = 0;
  for (const row of dist) {
    console.log(`  ${row.word_type.padEnd(15)} ${row.cnt}`);
    total += row.cnt;
  }
  console.log(`  ${'-'.repeat(20)}`);
  console.log(`  TOTAL             ${total}`);

  const empties = await query("SELECT word FROM vocabulary_words WHERE word_type IS NULL OR word_type = ''");
  if (empties.length > 0) {
    console.log(`\nWARNING: ${empties.length} words still empty!`);
    empties.forEach(e => console.log(`  ${e.word}`));
  } else {
    console.log('\nNo empty word_type left.');
  }

  await pool.end();
}

main().catch(err => { console.error('Failed:', err.message); process.exit(1); });
