const assert = require('node:assert/strict');
const test = require('node:test');

const {
  TEMPLATE_BANK,
  firstMeaning,
  normalizeSentenceKey,
  pickUniqueExample,
  primaryType,
  templateExample,
} = require('../api/_lib/xai');

const NOUNS = [
  'table', 'window', 'garden', 'letter', 'bottle', 'candle', 'basket', 'pencil',
  'mirror', 'ladder', 'bucket', 'curtain', 'pocket', 'river', 'cloud', 'stone',
  'bridge', 'forest', 'meadow', 'harbor', 'island', 'desert', 'valley',
  'tunnel', 'cottage', 'kitchen', 'balcony', 'chimney', 'blanket', 'cushion',
  'drawer', 'envelope', 'flashlight', 'hammer', 'magnet', 'needle',
  'oven', 'pillow', 'rope', 'scarf', 'shelf', 'spoon', 'towel', 'wallet',
  'anchor', 'arrow', 'badge', 'beacon', 'cactus', 'compass', 'glacier',
];

// Skeleton cu cua templateExample() truoc khi sua. Moi cau nay phai bien mat
// khoi bank, neu con thi import moi lai tao lai lo trung.
const LEGACY_CLAICHES = [
  'The {w} was easy to recognize.',
  'I try to {w} every day.',
  'I need to {w} before dinner.',
  'The weather is {w} today.',
  'She answered {w} during the meeting.',
  'The keys are {w} the book.',
  'I stayed home {w} it was raining.',
  '{w} is waiting outside.',
  '"{w}!" she shouted.',
  'We use "{w}" in everyday conversation.',
  'This sentence uses "{w}" correctly.',
  'I learned the expression "{w}" today.',
];

test('import 50 danh tu tao ra 50 cau vi du khac nhau', () => {
  const used = new Set();
  const sentences = [];

  for (const word of NOUNS) {
    const example = templateExample({ word, meaning: `nghia cua ${word}`, wordType: 'noun' }, { used });
    assert.ok(example.sentence.includes(word), `cau phai chua tu dich: ${example.sentence}`);
    assert.equal(example.target, word);
    sentences.push(example.sentence);
  }

  assert.equal(sentences.length, NOUNS.length);
  assert.equal(new Set(sentences.map(normalizeSentenceKey)).size, NOUNS.length);
});

test('cung mot tu luon sinh ra cung mot cau (deterministic)', () => {
  const info = { word: 'window', meaning: '(n) cửa sổ', wordType: 'noun' };
  const first = templateExample(info);
  const second = templateExample(info);

  assert.equal(first.sentence, second.sentence);
  assert.equal(first.translation, second.translation);
});

test('templateExample bo qua cau da dung va lay cau chua dung', () => {
  const info = { word: 'window', meaning: '(n) cửa sổ', wordType: 'noun' };
  const first = templateExample(info);
  const second = templateExample(info, { used: new Set([normalizeSentenceKey(first.sentence)]) });

  assert.notEqual(second.sentence, first.sentence);
  assert.ok(second.sentence.includes('window'));
});

test('moi loai tu deu co nhieu bien the cau va khong trung nhau ben trong', () => {
  for (const [type, bank] of Object.entries(TEMPLATE_BANK)) {
    assert.ok(Array.isArray(bank) && bank.length > 0, `${type} phai co template`);
    const sentences = bank.map((make) => make('window', 'cửa sổ').sentence);
    const unique = new Set(sentences.map(normalizeSentenceKey));
    assert.equal(unique.size, sentences.length, `${type} co cau bi trung ben trong`);
    for (const sentence of sentences) {
      assert.ok(sentence.includes('window'), `${type}: cau thieu tu dich -> ${sentence}`);
    }
  }
});

test('khong con cau cliche cu cu trong bank', () => {
  for (const bank of Object.values(TEMPLATE_BANK)) {
    for (const make of bank) {
      const { sentence } = make('window', 'cửa sổ');
      const skeleton = normalizeSentenceKey(sentence).replace(/window/g, '{w}');
      assert.ok(!LEGACY_CLAICHES.includes(skeleton), `van con cau cliche cu: ${sentence}`);
    }
  }
});


