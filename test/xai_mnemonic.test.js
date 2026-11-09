const assert = require('node:assert/strict');
const test = require('node:test');

const {
  buildMnemonicPrompt,
  normalizeGeneratedMnemonic,
} = require('../api/_lib/xai');

test('prompt meo nho co tu, nghia va phien am', () => {
  const prompt = buildMnemonicPrompt({
    word: 'immune',
    pronunciation: 'ɪˈmjuːn',
    meaning: 'miễn dịch',
    wordType: 'adjective',
  });
  assert.match(prompt, /Word: immune/);
  assert.match(prompt, /miễn dịch/);
  assert.match(prompt, /\/ɪˈmjuːn\//);
  assert.match(prompt, /Etymology/);
});

test('prompt meo nho uu tien goc tu that va cam khuon lap lai', () => {
  const prompt = buildMnemonicPrompt({
    word: 'critically',
    pronunciation: 'ˈkrɪt.ɪ.kəl.i',
    meaning: 'một cách phản biện; trầm trọng',
    wordType: 'adverb',
  });
  assert.match(prompt, /Never guess or invent an etymology/);
  assert.match(prompt, /Never reuse a fixed template/);
  assert.match(prompt, /critically -> critic/);
});

test('prompt bo phan doc khi tu chua co phien am', () => {
  const prompt = buildMnemonicPrompt({ word: 'immune', meaning: 'miễn dịch' });
  assert.doesNotMatch(prompt, /đọc là/);
  assert.doesNotMatch(prompt, /Pronunciation is/);
  assert.match(prompt, /Pronunciation \(IPA\): unknown/);
});

test('normalize cat khoang trang', () => {
  assert.deepEqual(
    normalizeGeneratedMnemonic({ mnemonic: '  Từ immune ...  ' }),
    { mnemonic: 'Từ immune ...' },
  );
});

test('normalize tu choi meo nho rong', () => {
  assert.throws(() => normalizeGeneratedMnemonic({}), /empty mnemonic/);
});

test('normalize tu choi meo nho qua dai', () => {
  assert.throws(
    () => normalizeGeneratedMnemonic({ mnemonic: 'x'.repeat(1201) }),
    /empty mnemonic/,
  );
});
