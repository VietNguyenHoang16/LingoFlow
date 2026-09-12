const assert = require('node:assert/strict');
const test = require('node:test');

const {
  mapWord,
  parsePageParams,
  parseWordId,
  validateExamplePayload,
} = require('../api/_lib/examples');

test('validateExamplePayload trims fields and keeps an optional target', () => {
  assert.deepEqual(
    validateExamplePayload({
      sentence: '  I am tired.  ',
      translation: '  Tôi mệt. ',
      target: ' lie down ',
    }),
    {
      sentence: 'I am tired.',
      translation: 'Tôi mệt.',
      target: 'lie down',
    },
  );
});

test('validateExamplePayload rejects missing sentence or translation', () => {
  assert.throws(
    () => validateExamplePayload({ sentence: '', translation: 'Tôi mệt.' }),
    (error) => error.code === 'VALIDATION_ERROR' && error.status === 422,
  );
  assert.throws(
    () => validateExamplePayload({ sentence: 'I am tired.', translation: ' ' }),
    (error) => error.code === 'VALIDATION_ERROR' && error.status === 422,
  );
});

test('validateExamplePayload rejects fields longer than the API limits', () => {
  assert.throws(
    () => validateExamplePayload({ sentence: 'x'.repeat(1001), translation: 'Tôi mệt.' }),
    (error) => error.code === 'VALIDATION_ERROR' && error.status === 422,
  );
  assert.throws(
    () => validateExamplePayload({ sentence: 'I am tired.', translation: 'Tôi mệt.', target: 'x'.repeat(256) }),
    (error) => error.code === 'VALIDATION_ERROR' && error.status === 422,
  );
});

test('parsePageParams normalizes pagination, search, and example filters', () => {
  assert.deepEqual(
    parsePageParams(new URLSearchParams('page=0&pageSize=999&q=%20lie%20down%20&hasExample=true')),
    { page: 1, pageSize: 100, query: 'lie down', hasExample: true },
  );
  assert.deepEqual(
    parsePageParams(new URLSearchParams()),
    { page: 1, pageSize: 50, query: '', hasExample: null },
  );
});

test('parseWordId accepts only positive integer ids', () => {
  assert.equal(parseWordId('42'), 42);
  assert.throws(
    () => parseWordId('0'),
    (error) => error.code === 'VALIDATION_ERROR' && error.status === 422,
  );
  assert.throws(
    () => parseWordId('abc'),
    (error) => error.code === 'VALIDATION_ERROR' && error.status === 422,
  );
});

test('mapWord exposes the example fields in the web API shape', () => {
  assert.deepEqual(
    mapWord({
      id: '7',
      word: 'lie down',
      pronunciation: '/laɪ daʊn/',
      meaning: 'nằm xuống',
      topic_tag: 'rest',
      example_sentence: "I'm tired.",
      example_translation: 'Tôi mệt.',
      example_target: 'lie down',
    }),
    {
      id: 7,
      word: 'lie down',
      pronunciation: '/laɪ daʊn/',
      meaning: 'nằm xuống',
      topicTag: 'rest',
      exampleSentence: "I'm tired.",
      exampleTranslation: 'Tôi mệt.',
      exampleTarget: 'lie down',
    },
  );
});