test('pickUniqueExample tra ve phan tu chua dung, neu het thi lay phan tu cuoi', () => {
  const candidates = [
    { sentence: 'First one.', translation: 'Mot.' },
    { sentence: 'Second one.', translation: 'Hai.' },
  ];

  assert.equal(pickUniqueExample(candidates).sentence, 'First one.');
  assert.equal(pickUniqueExample(candidates, new Set(['first one.'])).sentence, 'Second one.');
  assert.equal(pickUniqueExample(candidates, new Set(['first one.', 'second one.'])).sentence, 'Second one.');
  assert.throws(() => pickUniqueExample([]), /candidate/i);
});

test('pickUniqueExample ghi khoa vao Set duoc truyen vao', () => {
  const used = new Set();
  pickUniqueExample([{ sentence: 'Fresh line.', translation: 'Dong moi.' }], used);

  assert.deepEqual([...used], ['fresh line.']);
});

test('primaryType nhan dien duoc ca ten loai va nhan trong ngoac', () => {
  assert.equal(primaryType('noun'), 'noun');
  assert.equal(primaryType('(n) cái bàn'), 'noun');
  assert.equal(primaryType('(adj) yên tĩnh'), 'adjective');
  assert.equal(primaryType('(v) ngủ'), 'verb');
  assert.equal(primaryType('(prep) giữa'), 'preposition');
  assert.equal(primaryType('(conj) mặc dù'), 'conjunction');
  assert.equal(primaryType('(pron) họ'), 'pronoun');
  assert.equal(primaryType('(interj) ôi'), 'interjection');
  assert.equal(primaryType('phrasal_verb'), 'phrasal_verb');
  assert.equal(primaryType('idiom'), 'idiom');
  assert.equal(primaryType('collocation'), 'collocation');
  assert.equal(primaryType('grammar'), 'grammar');
  assert.equal(primaryType(''), 'other');
});

test('primaryType phan biet adverb voi verb', () => {
  assert.equal(primaryType('adverb'), 'adverb');
  assert.equal(primaryType('verb'), 'verb');
  assert.equal(primaryType('(adv) chậm rãi'), 'adverb');
});

test('moi loai tu trong primaryType deu sinh duoc cau day du', () => {
  const cases = [
    ['(n) cái bàn', 'table'],
    ['(v) ngủ', 'sleep'],
    ['(adj) yên tĩnh', 'quiet'],
    ['(adv) chậm rãi', 'slowly'],
    ['(prep) giữa', 'between'],
    ['(conj) mặc dù', 'although'],
    ['(pron) họ', 'they'],
    ['(interj) ôi', 'wow'],
    ['(phrasal verb) bỏ cuộc', 'give up'],
    ['(idiom) dễ ăn', 'piece of cake'],
    ['(collocation) đưa ra quyết định', 'make a decision'],
    ['(grammar) mạo từ', 'a/an'],
    ['', 'whatever'],
  ];

  for (const [meaning, word] of cases) {
    const example = templateExample({ word, meaning, wordType: '' });
    assert.ok(example.sentence.length > 0, `${word}: cau rong`);
    assert.ok(example.translation.length > 0, `${word}: thieu ban dich`);
    assert.ok(example.sentence.includes(word), `${word}: cau khong chua tu -> ${example.sentence}`);
    assert.equal(example.target, word);
  }
});

test('firstMeaning bo nhan trong ngoac va phan tach dau cham', () => {
  assert.equal(firstMeaning('(n) cái bàn; đồ vật'), 'cái bàn');
  assert.equal(firstMeaning('  (v)  ngủ  '), 'ngủ');
  assert.ok(firstMeaning('').length > 0);
});

test('nhieu loai tu khac nhau khong dung chung mot cau', () => {
  const used = new Set();
  const words = ['sleep', 'quiet', 'slowly', 'table'];
  const types = ['verb', 'adjective', 'adverb', 'noun'];

  const sentences = words.map((word, i) => {
    const example = templateExample({ word, meaning: `nghia cua ${word}`, wordType: types[i] }, { used });
    return example.sentence;
  });

  assert.equal(new Set(sentences.map(normalizeSentenceKey)).size, words.length);
});
