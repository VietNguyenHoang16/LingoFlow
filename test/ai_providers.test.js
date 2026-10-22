const assert = require('node:assert/strict');
const test = require('node:test');

const {
  createAiChain,
  normalizeChatEndpoint,
  sanitizeAiConfigs,
  testAiProvider,
} = require('../api/_lib/xai');

function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function exampleResponse(sentence) {
  return jsonResponse(200, {
    choices: [
      {
        message: {
          content: JSON.stringify({ sentence, translation: 'Co ay di lam bang xe buyt.' }),
        },
      },
    ],
  });
}

async function withFetch(mock, fn) {
  const original = global.fetch;
  global.fetch = mock;
  try {
    return await fn();
  } finally {
    global.fetch = original;
  }
}

async function withoutGeminiKey(fn) {
  const original = process.env.GEMINI_API_KEY;
  delete process.env.GEMINI_API_KEY;
  try {
    return await fn();
  } finally {
    if (original === undefined) delete process.env.GEMINI_API_KEY;
    else process.env.GEMINI_API_KEY = original;
  }
}

test('normalizeChatEndpoint nhan base URL hoac full endpoint', () => {
  assert.equal(
    normalizeChatEndpoint('https://api.xkiro.com/v1'),
    'https://api.xkiro.com/v1/chat/completions',
  );
  assert.equal(
    normalizeChatEndpoint('https://api.xkiro.com/v1/chat/completions/'),
    'https://api.xkiro.com/v1/chat/completions',
  );
  assert.throws(() => normalizeChatEndpoint('http://api.xkiro.com/v1'), /https/i);
  assert.throws(() => normalizeChatEndpoint('https://127.0.0.1/v1'), /nội bộ/i);
  assert.throws(() => normalizeChatEndpoint('https://localhost/v1'), /nội bộ/i);
});

test('sanitizeAiConfigs gioi han 3 va bo cau hinh thieu', () => {
  const configs = sanitizeAiConfigs([
    { name: 'A', baseUrl: 'https://a.example/v1', apiKey: 'ka', model: 'm1' },
    { name: 'B', baseUrl: 'https://b.example/v1', apiKey: 'kb', model: 'm2' },
    { name: 'C', baseUrl: 'https://c.example/v1', apiKey: 'kc', model: 'm3' },
    { name: 'D', baseUrl: 'https://d.example/v1', apiKey: 'kd', model: 'm4' },
    { name: 'E', baseUrl: 'https://e.example/v1', apiKey: '', model: 'm5' },
    { name: 'F', baseUrl: 'ftp://f.example/v1', apiKey: 'kf', model: 'm6' },
  ]);

  assert.equal(configs.length, 3);
  assert.equal(configs[0].endpoint, 'https://a.example/v1/chat/completions');
  assert.equal(configs[0].apiKey, 'ka');
});

test('chain thu tu tren xuong, tat provider loi key va uu tien provider da thanh cong', async () => {
  const calls = [];

  await withoutGeminiKey(() =>
    withFetch(
      async (url, options) => {
        calls.push({
          url: String(url),
          auth: options.headers.Authorization,
          body: JSON.parse(options.body),
        });
        if (String(url).startsWith('https://bad.example')) {
          return jsonResponse(401, { error: { message: 'invalid api key' } });
        }
        return exampleResponse('Mai commutes to work by bus.');
      },
      async () => {
        const chain = createAiChain([
          { name: 'Bad', baseUrl: 'https://bad.example/v1', apiKey: 'bad', model: 'bad-model' },
          { name: 'Good', baseUrl: 'https://good.example/v1', apiKey: 'good', model: 'good-model' },
        ]);

        const first = await chain.generate(
          { word: 'commute', meaning: 'di lam', wordType: 'verb' },
          { timeoutMs: 1000 },
        );
        assert.equal(first.target, 'commute');
        assert.equal(calls.length, 2);
        assert.equal(calls[0].auth, 'Bearer bad');
        assert.equal(calls[1].auth, 'Bearer good');
        assert.equal(calls[1].body.model, 'good-model');

        const second = await chain.generate(
          { word: 'commute', meaning: 'di lam', wordType: 'verb' },
          { timeoutMs: 1000 },
        );
        assert.equal(second.sentence, 'Mai commutes to work by bus.');
        assert.equal(calls.length, 3);
        assert.equal(calls[2].url, 'https://good.example/v1/chat/completions');
      },
    ),
  );
});

test('chain doc duoc JSON boc trong markdown fence', async () => {
  await withoutGeminiKey(() =>
    withFetch(
      async () =>
        jsonResponse(200, {
          choices: [
            {
              message: {
                content:
                  '```json\n{"sentence":"I commute by train.","translation":"Toi di lam bang tau."}\n```',
              },
            },
          ],
        }),
      async () => {
        const chain = createAiChain([
          { baseUrl: 'https://good.example/v1', apiKey: 'k', model: 'm' },
        ]);
        const example = await chain.generate(
          { word: 'commute', meaning: 'di lam', wordType: 'verb' },
          { timeoutMs: 1000 },
        );
        assert.equal(example.sentence, 'I commute by train.');
        assert.equal(example.translation, 'Toi di lam bang tau.');
      },
    ),
  );
});

