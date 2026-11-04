const assert = require('node:assert/strict');
const test = require('node:test');

const {
  WORD_TYPES,
  buildExamplePrompt,
  buildWordInfoPrompt,
  createAiChain,
  exampleContainsTarget,
  exampleErrorMessage,
  normalizeGeneratedExample,
  normalizeGeneratedWordInfo,
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

test('cum nhieu tu: nhan cau da thay placeholder bang danh tu cu the', () => {
  assert.equal(
    exampleContainsTarget('He put his colleague down in front of the team.', 'put someone down'),
    true,
  );
  assert.equal(exampleContainsTarget('You should give up smoking.', 'give something up'), true);
  assert.equal(exampleContainsTarget('She puts people down all the time.', 'put someone down'), true);
  assert.equal(exampleContainsTarget('They looked after the children well.', 'look after someone'), true);
});

test('cum nhieu tu: van tu choi cau thieu tu khoa cua cum', () => {
  assert.equal(exampleContainsTarget('He put the book on the shelf.', 'put someone down'), false);
  assert.equal(exampleContainsTarget('She left early.', 'put someone down'), false);
  assert.equal(exampleContainsTarget('', 'put someone down'), false);
});

test('normalize nhan duoc vi du cho cum co placeholder', () => {
  const example = normalizeGeneratedExample(
    {
      sentence: 'He put his colleague down at the meeting.',
      translation: 'Anh ta ha be dong nghiep trong cuoc hop.',
    },
    'put someone down',
  );

  assert.equal(example.target, 'put someone down');
  assert.equal(example.sentence, 'He put his colleague down at the meeting.');
});

test('loi duoc map sang thong bao tieng Viet ro rang', () => {
  assert.match(exampleErrorMessage(new Error('Missing GEMINI_API_KEY')), /chưa cấu hình AI/);
  assert.match(exampleErrorMessage(new Error('This operation was aborted')), /quá chậm/);
  assert.match(exampleErrorMessage(new Error('Gemini HTTP 429')), /quá tải/);
  assert.match(exampleErrorMessage(new Error('AI example is missing the target word')), /không hợp lệ/);
  assert.match(exampleErrorMessage(new Error('AI returned an empty meaning for word info')), /không lấy được nghĩa/);
});

test('prompt word info mang tu va liet ke du loai tu app ho tro', () => {
  const prompt = buildWordInfoPrompt({ word: 'give up' });
  assert.match(prompt, /give up/);
  for (const type of WORD_TYPES) assert.match(prompt, new RegExp(type));
  assert.match(prompt, /Vietnamese meaning/i);
});

test('normalize word info nhan key hop le, map exclamation -> interjection', () => {
  assert.deepEqual(
    normalizeGeneratedWordInfo({ meaning: 'kiên cường', wordType: 'adjective' }, 'resilient'),
    {
      word: 'resilient',
      meaning: 'kiên cường',
      wordType: 'adjective',
      collocations: '',
      synonyms: [],
    },
  );
  assert.equal(
    normalizeGeneratedWordInfo({ meaning: 'ồ', wordType: 'exclamation' }, 'wow').wordType,
    'interjection',
  );
  assert.equal(
    normalizeGeneratedWordInfo({ meaning: 'từ bỏ', wordType: 'Phrasal Verb' }, 'give up').wordType,
    'phrasal_verb',
  );
});

test('normalize word info tu choi nghia rong va loai tu la', () => {
  assert.throws(
    () => normalizeGeneratedWordInfo({ meaning: '', wordType: 'noun' }, 'apple'),
    /empty meaning/i,
  );
  assert.throws(
    () => normalizeGeneratedWordInfo({ meaning: 'quả táo', wordType: 'fruit' }, 'apple'),
    /unknown word type/i,
  );
});

test('createAiChain.generateWordInfo goi provider va tra nghia + loai tu', async () => {
  const original = global.fetch;
  global.fetch = async () =>
    new Response(
      JSON.stringify({ choices: [{ message: { content: '{"meaning":"từ bỏ","wordType":"phrasal_verb"}' } }] }),
      { status: 200, headers: { 'content-type': 'application/json' } },
    );
  try {
    const chain = createAiChain([
      { name: 'test', baseUrl: 'https://api.example.com/v1', apiKey: 'k', model: 'm' },
    ]);
    const info = await chain.generateWordInfo({ word: 'give up' }, { timeoutMs: 2000 });
    assert.deepEqual(info, {
      word: 'give up',
      meaning: 'từ bỏ',
      wordType: 'phrasal_verb',
      collocations: '',
      synonyms: [],
    });
  } finally {
    global.fetch = original;
  }
});
