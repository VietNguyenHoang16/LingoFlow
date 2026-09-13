// Sinh cau vi du tieng Anh de hieu + ban dich tieng Viet bang xAI (Grok).
// Key KHONG hardcode: doc tu env XAI_API_KEY. That bai -> dung mau tinh.

const XAI_URL = 'https://api.x.ai/v1/chat/completions';

// Model khoa cung: moi request sinh vi du deu dung model nay. Doi model -> sua code + deploy.
const XAI_MODEL = 'grok-4.20-0309-non-reasoning';

function model() {
  return XAI_MODEL;
}

function firstMeaning(raw) {
  return String(raw || '')
    .replace(/^\([^)]*\)\s*/, '')
    .split(';')[0]
    .trim() || String(raw || '').trim() || 'it';
}

function primaryType(raw) {
  const value = String(raw || '').toLowerCase();
  if (value.includes('phrasal_verb')) return 'phrasal_verb';
  if (value.includes('idiom')) return 'idiom';
  if (value.includes('collocation')) return 'collocation';
  if (value.includes('grammar')) return 'grammar';
  if (value.includes('adjective')) return 'adjective';
  if (value.includes('adverb')) return 'adverb';
  if (value.includes('preposition')) return 'preposition';
  if (value.includes('conjunction')) return 'conjunction';
  if (value.includes('pronoun')) return 'pronoun';
  if (value.includes('interjection')) return 'interjection';
  if (value.includes('verb')) return 'verb';
  if (value.includes('noun')) return 'noun';
  return 'other';
}

// Mau tinh khi AI loi/timeout/thieu key. Giong scripts/populate_examples.js.
function templateExample({ word, meaning, wordType }) {
  const w = String(word || '').trim();
  const m = firstMeaning(meaning);
  switch (primaryType(`${wordType || ''} ${meaning || ''}`)) {
    case 'verb':
      return { sentence: `I try to ${w} every day.`, translation: `Tôi cố gắng ${m} mỗi ngày.`, target: w };
    case 'phrasal_verb':
      return { sentence: `I need to ${w} before dinner.`, translation: `Tôi cần ${m} trước bữa tối.`, target: w };
    case 'noun':
      return { sentence: `The ${w} was easy to recognize.`, translation: `${m} đó rất dễ nhận ra.`, target: w };
    case 'adjective':
      return { sentence: `The weather is ${w} today.`, translation: `Thời tiết hôm nay ${m}.`, target: w };
    case 'adverb':
      return { sentence: `She answered ${w} during the meeting.`, translation: `Cô ấy trả lời ${m} trong cuộc họp.`, target: w };
    case 'preposition':
      return { sentence: `The keys are ${w} the book.`, translation: `Chìa khóa ở ${m} quyển sách.`, target: w };
    case 'conjunction':
      return { sentence: `I stayed home ${w} it was raining.`, translation: `Tôi ở nhà ${m} trời đang mưa.`, target: w };
    case 'pronoun':
      return { sentence: `${w} is waiting outside.`, translation: `${m} đang đợi ở bên ngoài.`, target: w };
    case 'interjection':
      return { sentence: `"${w}!" she shouted.`, translation: `"${m}!" cô ấy hét lên.`, target: w };
    case 'idiom':
    case 'collocation':
      return { sentence: `We use "${w}" in everyday conversation.`, translation: `Chúng ta dùng "${w}" trong giao tiếp hằng ngày.`, target: w };
    case 'grammar':
      return { sentence: `This sentence uses "${w}" correctly.`, translation: `Câu này sử dụng "${m}" đúng cách.`, target: w };
    default:
      return { sentence: `I learned the expression "${w}" today.`, translation: `Hôm nay tôi học cách dùng "${w}".`, target: w };
  }
}

function clean(value, max) {
  const s = typeof value === 'string' ? value.trim() : '';
  return s.length > max ? '' : s;
}

async function generateExample({ word, meaning, wordType }, { timeoutMs = 10000 } = {}) {
  const apiKey = process.env.XAI_API_KEY;
  if (!apiKey) throw new Error('Missing XAI_API_KEY');
  const w = String(word || '').trim();
  if (!w) throw new Error('Missing word');

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(XAI_URL, {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: model(),
        messages: [
          {
            role: 'system',
            content: 'You write ONE very easy English example sentence (A1-A2 level, under 15 words) for a Vietnamese learner, plus its natural Vietnamese translation. Reply with JSON only: {"sentence":"...","translation":"..."}.',
          },
          { role: 'user', content: `Word: ${w} (${wordType || 'word'}) - meaning: ${firstMeaning(meaning)}` },
        ],
        response_format: { type: 'json_object' },
        temperature: 0.7,
      }),
      signal: controller.signal,
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload?.error || `xAI HTTP ${response.status}`);
    const raw = payload?.choices?.[0]?.message?.content || '';
    const parsed = JSON.parse(raw);
    const sentence = clean(parsed.sentence, 1000);
    const translation = clean(parsed.translation, 1000);
    if (!sentence || !translation) throw new Error('Empty xAI example');
    return { sentence, translation, target: w };
  } finally {
    clearTimeout(timer);
  }
}

// Sinh vi du cho 1 tu vua insert: thu AI, loi -> mau tinh. Khong bao gio throw.
async function enrichWordExample(query, wordId, info, opts = {}) {
  let example;
  let source = 'ai';
  if (opts.skipAi) {
    example = templateExample(info);
    source = 'template';
  } else {
    try {
      example = await generateExample(info, opts);
    } catch (_) {
      example = templateExample(info);
      source = 'template';
    }
  }
  try {
    await query(
      `UPDATE vocabulary_words
       SET example_sentence = $1, example_translation = $2, example_target = $3
       WHERE id = $4`,
      [example.sentence, example.translation, example.target, wordId],
    );
  } catch (_) {}
  return source;
}

module.exports = {
  generateExample,
  templateExample,
  enrichWordExample,
  firstMeaning,
};