test('testAiProvider tra ve ok va loi tieng Viet', async () => {
  await withFetch(
    async (url) => {
      if (String(url).startsWith('https://bad.example')) {
        return jsonResponse(401, { error: { message: 'invalid api key' } });
      }
      return jsonResponse(200, { choices: [{ message: { content: 'OK' } }] });
    },
    async () => {
      const ok = await testAiProvider({
        baseUrl: 'https://api.xkiro.com/v1/chat/completions',
        apiKey: 'good',
        model: 'openai/gpt-5.6-sol',
      });
      assert.equal(ok.ok, true);
      assert.equal(typeof ok.latencyMs, 'number');

      const bad = await testAiProvider({
        baseUrl: 'https://bad.example/v1',
        apiKey: 'bad',
        model: 'm',
      });
      assert.equal(bad.ok, false);
      assert.match(bad.message, /API key/i);

      const missing = await testAiProvider({ baseUrl: '', apiKey: '', model: '' });
      assert.equal(missing.ok, false);
    },
  );
});

test('chain fallback ve GEMINI_API_KEY cua server khi moi API nguoi dung loi', async () => {
  const original = process.env.GEMINI_API_KEY;
  process.env.GEMINI_API_KEY = 'server-key';
  const urls = [];

  try {
    await withFetch(
      async (url) => {
        urls.push(String(url));
        if (String(url).includes('generativelanguage')) {
          return jsonResponse(200, {
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        sentence: 'She commutes to work by bike.',
                        translation: 'Co ay di lam bang xe dap.',
                      }),
                    },
                  ],
                },
              },
            ],
          });
        }
        return jsonResponse(500, { error: { message: 'provider down' } });
      },
      async () => {
        const chain = createAiChain([
          { baseUrl: 'https://down.example/v1', apiKey: 'k', model: 'm' },
        ]);
        const example = await chain.generate(
          { word: 'commute', meaning: 'di lam', wordType: 'verb' },
          { timeoutMs: 1000 },
        );
        assert.equal(example.sentence, 'She commutes to work by bike.');
        assert.ok(urls.some((url) => url.includes('generativelanguage')));
      },
    );
  } finally {
    if (original === undefined) delete process.env.GEMINI_API_KEY;
    else process.env.GEMINI_API_KEY = original;
  }
});

test('chain bo qua provider timeout 2 lan lien tiep', async () => {
  const calls = [];

  await withoutGeminiKey(() =>
    withFetch(
      async (url, options) => {
        const target = String(url);
        calls.push(target);
        if (target.startsWith('https://slow.example')) {
          return new Promise((_, reject) => {
            options.signal.addEventListener('abort', () => {
              reject(new Error('This operation was aborted'));
            });
          });
        }
        return jsonResponse(500, { error: { message: 'provider down' } });
      },
      async () => {
        const chain = createAiChain([
          { baseUrl: 'https://slow.example/v1', apiKey: 'slow', model: 'slow-model' },
          { baseUrl: 'https://down.example/v1', apiKey: 'down', model: 'down-model' },
        ]);

        await assert.rejects(
          () => chain.generate({ word: 'commute', meaning: 'di lam' }, { timeoutMs: 30 }),
        );
        await assert.rejects(
          () => chain.generate({ word: 'commute', meaning: 'di lam' }, { timeoutMs: 30 }),
        );
        assert.deepEqual(calls, [
          'https://slow.example/v1/chat/completions',
          'https://down.example/v1/chat/completions',
          'https://slow.example/v1/chat/completions',
          'https://down.example/v1/chat/completions',
        ]);

        await assert.rejects(
          () => chain.generate({ word: 'commute', meaning: 'di lam' }, { timeoutMs: 30 }),
        );
        assert.equal(calls.length, 5);
        assert.ok(calls[4].startsWith('https://down.example'));
      },
    ),
  );
});

test('chain ton trong deadline tong', async () => {
  await withoutGeminiKey(() =>
    withFetch(
      async (url, options) =>
        new Promise((_, reject) => {
          options.signal.addEventListener('abort', () => {
            reject(new Error('This operation was aborted'));
          });
        }),
      async () => {
        const chain = createAiChain([
          { baseUrl: 'https://slow.example/v1', apiKey: 'k', model: 'm' },
        ]);
        const started = Date.now();
        await assert.rejects(
          () =>
            chain.generate(
              { word: 'commute' },
              { timeoutMs: 5000, deadline: Date.now() + 60 },
            ),
          /quá chậm/i,
        );
        assert.ok(Date.now() - started < 1000);
      },
    ),
  );
});
