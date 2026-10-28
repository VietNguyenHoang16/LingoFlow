const assert = require('node:assert/strict');
const test = require('node:test');

const {
  DEFAULT_EXAMPLE_STYLE,
  MAX_STYLE_CUSTOM,
  buildExamplePrompt,
  buildStylePrompt,
  buildWordInfoPrompt,
  normalizeExampleStyle,
} = require('../api/_lib/xai');

test('khong co du lieu -> mac dinh doi song / cong viec / IT, bo nghia hiem', () => {
  const style = normalizeExampleStyle(null);
  assert.deepEqual(style.contexts, ['daily', 'work', 'it']);
  assert.equal(style.skipRareSenses, true);
  assert.equal(style.custom, '');
  assert.deepEqual(style, { ...DEFAULT_EXAMPLE_STYLE });
});

test('boi canh la bi loai, trung lap duoc gop, custom duoc lam sach', () => {
  const style = normalizeExampleStyle({
    contexts: ['IT', 'it', ' mars ', 'study', 'travel'],
    skipRareSenses: false,
    custom: '   dung   thi   hien tai\n\nva cau ngan   ',
  });
  assert.deepEqual(style.contexts, ['it', 'study', 'travel']);
  assert.equal(style.skipRareSenses, false);
  assert.equal(style.custom, 'dung thi hien tai va cau ngan');
});

test('custom bi cat o 300 ky tu', () => {
  const style = normalizeExampleStyle({ custom: 'a'.repeat(500) });
  assert.equal(style.custom.length, MAX_STYLE_CUSTOM);
});

test('contexts khong phai mang -> quay ve mac dinh', () => {
  const style = normalizeExampleStyle({ contexts: 'daily' });
  assert.deepEqual(style.contexts, ['daily', 'work', 'it']);
});

test('prompt vi du mac dinh uu tien nghia pho bien + boi canh doi song/IT', () => {
  const prompt = buildExamplePrompt({
    word: 'harness',
    meaning: '(v) khai thác, tận dụng',
    wordType: 'verb',
    topicTag: '',
    style: null,
  });

  assert.match(prompt, /Learner preferences:/);
  assert.match(prompt, /concrete" use "cụ thể, rõ ràng"/);
  assert.match(prompt, /harness" use "tận dụng, khai thác"/);
  assert.match(prompt, /everyday life, work and the office, IT and technology/);
  // Rang buoc cu phai con nguyen.
  assert.match(prompt, /The sentence MUST contain the target word exactly as written/);
  // Khong con khoa trinh do A2-B1.
  assert.equal(/A2-B1|A2|B1/.test(prompt), false);
  assert.match(prompt, /natural, correct English at whatever level/);
  assert.match(prompt, /Reply with JSON only: \{"sentence":"\.\.\.","translation":"\.\.\."\}/);
  assert.match(prompt, /Word: harness/);
});

test('tat het tuy chon -> prompt khong con khoi uu tien', () => {
  const prompt = buildExamplePrompt({
    word: 'table',
    meaning: 'cái bàn',
    style: { contexts: [], skipRareSenses: false, custom: '' },
  });
  assert.equal(prompt.includes('Learner preferences:'), false);
  assert.match(prompt, /Word: table/);
});

test('yeu cau rieng duoc chen nguyen van', () => {
  const prompt = buildExamplePrompt({
    word: 'deploy',
    meaning: 'triển khai',
    style: { contexts: ['it'], skipRareSenses: true, custom: 'chi dung thi hien tai don' },
  });
  assert.match(prompt, /Extra notes from the learner: chi dung thi hien tai don/);
});

test('prompt nghia chi nhan uu tien nghia, khong nhan boi canh', () => {
  const prompt = buildWordInfoPrompt({
    word: 'concrete',
    style: { contexts: ['it'], skipRareSenses: true, custom: '' },
  });
  assert.match(prompt, /cụ thể, rõ ràng/);
  assert.equal(prompt.includes('IT and technology'), false);
  assert.match(prompt, /Reply with JSON only: \{"meaning":"\.\.\.","wordType":"\.\.\."\}/);
});

test('buildStylePrompt tra ve chuoi rong khi khong co tuy chon nao', () => {
  assert.equal(
    buildStylePrompt({ contexts: [], skipRareSenses: false, custom: '' }),
    '',
  );
});
