const assert = require('node:assert/strict');
const test = require('node:test');

const {
  buildExamplePrompt,
  exampleErrorMessage,
  normalizeGeneratedExample,
} = require('../api/_lib/xai');

test('prompt mang du ngu canh va cam khuon mau co dinh', () => {
  const prompt = buildExamplePrompt({
    word: 'commute',
    meaning: '(v) di lam hang ngay',
    wordType: 'verb',
    topicTag: 'work',
  });

  assert.match(prompt, /commute/);
  assert.match(prompt, /di lam hang ngay/);
  assert.match(prompt, /verb/);
  assert.match(prompt, /work/);
  assert.match(prompt, /fixed sentence pattern/i);
});

test('normalize nhan cau tu nhien co chua tu dich', () => {
  const example = normalizeGeneratedExample(
    {
      sentence: 'Mai commutes to work by bus when it rains.',
      translation: 'Mai di lam bang xe buyt khi troi mua.',
    },
    'commute',
  );

  assert.equal(example.sentence, 'Mai commutes to work by bus when it rains.');
  assert.equal(example.translation, 'Mai di lam bang xe buyt khi troi mua.');
  assert.equal(example.target, 'commute');
});

test('normalize tu choi cau thieu tu dich, thieu ban dich, qua dai', () => {
  assert.throws(
    () => normalizeGeneratedExample({ sentence: 'She left early.', translation: 'Co ay ve som.' }, 'commute'),
    /missing the target/i,
  );
  assert.throws(
    () => normalizeGeneratedExample({ sentence: 'Mai commutes to work.', translation: '' }, 'commute'),
    /empty example/i,
  );
  assert.throws(
    () => normalizeGeneratedExample({ sentence: 'A '.repeat(200) + 'commute', translation: 'x' }, 'commute'),
    /empty example/i,
  );
});

test('loi duoc map sang thong bao tieng Viet ro rang', () => {
  assert.match(exampleErrorMessage(new Error('Missing GEMINI_API_KEY')), /chưa cấu hình AI/);
  assert.match(exampleErrorMessage(new Error('This operation was aborted')), /quá chậm/);
  assert.match(exampleErrorMessage(new Error('Gemini HTTP 429')), /quá tải/);
  assert.match(exampleErrorMessage(new Error('AI example is missing the target word')), /không hợp lệ/);
});
