const BASE_URL = process.env.LINGOFLOW_API_URL || 'https://vocab-virid.vercel.app';
const PAGE_SIZE = 100;
const WORKERS = 4;

// Dung chung template bank + bo phan loai voi api/_lib/xai.js. Truoc day file
// nay copy rieng mot bo template cau dinh, nen cau sinh ra hay bi trung.
const { templateExample, normalizeSentenceKey } = require('../api/_lib/xai');

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    if (!argv[i].startsWith('--')) continue;
    const key = argv[i].slice(2);
    args[key] = argv[i + 1]?.startsWith('--') ? true : (argv[i + 1] ?? true);
    if (args[key] !== true) i += 1;
  }
  return args;
}

function phoneNumber(raw) {
  let digits = String(raw || '').replace(/\D/g, '');
  if (digits.length === 10 && digits.startsWith('0')) digits = digits.slice(1);
  if (digits.length !== 9) throw new Error('Phone must contain 9 digits.');
  return `+84${digits}`;
}

async function fetchJson(url, options = {}, retries = 3, timeoutMs = 12000) {
  let lastError;
  for (let attempt = 0; attempt < retries; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(url, { ...options, signal: controller.signal });
      const text = await response.text();
      let data;
      try { data = JSON.parse(text); } catch (_) { data = null; }
      if (!response.ok) throw new Error(data?.error?.message || `HTTP ${response.status}`);
      return data;
    } catch (error) {
      lastError = error;
    } finally {
      clearTimeout(timeout);
    }
    await new Promise((resolve) => setTimeout(resolve, 250 * (attempt + 1)));
  }
  throw lastError;
}

async function dictionaryExample(word) {
  try {
    const entries = await fetchJson(
      `https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(word)}`,
      { headers: { 'user-agent': 'LingoFlow example importer' } },
      1,
      5000,
    );
    if (!Array.isArray(entries)) return null;
    return entries
      .flatMap((entry) => entry.meanings || [])
      .flatMap((meaning) => meaning.definitions || [])
      .map((definition) => definition.example)
      .find((example) => typeof example === 'string' && example.trim()) || null;
  } catch (_) {
    return null;
  }
}

async function translate(sentence) {
  try {
    const url = 'https://translate.google.com/translate_a/single?client=gtx&sl=en&tl=vi&dt=t&q='
      + encodeURIComponent(sentence);
    const data = await fetchJson(url, { headers: { 'user-agent': 'LingoFlow example importer' } }, 1, 5000);
    const result = (data?.[0] || []).map((part) => part?.[0] || '').join('').trim();
    return result || null;
  } catch (_) {
    return null;
  }
}

function includesTarget(sentence, word) {
  return sentence.toLocaleLowerCase().includes(word.toLocaleLowerCase());
}

// `used` dung chung cho ca lo chay: fallback sinh cau chua tung dung va
// cau tu dictionary cung duoc ghi vao de lo sau khong chon trung.
async function createExample(row, used) {
  const fallback = templateExample(
    { word: row.word, meaning: row.meaning || '', wordType: row.type || '' },
    { used },
  );
  const dictionarySentence = await dictionaryExample(row.word);
  if (!dictionarySentence || !includesTarget(dictionarySentence, row.word)) {
    return { ...fallback, target: row.word, source: 'fallback' };
  }
  const key = normalizeSentenceKey(dictionarySentence);
  if (used.has(key)) return { ...fallback, target: row.word, source: 'fallback' };

  const translation = await translate(dictionarySentence);
  used.add(key);
  return {
    sentence: dictionarySentence.trim(),
    translation: translation || fallback.translation,
    target: row.word,
    source: translation ? 'dictionary' : 'dictionary-no-translation',
  };
}

async function login(phone) {
  const result = await fetchJson(`${BASE_URL}/api/lingoflow`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ action: 'loginUser', data: { phoneNumber: phoneNumber(phone) } }),
  });
  if (!result.data?.token) throw new Error('Login failed or phone is not registered.');
  return result.data.token;
}

async function loadMissingWords(token) {
  const rows = [];
  let page = 1;
  let totalPages = 1;
  while (page <= totalPages) {
    const result = await fetchJson(
      `${BASE_URL}/api/examples?page=${page}&pageSize=${PAGE_SIZE}&hasExample=false`,
      { headers: { authorization: `Bearer ${token}` } },
    );
    const pageData = result.data || {};
    rows.push(...(pageData.data || []));
    totalPages = pageData.pagination?.totalPages || page;
    process.stdout.write(`Loaded page ${page}/${totalPages}\r`);
    page += 1;
  }
  process.stdout.write('\n');
  return rows;
}

async function saveExample(token, row, example) {
  await fetchJson(`${BASE_URL}/api/words/${row.id}/example`, {
    method: 'PUT',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify({ sentence: example.sentence, translation: example.translation, target: example.target }),
  });
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const token = await login(args.phone);
  let rows = await loadMissingWords(token);
  if (args.limit && Number(args.limit) > 0) rows = rows.slice(0, Number(args.limit));
  if (rows.length === 0) {
    console.log('No missing examples.');
    return;
  }

  const dryRun = Boolean(args['dry-run']);
  let cursor = 0;
  let saved = 0;
  let dictionary = 0;
  let fallback = 0;
  const failures = [];
  // Chung cho ca lo chay: moi tu chi nhan 1 cau, khong trung voi nhau.
  const used = new Set();
  async function worker() {
    while (true) {
      const index = cursor++;
      if (index >= rows.length) return;
      const row = rows[index];
      try {
        const example = await createExample(row, used);
        if (example.source === 'dictionary') dictionary += 1;
        else fallback += 1;
        if (!dryRun) await saveExample(token, row, example);
        saved += 1;
        if (saved <= 5 || saved % 25 === 0) {
          console.log(`${dryRun ? 'Preview' : 'Saved'} ${saved}/${rows.length}: ${row.word}`);
          if (saved <= 3) console.log(`  ${example.sentence} = ${example.translation}`);
        }
      } catch (error) {
        failures.push({ id: row.id, word: row.word, error: error.message });
      }
    }
  }
  await Promise.all(Array.from({ length: Math.min(WORKERS, rows.length) }, worker));
  console.log(JSON.stringify({ requested: rows.length, saved, dictionary, fallback, failures }, null, 2));
  if (failures.length > 0) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
