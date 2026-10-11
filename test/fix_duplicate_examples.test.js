const assert = require('node:assert/strict');
const test = require('node:test');

const {
  groupBySkeleton,
  planFixes,
  skeletonOf,
  LEGACY_CLAICHES,
} = require('../scripts/fix_duplicate_examples');
const { normalizeSentenceKey } = require('../api/_lib/xai');

// Mo phong chinh xac loi gap nghien: 10 danh tu cung duoc gan mot cau co dinh.
const STALE_ROWS = [
  { id: 1, word: 'table', meaning: '(n) cái bàn', word_type: 'noun', example_sentence: 'The table was easy to recognize.' },
  { id: 2, word: 'window', meaning: '(n) cửa sổ', word_type: 'noun', example_sentence: 'The window was easy to recognize.' },
  { id: 3, word: 'garden', meaning: '(n) vườn', word_type: 'noun', example_sentence: 'The garden was easy to recognize.' },
  { id: 4, word: 'river', meaning: '(n) con sông', word_type: 'noun', example_sentence: 'The river was easy to recognize.' },
  { id: 5, word: 'sleep', meaning: '(v) ngủ', word_type: 'verb', example_sentence: 'I try to sleep every day.' },
  { id: 6, word: 'quiet', meaning: '(adj) yên tĩnh', word_type: 'adjective', example_sentence: 'The weather is quiet today.' },
];

test('skeletonOf rut gon 2 cau khac nhau ve cung mot khuon', () => {
  assert.equal(
    skeletonOf('The window was easy to recognize.', 'window'),
    skeletonOf('The table was easy to recognize.', 'table'),
  );
});

test('skeletonOf chi rut gon khi cau that su chua tu dich', () => {
  assert.equal(
    skeletonOf('The teacher explained the rule to us.', 'rule'),
    'the teacher explained the {w} to us.',
  );
  // Tu khong xuat hien trong cau -> skeleton giong het cau goc.
  assert.equal(
    skeletonOf('The teacher explained it to us.', 'window'),
    'the teacher explained it to us.',
  );
});

test('skeletonOf xu ly du an nhieu chu', () => {
  assert.equal(
    skeletonOf('I need to give up before dinner.', 'give up'),
    'i need to {w} before dinner.',
  );
});

test('groupBySkeleton gom duoc nhom cau trung', () => {
  const groups = groupBySkeleton(STALE_ROWS);
  const duplicates = [...groups.entries()].filter(([, rows]) => rows.length > 1);

  assert.equal(duplicates.length, 1);
  assert.equal(duplicates[0][1].length, 4);
});

test('phat hien duoc nhom trung ngay ca khi chi co mot cau', () => {
  const groups = groupBySkeleton(STALE_ROWS);
  const cliches = [...groups.keys()].filter((key) => LEGACY_CLAICHES.includes(key));

  assert.equal(cliches.length, 3);
});

test('ke hoach sua tao ra cau khac nhau cho tung tu bi trung', () => {
  const groups = groupBySkeleton(STALE_ROWS);
  const toFix = new Map();
  for (const [key, rows] of groups) {
    if (rows.length > 1 || LEGACY_CLAICHES.includes(key)) {
      for (const row of rows) toFix.set(row.id, { row, skeleton: key });
    }
  }

  assert.equal(toFix.size, 6);

  const plan = planFixes(STALE_ROWS, toFix);
  const sentences = plan.map((item) => normalizeSentenceKey(item.next.sentence));
  assert.equal(new Set(sentences).size, 6, '6 tu phai ra 6 cau khac nhau');
  for (const item of plan) {
    assert.ok(item.next.sentence.includes(item.row.word), `${item.row.word} thieu tu dich`);
    assert.ok(item.next.translation.length > 0);
    assert.equal(item.next.target, item.row.word);
  }
});

test('ke hoach sua khong sinh trung voi cau cua tu khong bi sua', () => {
  const words = [
    ...STALE_ROWS,
    { id: 99, word: 'sleep', meaning: '(v) ngủ', word_type: 'verb', example_sentence: 'I want to sleep now.' },
  ];
  const toFix = new Map();
  for (const row of STALE_ROWS) toFix.set(row.id, { row, skeleton: 'x' });

  const plan = planFixes(words, toFix);
  const sentences = plan.map((item) => item.next.sentence);
  assert.ok(!sentences.includes('I want to sleep now.'), 'khong duoc trung cau cua tu id=99');
});
