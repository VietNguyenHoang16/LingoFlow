// Sua cau vi du bi trung cho mot tai khoan.
//
// Truoc day templateExample() chi co 1 cau co dinh cho moi loai tu, nen mot lo
// import 100 danh tu tao ra 100 cau giong het nhau ("The X was easy to
// recognize."). Script nay:
//   1. Nap tat ca tu cua user, nhom cau theo "skeleton" = cau da bo tu dich.
//   2. Danh dau moi nhom co > 1 cau, plus ca nhom khop voi template cu.
//   3. Sinh lai bang template bank moi, dedupe voi tat ca cau con lai.
//
// Mac dinh chi bao cao (dry-run). Them --apply de ghi vao DB.
//
// Tai khoan mac dinh: 0375098325. Dung --phone de doi.
// VD: node scripts/fix_duplicate_examples.js
//     node scripts/fix_duplicate_examples.js --apply --limit 200
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

const { templateExample, normalizeSentenceKey } = require('../api/_lib/xai');

// Template cu bi loai khoi bank nen cau nao khop deu la cau can sua.
const LEGACY_CLAICHES = [
  'the {w} was easy to recognize.',
  'i try to {w} every day.',
  'i need to {w} before dinner.',
  'the weather is {w} today.',
  'she answered {w} during the meeting.',
  'the keys are {w} the book.',
  'i stayed home {w} it was raining.',
  '{w} is waiting outside.',
  '"{w}!" she shouted.',
  'we use "{w}" in everyday conversation.',
  'this sentence uses "{w}" correctly.',
  'i learned the expression "{w}" today.',
];

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

// Bo tu dich khoi cau -> cau con lai dung de so sanh 2 tu co cung khuon
// cau hay khong. "The window was easy to recognize." va "The table was easy to
// recognize." cung rut gon ve mot skeleton.
//
// Dung regex gom ca cum tu (escape tung chu) nen "give up" rut gon thanh mot
// {w}, khong bi tach thanh hai {w} {w}.
function skeletonOf(sentence, word) {
  const base = normalizeSentenceKey(sentence);
  const target = String(word || '').trim().toLowerCase().replace(/\s+/g, ' ');
  if (!target) return base;
  const escaped = target.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return base.replace(new RegExp(escaped, 'g'), '{w}').replace(/\s+/g, ' ').trim();
}

// Ke hoach sua cho mot danh sach tu: giu cac cau khong sua vao `used` roi
// sinh lai cac tu bi trung. Tach rieng de test duoc khong can DB.
function planFixes(words, toFix) {
  const used = new Set();
  for (const row of words) {
    if (!toFix.has(row.id)) used.add(normalizeSentenceKey(row.example_sentence));
  }
  return [...toFix.values()].map(({ row }) => ({
    row,
    next: templateExample(
      { word: row.word, meaning: row.meaning || '', wordType: row.word_type || '' },
      { used },
    ),
  }));
}

module.exports = { groupBySkeleton, planFixes, skeletonOf, LEGACY_CLAICHES };

if (require.main !== module) return;


async function findUser(phone) {
  const { rows } = await pool.query('SELECT id, phone_number FROM users WHERE phone_number = $1 LIMIT 1', [phone]);
  if (rows.length === 0) throw new Error(`Khong tim thay tai khoan ${phone}`);
  return rows[0];
}

async function loadWords(userId, limit) {
  const params = [userId];
  let sql = `SELECT vw.id, vw.word, vw.meaning, vw.word_type, vw.example_sentence,
                    vw.example_translation, vw.example_target
             FROM vocabulary_words vw
             JOIN vocabulary_lists vl ON vw.list_id = vl.id
             WHERE vl.user_id = $1 AND COALESCE(vw.example_sentence, '') <> ''`;
  if (limit > 0) {
    params.push(limit);
    sql += ` ORDER BY vw.id LIMIT $${params.length}`;
  } else {
    sql += ' ORDER BY vw.id';
  }
  const { rows } = await pool.query(sql, params);
  return rows;
}

function groupBySkeleton(words) {
  const groups = new Map();
  for (const row of words) {
    const key = skeletonOf(row.example_sentence, row.word);
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(row);
  }
  return groups;
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  const apply = Boolean(args.apply);
  const limit = Number(args.limit) > 0 ? Number(args.limit) : 0;
  const phone = phoneNumber(args.phone || '0375098325');

  const user = await findUser(phone);
  const words = await loadWords(user.id, limit);
  console.log(`Tai khoan ${user.phone_number} (id=${user.id}) - ${words.length} tu co cau vi du\n`);

  const groups = groupBySkeleton(words);
  const duplicates = [...groups.entries()].filter(([, rows]) => rows.length > 1);
  const cliches = [...groups.entries()].filter(([key]) => LEGACY_CLAICHES.includes(key));

  console.log('=== TRUOC KHI SUA ===');
  console.log(`Nhom cau bi trung: ${duplicates.length}`);
  console.log(`Nhom khop template cu: ${cliches.length}`);
  const toFix = new Map();
  for (const [key, rows] of [...duplicates, ...cliches]) {
    for (const row of rows) toFix.set(row.id, { row, skeleton: key });
  }
  console.log(`So tu se sua: ${toFix.size}\n`);

  for (const [key, rows] of duplicates.slice(0, 5)) {
    console.log(`  "${key}" x${rows.length}`);
    console.log(`    vi du: ${rows[0].example_sentence}`);
  }
  if (duplicates.length > 5) console.log(`  ... va ${duplicates.length - 5} nhom khac`);

  if (toFix.size === 0) {
    console.log('\nKhong co cau nao bi trung. Khong can sua.');
    return;
  }

  // Cau cua cac tu KHONG sua lai duoc giu trong `used` de cau moi sinh ra
  // khong trung voi chung (vi du: tu do co cau AI rieng).
  const plan = planFixes(words, toFix);

  console.log('\n=== SAU KHI SUA ===');
  console.log(`Se tao ${new Set(plan.map((p) => normalizeSentenceKey(p.next.sentence))).size} cau khac nhau cho ${plan.length} tu`);
  for (const item of plan.slice(0, 5)) {
    console.log(`  ${item.row.word}: "${item.row.example_sentence}"`);
    console.log(`      -> "${item.next.sentence}"`);
  }
  if (plan.length > 5) console.log(`  ... va ${plan.length - 5} tu khac`);

  if (!apply) {
    console.log('\n[DRY-RUN] Chua ghi gi vao DB. Chay lai voi --apply de luu.');
    return;
  }

  let saved = 0;
  for (const item of plan) {
    await pool.query(
      `UPDATE vocabulary_words
       SET example_sentence = $1, example_translation = $2, example_target = $3
       WHERE id = $4`,
      [item.next.sentence, item.next.translation, item.next.target, item.row.id],
    );
    saved += 1;
  }
  console.log(`\nDa luu ${saved} cau vi du moi.`);
}

run()
  .then(() => pool.end())
  .catch(async (error) => {
    console.error(error.message);
    await pool.end();
    process.exitCode = 1;
  });
