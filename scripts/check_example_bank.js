// Kiem nhanh nhanh bank: cau trung ben trong + con cliche cu khong.
const { TEMPLATE_BANK } = require('../api/_lib/xai');
const { templateExample } = require('../api/_lib/xai');

// Moi loai du 51 tu -> cau rieng. Day la tinh huong that cua mot lo import lon.
const WORDS = [
  'table', 'window', 'garden', 'letter', 'bottle', 'candle', 'basket', 'pencil',
  'mirror', 'ladder', 'bucket', 'curtain', 'pocket', 'river', 'cloud', 'stone',
  'bridge', 'forest', 'meadow', 'harbor', 'island', 'desert', 'valley',
  'tunnel', 'cottage', 'kitchen', 'balcony', 'chimney', 'blanket', 'cushion',
  'drawer', 'envelope', 'flashlight', 'hammer', 'magnet', 'needle',
  'oven', 'pillow', 'rope', 'scarf', 'shelf', 'spoon', 'towel', 'wallet',
  'anchor', 'arrow', 'badge', 'beacon', 'cactus', 'compass', 'glacier',
];

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

let dupes = 0;
let cliches = 0;
for (const [type, bank] of Object.entries(TEMPLATE_BANK)) {
  const sentences = bank.map((make) => make('window', 'cửa sổ').sentence);
  const unique = new Set(sentences.map((s) => s.toLowerCase()));
  if (unique.size !== sentences.length) {
    dupes += 1;
    console.log('TRUNG', type, sentences.length, '->', unique.size);
  }
  for (const sentence of sentences) {
    const skeleton = sentence.toLowerCase().replace(/window/g, '{w}');
    if (LEGACY_CLAICHES.includes(skeleton)) {
      cliches += 1;
      console.log('CLICHE', type, '->', skeleton);
    }
  }
  console.log(type.padEnd(14), 'size', String(sentences.length).padStart(4), 'unique', unique.size);

// Mo phong mot lo import 51 danh tu: moi tu phai ra mot cau rieng.
const used = new Set();
const generated = WORDS.map((word) => templateExample({ word, meaning: `nghia cua ${word}`, wordType: 'noun' }, { used }));
const uniqueBatch = new Set(generated.map((e) => e.sentence.toLowerCase()));
console.log('\n=== Lo import 51 danh tu ===');
console.log('so tu:', generated.length, '| so cau khac nhau:', uniqueBatch.size);
console.log(generated.slice(0, 6).map((e, i) => `  ${WORDS[i]} -> ${e.sentence}`).join('\n'));

}
console.log('TONG trung =', dupes, '| tong cliche =', cliches);
