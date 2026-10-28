// Sinh cau vi du tieng Anh de hieu + ban dich tieng Viet bang Gemini.
// Key KHONG hardcode: doc tu env GEMINI_API_KEY (tuong thich nguoc XAI_API_KEY
// neu chua doi env). That bai -> dung mau tinh.

const GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta/models';

// Model khoa cung: moi request sinh vi du deu dung model nay. Doi model -> sua code + deploy.
// Key dang AQ. da kiem chung chay that (10/10/2026): gemini-3.6-flash -> 200,
// gemini-2.5-flash / 2.0-flash -> 404 (ngung cho user moi).
const GEMINI_MODEL = 'gemini-3.6-flash';
const GEMINI_FALLBACK_MODEL = 'gemini-3.5-flash-lite';

function model() {
  return GEMINI_MODEL;
}

const MAX_AI_PROVIDERS = 3;

function isPrivateHost(rawHost) {
  const host = String(rawHost || '').toLowerCase().replace(/^\[|\]$/g, '');
  if (!host) return true;
  if (host === 'localhost' || host.endsWith('.localhost') || host.endsWith('.local')) return true;
  if (host.includes(':') && (host === '::1' || host.startsWith('fc') || host.startsWith('fd') || host.startsWith('fe80'))) return true;
  if (/^127\./.test(host) || /^10\./.test(host) || /^192\.168\./.test(host) || /^169\.254\./.test(host)) return true;
  return /^172\.(1[6-9]|2\d|3[01])\./.test(host);
}

function normalizeChatEndpoint(raw) {
  let url;
  try {
    url = new URL(String(raw || '').trim());
  } catch (_) {
    throw new Error('Base URL không hợp lệ.');
  }
  if (url.protocol !== 'https:') throw new Error('Base URL phải dùng https.');
  if (isPrivateHost(url.hostname)) throw new Error('Base URL không được trỏ vào mạng nội bộ.');
  const path = url.pathname.replace(/\/+$/, '').replace(/\/chat\/completions$/i, '');
  url.pathname = `${path}/chat/completions`;
  url.search = '';
  url.hash = '';
  return url.toString();
}

function sanitizeAiConfigs(raw) {
  if (!Array.isArray(raw)) return [];
  const configs = [];
  for (const item of raw.slice(0, MAX_AI_PROVIDERS)) {
    if (!item || typeof item !== 'object') continue;
    const baseUrl = String(item.baseUrl || '').trim();
    const apiKey = String(item.apiKey || '').trim();
    const modelName = String(item.model || '').trim();
    if (!baseUrl || !apiKey || !modelName) continue;
    if (baseUrl.length > 500 || apiKey.length > 500 || modelName.length > 200) continue;
    try {
      configs.push({
        name: String(item.name || '').trim().slice(0, 60),
        endpoint: normalizeChatEndpoint(baseUrl),
        apiKey,
        model: modelName,
      });
    } catch (_) {
      // Bo qua cau hinh khong hop le, thu API tiep theo.
    }
  }
  return configs;
}

function parseJsonContent(raw) {
  let text = String(raw || '').trim();
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fence) text = fence[1].trim();
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start >= 0 && end > start) text = text.slice(start, end + 1);
  if (!text) throw new Error('Empty AI response');
  return JSON.parse(text);
}

function responseContent(content) {
  if (typeof content === 'string') return content.trim();
  if (Array.isArray(content)) {
    return content
      .map((part) => (typeof part === 'string' ? part : part?.text || ''))
      .join('')
      .trim();
  }
  return '';
}

async function callOpenAiCompatible({ endpoint, apiKey, model: modelName, prompt, timeoutMs }) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: modelName,
        messages: [{ role: 'user', content: prompt }],
      }),
      signal: controller.signal,
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      const error = new Error(payload?.error?.message || `API HTTP ${response.status}`);
      error.status = response.status;
      throw error;
    }
    const content = responseContent(payload?.choices?.[0]?.message?.content);
    if (!content) throw new Error('Empty AI response');
    return content;
  } finally {
    clearTimeout(timer);
  }
}

function isPermanentProviderError(error) {
  const status = Number(error?.status);
  return status === 401 || status === 403 || status === 404;
}

function isTimeoutError(error) {
  return /abort|timeout|timed out/i.test(String(error?.message || error || ''));
}

// Nhan dang "(n) y nghia" hoac "y nghia (n)" -> lay phan nghia.
function firstMeaning(raw) {
  const text = String(raw || '').trim();
  const leading = text.match(/^\s*\([^)]*\)\s*/);
  const withoutTag = leading ? text.slice(leading[0].length) : text.replace(/\([^)]*\)\s*$/, '');
  const picked = withoutTag.split(';')[0].trim();
  if (picked) return picked;
  const stripped = withoutTag.replace(/^\([^)]*\)/, '').trim();
  return stripped || text || 'it';
}

// Thu tu quan trong: 'pronoun' phai dung truoc 'noun', 'adverb' truoc 'verb',
// vi chuoi chua chuoi kia. Moi loai chap ca ten tieng Anh va nhan trong ngoac.
const TYPE_PATTERNS = [
  ['phrasal_verb', ['phrasal_verb', 'phrasal verb', '(phrasal v)']],
  ['idiom', ['idiom', '(idiom)']],
  ['collocation', ['collocation', '(coll)']],
  ['grammar', ['grammar', '(grammar)']],
  ['interjection', ['interjection', '(interj)']],
  ['adjective', ['adjective', '(adj)']],
  ['adverb', ['adverb', '(adv)']],
  ['preposition', ['preposition', '(prep)']],
  ['conjunction', ['conjunction', '(conj)']],
  ['pronoun', ['pronoun', '(pron)']],
  ['noun', ['noun', '(n)']],
  ['verb', ['verb', '(v)']],
];

function primaryType(raw) {
  const value = String(raw || '').toLowerCase();
  for (const [type, needles] of TYPE_PATTERNS) {
    if (needles.some((needle) => value.includes(needle))) return type;
  }
  return 'other';
}

// djb2: cung mot tu -> cung mot chi so, nen chay lai khong nhay cau.
function hashString(raw) {
  const text = String(raw || '');
  let hash = 5381;
  for (let i = 0; i < text.length; i += 1) {
    hash = ((hash << 5) + hash) ^ text.charCodeAt(i);
  }
  return Math.abs(hash);
}

// Khoa so sanh hai cau: bo khoang trang thua + ha chu thuong.
function normalizeSentenceKey(sentence) {
  return String(sentence || '').toLowerCase().replace(/\s+/g, ' ').trim();
}

// Tra ve phan tu chua tung dung. Het duoc -> lay phan tu cuoi (van ton tai
// cau hop le hon la tra ve rong). Ghi khoa vao `used` neu la Set de caller
// khong phai tu ghi.
function pickUniqueExample(candidates, used) {
  const list = (Array.isArray(candidates) ? candidates : []).filter(Boolean);
  if (list.length === 0) throw new Error('No example candidates');

  const seen = used instanceof Set ? used : new Set(used || []);
  for (const candidate of list) {
    const key = normalizeSentenceKey(candidate.sentence);
    if (!seen.has(key)) {
      seen.add(key);
      return candidate;
    }
  }
  return list[list.length - 1];
}

// Chep chu nghiem: mot danh sach chu nghiem x mot danh sach khung cau ->
// nhieu cau, tat ca deu khac nhau ve hinh thuc.
function buildBank(subjects, frames) {
  const bank = [];
  const seen = new Set();

  for (const frame of frames) {
    const usesSubject = frame.en(subjects[0].en, '__W__') !== frame.en(subjects[1].en, '__W__');
    const list = usesSubject ? subjects : [subjects[0]];

    for (const subject of list) {
      const probe = frame.en(subject.en, '__W__');
      if (seen.has(probe)) continue;
      seen.add(probe);
      bank.push((w, m) => ({
        sentence: frame.en(subject.en, w),
        translation: frame.vi(subject.vi, m, w),
      }));
    }
  }

  return bank;
}

// Nghinh chu de dung chung cho nhieu loai. Moi cap { en, vi } la mot chu nghinh;
// khuong cau ghep "chu nghinh + khung" nen khung phai la cum bo dong,
// vd: { en: 'The teacher explained', vi: 'Giáo viên đã giải thích' }.
const SUBJECTS = [
  { en: 'The teacher', vi: 'Giáo viên' },
  { en: 'My mother', vi: 'Mẹ tôi' },
  { en: 'My friend', vi: 'Bạn tôi' },
  { en: 'My brother', vi: 'Em trai tôi' },
  { en: 'My little sister', vi: 'Em gái tôi' },
  { en: 'The doctor', vi: 'Bác sĩ' },
  { en: 'My neighbour', vi: 'Hàng xóm của tôi' },
  { en: 'The students', vi: 'Các học sinh' },
  { en: 'My parents', vi: 'Bố mẹ tôi' },
  { en: 'The driver', vi: 'Tài xế' },
  { en: 'My cousin', vi: 'Em họ của tôi' },
  { en: 'The nurse', vi: 'Y tá' },
];

// Khung cau dung chung. Moi khuong deu chua du cho ca danh tu (ke dem/khong
// dem) va ca tu so nhieu.
const SHARED_FRAMES = [
  { en: (s, w) => `${s} talked about ${w} yesterday.`, vi: (s, m) => `${s} đã nói về ${m} hôm qua.` },
  { en: (s, w) => `${s} wrote a short note about ${w}.`, vi: (s, m) => `${s} đã viết một ghi chú ngắn về ${m}.` },
  { en: (s, w) => `${s} knows a lot about ${w}.`, vi: (s, m) => `${s} biết rất nhiều về ${m}.` },
  { en: (s, w) => `${s} asked me a question about ${w}.`, vi: (s, m) => `${s} đã hỏi tôi một câu về ${m}.` },
  { en: (s, w) => `${s} is very interested in ${w}.`, vi: (s, m) => `${s} rất quan tâm đến ${m}.` },
  { en: (s, w) => `${s} read an article about ${w} last week.`, vi: (s, m) => `${s} đã đọc một bài viết về ${m} tuần trước.` },
  { en: (s, w) => `${s} says the book is about ${w}.`, vi: (s, m) => `${s} nói cuốn sách nói về ${m}.` },
  { en: (s, w) => `${s} did not understand ${w} at all.`, vi: (s, m) => `${s} không hiểu ${m} chút nào.` },
];

// Bank moi: moi loai rat nhieu bien the cau. Cau cu "The {word} was easy to
// recognize." da bi loai vi import 100 tu tao ra 100 cau giong het nhau.
const TEMPLATE_BANK = {
  noun: buildBank(SUBJECTS, [
    ...SHARED_FRAMES,
    { en: (s, w) => `${s} put the ${w} on the table.`, vi: (s, m) => `${s} đã đặt ${m} lên bàn.` },
    { en: (s, w) => `This ${w} belongs to my friend.`, vi: (s, m) => `${m} này thuộc về bạn tôi.` },
    { en: (s, w) => `I bought a new ${w} last month.`, vi: (s, m) => `Tháng trước tôi đã mua một ${m} mới.` },
    { en: (s, w) => `${s} keeps the ${w} in a small box.`, vi: (s, m) => `${s} để ${m} trong một chiếc hộp nhỏ.` },
  ]),

  verb: buildBank(SUBJECTS, [
    { en: (s, w) => `${s} wants to ${w} this weekend.`, vi: (s, m) => `${s} muốn ${m} vào cuối tuần này.` },
    { en: (s, w) => `${s} tried to ${w} three times.`, vi: (s, m) => `${s} đã cố ${m} ba lần.` },
    { en: (s, w) => `We should ${w} before the meeting ends.`, vi: (s, m) => `Chúng ta nên ${m} trước khi cuộc họp kết thúc.` },
    { en: (s, w) => `${s} often forgets to ${w}.`, vi: (s, m) => `${s} hay quên ${m}.` },
    { en: (s, w) => `${s} learned how to ${w} last year.`, vi: (s, m) => `Năm ngoái ${s} đã học cách ${m}.` },
    { en: (s, w) => `Can you teach me to ${w}?`, vi: (s, m) => `Bạn có thể dạy tôi cách ${m} không?` },
    { en: (s, w) => `${s} must ${w} again tonight.`, vi: (s, m) => `${s} phải ${m} lại vào tối nay.` },
    { en: (s, w) => `They decide to ${w} every morning.`, vi: (s, m) => `Họ quyết định ${m} mỗi sáng.` },
  ]),

  phrasal_verb: buildBank(SUBJECTS, [
    { en: (s, w) => `${s} had to ${w} before the deadline.`, vi: (s, m) => `${s} phải ${m} trước hạn.` },
    { en: (s, w) => `${s} wants to ${w} one more time.`, vi: (s, m) => `${s} muốn ${m} thêm một lần nữa.` },
    { en: (s, w) => `Please ${w} and wait for me here.`, vi: (s, m) => `Xin hãy ${m} rồi đợi tôi ở đây.` },
    { en: (s, w) => `They often ${w} when the work is hard.`, vi: (s, m) => `Họ hay ${m} khi công việc khó.` },
    { en: (s, w) => `${s} will ${w} as soon as possible.`, vi: (s, m) => `${s} sẽ ${m} càng sớm càng tốt.` },
    { en: (s, w) => `We must not forget to ${w} today.`, vi: (s, m) => `Hôm nay chúng ta không được quên ${m}.` },
    { en: (s, w) => `${s} agreed to ${w} with the plan.`, vi: (s, m) => `${s} đồng ý ${m} với kế hoạch.` },
    { en: (s, w) => `Nobody expected him to ${w} so fast.`, vi: (s, m) => `Không ai ngờ anh ấy sẽ ${m} nhanh vậy.` },
  ]),

  adjective: buildBank(SUBJECTS, [
    { en: (s, w) => `The room feels ${w} this evening.`, vi: (s, m) => `Căn phòng trông ${m} vào tối nay.` },
    { en: (s, w) => `${s} was ${w} about the result.`, vi: (s, m) => `${s} rất ${m} về kết quả.` },
    { en: (s, w) => `The soup tastes a bit ${w}.`, vi: (s, m) => `Món súp có vị hơi ${m}.` },
    { en: (s, w) => `We had a ${w} morning at the office.`, vi: (s, m) => `Chúng tôi đã có một buổi sáng ${m} ở văn phòng.` },
    { en: (s, w) => `This street is very ${w} at night.`, vi: (s, m) => `Con đường này rất ${m} vào ban đêm.` },
    { en: (s, w) => `${s} sounds ${w} on the phone.`, vi: (s, m) => `Qua điện thoại ${s} nghe ${m}.` },
    { en: (s, w) => `The exam was ${w} for all of us.`, vi: (s, m) => `Bài kiểm tra thật ${m} với tất cả chúng ta.` },
    { en: (s, w) => `She looks ${w} in that blue coat.`, vi: (s, m) => `Cô ấy trông ${m} trong chiếc áo khoác xanh đó.` },
  ]),

  adverb: buildBank(SUBJECTS, [
    { en: (s, w) => `${s} answered the question ${w}.`, vi: (s, m) => `${s} đã trả lời câu hỏi ${m}.` },
    { en: (s, w) => `${s} spoke ${w} during the meeting.`, vi: (s, m) => `${s} đã nói ${m} trong cuộc họp.` },
    { en: (s, w) => `She finished the work ${w} yesterday.`, vi: (s, m) => `Cô ấy đã xong công việc ${m} hôm qua.` },
    { en: (s, w) => `${s} walked to school ${w} this morning.`, vi: (s, m) => `Sáng nay ${s} đi bộ tới trường ${m}.` },
    { en: (s, w) => `He explained the rule ${w} to us.`, vi: (s, m) => `Anh ấy đã giải thích quy tắc ${m} cho chúng ta.` },
    { en: (s, w) => `${s} typed the letter ${w}.`, vi: (s, m) => `${s} đã gõ lách thư ${m}.` },
    { en: (s, w) => `The baby slept ${w} all afternoon.`, vi: (s, m) => `Em bé đã ngủ ${m} cả buổi chiều.` },
    { en: (s, w) => `${s} opened the window ${w}.`, vi: (s, m) => `${s} đã mở cửa sổ ${m}.` },
  ]),

  preposition: buildBank(SUBJECTS, [
    { en: (s, w) => `The cat is hiding ${w} the box.`, vi: (s, m) => `Con mèo đang nấp ${m} chiếc hộp.` },
    { en: (s, w) => `${s} put the book ${w} the desk.`, vi: (s, m) => `${s} đặt cuốn sách ${m} bàn làm việc.` },
    { en: (s, w) => `The shop is ${w} the bank.`, vi: (s, m) => `Cửa hàng nằm ${m} ngân hàng.` },
    { en: (s, w) => `${s} grew up ${w} a small town.`, vi: (s, m) => `${s} lớn lên ${m} một thị trấn nhỏ.` },
    { en: (s, w) => `She waited for the bus ${w} the corner.`, vi: (s, m) => `Cô ấy đợi xe buýt ${m} góc đường.` },
    { en: (s, w) => `The keys are still ${w} my bag.`, vi: (s, m) => `Chìa khóa vẫn còn ${m} chiếc túi của tôi.` },
    { en: (s, w) => `${s} arrived home just ${w} the party started.`, vi: (s, m) => `${s} về nhà vừa đúng ${m} bữa tiệc bắt đầu.` },
    { en: (s, w) => `We talked about the trip ${w} dinner.`, vi: (s, m) => `Chúng tôi nói về chuyến đi ${m} bữa tối.` },
  ]),

  conjunction: buildBank(SUBJECTS, [
    { en: (s, w) => `${s} stayed home, ${w} it was raining.`, vi: (s, m) => `${s} ở nhà, ${m} trời đang mưa.` },
    { en: (s, w) => `She smiled, ${w} she passed the test.`, vi: (s, m) => `Cô ấy cười, ${m} cô ấy đã đỗ kỳ thi.` },
    { en: (s, w) => `${s} left early, ${w} the class was over.`, vi: (s, m) => `${s} về sớm, ${m} giờ học đã kết thúc.` },
    { en: (s, w) => `I called you, ${w} you were not there.`, vi: (s, m) => `Tôi đã gọi cho bạn, ${m} bạn không có ở đó.` },
    { en: (s, w) => `${s} was tired, ${w} the work was long.`, vi: (s, m) => `${s} rất mệt, ${m} công việc kéo dài.` },
    { en: (s, w) => `She was happy, ${w} the news was good.`, vi: (s, m) => `Cô ấy rất vui, ${m} tin tức rất tốt.` },
    { en: (s, w) => `${s} kept quiet, ${w} the baby was sleeping.`, vi: (s, m) => `${s} giữ im lặng, ${m} em bé đang ngủ.` },
    { en: (s, w) => `He walked away, ${w} he was angry.`, vi: (s, m) => `Anh ấy bỏ đi, ${m} anh ấy rất giận.` },
  ]),


  pronoun: buildBank(SUBJECTS, [
    { en: (s, w) => `${w} is waiting in front of the gate.`, vi: (s, m) => `${m} đang đứng đợi trước cổng.` },
    { en: (s, w) => `${w} called me twice this morning.`, vi: (s, m) => `Sáng nay ${m} đã gọi cho tôi hai lần.` },
    { en: (s, w) => `${w} always help with the dishes.`, vi: (s, m) => `${m} luôn giúp rửa bát.` },
    { en: (s, w) => `I gave ${w} my old notebook.`, vi: (s, m) => `Tôi đã đưa ${m} cuốn sổ cũ của tôi.` },
    { en: (s, w) => `${w} live next to the small park.`, vi: (s, m) => `${m} sống ngay cạnh công viên nhỏ.` },
    { en: (s, w) => `${w} were very happy with the news.`, vi: (s, m) => `${m} rất vui với tin tức đó.` },
  ]),

  interjection: buildBank(SUBJECTS, [
    { en: (s, w) => `"${w}!" ${s} shouted at the door.`, vi: (s, m) => `"${m}!" ${s} hét lên ở cửa.` },
    { en: (s, w) => `"${w}!" she cried and ran away.`, vi: (s, m) => `"${m}!" cô ấy kêu lên rồi bỏ chạy.` },
    { en: (s, w) => `"${w}," ${s} said with a big smile.`, vi: (s, m) => `"${m}," ${s} nói với nụ cười rất tươi.` },
    { en: (s, w) => `${s} said "${w}" and looked at me.`, vi: (s, m) => `${s} nói "${m}" rồi nhìn tôi.` },
    { en: (s, w) => `"${w}! That was close," ${s} whispered.`, vi: (s, m) => `"${m}! Suýt nữa thì..." ${s} thì thầm.` },
    { en: (s, w) => `${s} could not say "${w}" out loud.`, vi: (s, m) => `${s} không dám nói "${m}" to.` },
    { en: (s, w) => `"${w}," ${s} replied after a long pause.`, vi: (s, m) => `"${m}," ${s} đáp lại sau một khoảng lặng dài.` },
    { en: (s, w) => `Everyone shouted "${w}!" when they heard it.`, vi: (s, m) => `Mọi người đều hét "${m}!" khi nghe thấy.` },
  ]),

  idiom: buildBank(SUBJECTS, [
    { en: (s, w) => `${s} said "${w}" during the meeting.`, vi: (s, m, w) => `${s} đã nói "${w}" trong cuộc họp.` },
    { en: (s, w) => `Can you explain "${w}" to me again?`, vi: (s, m, w) => `Bạn giải thích lại "${w}" cho tôi được không?` },
    { en: (s, w) => `We use "${w}" almost every week at work.`, vi: (s, m, w) => `Chúng tôi dùng "${w}" gần như mỗi tuần ở công sở.` },
    { en: (s, w) => `${s} learned "${w}" from an English movie.`, vi: (s, m, w) => `${s} học "${w}" từ một bộ phim tiếng Anh.` },
    { en: (s, w) => `"${w}" sounds natural in this situation.`, vi: (s, m, w) => `"${w}" nghe rất tự nhiên trong tình huống này.` },
    { en: (s, w) => `Please write "${w}" in your notebook.`, vi: (s, m, w) => `Xin hãy viết "${w}" vào sổ tay của bạn.` },
    { en: (s, w) => `${s} did not know "${w}" before this lesson.`, vi: (s, m, w) => `Trước bài học này ${s} chưa biết "${w}".` },
    { en: (s, w) => `My teacher often uses "${w}" in class.`, vi: (s, m, w) => `Giáo viên của tôi hay dùng "${w}" trong lớp.` },
  ]),

  collocation: buildBank(SUBJECTS, [
    { en: (s, w) => `${s} tried to make a quick ${w} today.`, vi: (s, m) => `Hôm nay ${s} cố tạo ra một ${m} nhanh chóng.` },
    { en: (s, w) => `We often discuss this ${w} in class.`, vi: (s, m) => `Chúng tôi thường bàn luận về ${m} này trong lớp.` },
    { en: (s, w) => `${s} wrote a short ${w} for the website.`, vi: (s, m) => `${s} đã viết một ${m} ngắn cho trang web.` },
    { en: (s, w) => `I need to improve my ${w} skills.`, vi: (s, m) => `Tôi cần cải thiện kỹ năng ${m} của mình.` },
    { en: (s, w) => `${s} made a good ${w} with the first try.`, vi: (s, m) => `${s} đã có một ${m} tốt ngay lần đầu.` },
    { en: (s, w) => `Please give me some ${w} before Friday.`, vi: (s, m) => `Xin hãy cho tôi một ít ${m} trước thứ Sáu.` },
    { en: (s, w) => `${s} hopes for a better ${w} this year.`, vi: (s, m) => `${s} hy vọng có một ${m} tốt hơn trong năm nay.` },
    { en: (s, w) => `We had a long ${w} about the new plan.`, vi: (s, m) => `Chúng tôi đã có một cuộc ${m} dài về kế hoạch mới.` },
  ]),

  grammar: buildBank(SUBJECTS, [
    { en: (s, w) => `This sentence uses "${w}" in the right place.`, vi: (s, m, w) => `Câu này dùng "${w}" đúng chỗ.` },
    { en: (s, w) => `Can you find "${w}" in this sentence?`, vi: (s, m) => `Bạn tìm thấy "${m}" trong câu này không?` },
    { en: (s, w) => `${s} explained the rule of "${w}" to us.`, vi: (s, m) => `${s} đã giải thích quy tắc của "${m}" cho chúng tôi.` },
    { en: (s, w) => `There is only one "${w}" in this paragraph.`, vi: (s, m) => `Trong đoạn văn này chỉ có một "${m}".` },
    { en: (s, w) => `Check the position of "${w}" before you write.`, vi: (s, m) => `Hãy kiểm tra vị trí của "${m}" trước khi viết.` },
    { en: (s, w) => `${s} forgot the rule about "${w}" yesterday.`, vi: (s, m) => `Hôm qua ${s} đã quên quy tắc về "${m}".` },
    { en: (s, w) => `The teacher wrote "${w}" on the board.`, vi: (s, m) => `Giáo viên đã viết "${m}" lên bảng.` },
    { en: (s, w) => `I made a mistake with "${w}" in my test.`, vi: (s, m) => `Tôi đã sai với "${m}" trong bài kiểm tra.` },
  ]),

  other: buildBank(SUBJECTS, [
    { en: (s, w) => `${s} wrote down the word "${w}" today.`, vi: (s, m, w) => `Hôm nay ${s} đã ghi lại từ "${w}".` },
    { en: (s, w) => `I met someone who used "${w}" yesterday.`, vi: (s, m, w) => `Hôm qua tôi gặp một người dùng "${w}".` },
    { en: (s, w) => `"${w}" was the last word in the lesson.`, vi: (s, m, w) => `"${w}" là từ cuối cùng trong bài học.` },
    { en: (s, w) => `Please add "${w}" to my vocabulary list.`, vi: (s, m, w) => `Xin hãy thêm "${w}" vào danh sách từ của tôi.` },
    { en: (s, w) => `${s} asked me the meaning of "${w}".`, vi: (s, m, w) => `${s} hỏi tôi nghĩa của "${w}".` },
    { en: (s, w) => `I saw "${w}" in the newspaper this morning.`, vi: (s, m, w) => `Sáng nay tôi thấy "${w}" trên báo.` },
    { en: (s, w) => `${s} looked up "${w}" in the dictionary.`, vi: (s, m, w) => `${s} đã tra "${w}" trong từ điển.` },
    { en: (s, w) => `We keep "${w}" at the end of every lesson.`, vi: (s, m, w) => `Chúng tôi ghi nhớ "${w}" ở cuối mỗi bài học.` },
  ]),
};

// Mau tinh khi AI loi/timeout/thieu key. Chon template bang hash cua tu nen cung
// mot tu -> cung mot cau (chay lai khong nhay cau), con `used` dam bao cau do
// chua tung xuat hien trong lo hien tai.
function templateExample({ word, meaning, wordType }, opts = {}) {
  const w = String(word || '').trim();
  const m = firstMeaning(meaning);
  const type = primaryType(`${wordType || ''} ${meaning || ''}`);
  const bank = TEMPLATE_BANK[type] || TEMPLATE_BANK.other;

  // Xoay vong danh sach theo hash de phan bo deu, roi dung `used` chon phan
  // tu chua bi trung.
  const start = bank.length > 0 ? hashString(`${type}:${w.toLowerCase()}`) % bank.length : 0;
  const candidates = bank
    .map((_, i) => bank[(start + i) % bank.length])
    .map((make) => make(w, m));
  const picked = pickUniqueExample(candidates, opts.used);

  return { sentence: picked.sentence, translation: picked.translation, target: w };
}




function clean(value, max) {
  const s = typeof value === 'string' ? value.trim() : '';
  return s.length > max ? '' : s;
}

async function callGemini({ apiKey, modelName, prompt, timeoutMs, temperature = 0.95 }) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(
      `${GEMINI_URL}/${modelName}:generateContent`,
      {
        method: 'POST',
        headers: { 'x-goog-api-key': apiKey, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { responseMimeType: 'application/json', temperature },
        }),
        signal: controller.signal,
      },
    );
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      const message = payload?.error?.message || `Gemini HTTP ${response.status}`;
      throw new Error(message);
    }
    const raw = payload?.candidates?.[0]?.content?.parts
      ?.map((part) => part?.text || '')
      .join('')
      .trim() || '';
    if (!raw) throw new Error('Empty AI response');
    return JSON.parse(raw);
  } finally {
    clearTimeout(timer);
  }
}

// Boi canh goi y cho cau vi du. Id phai trung voi AiExampleContext cua app.
const EXAMPLE_CONTEXTS = {
  daily: 'everyday life',
  work: 'work and the office',
  it: 'IT and technology',
  study: 'study and exams',
  travel: 'travel',
  business: 'business',
  health: 'health and daily wellbeing',
  media: 'films, series and entertainment',
};

const MAX_STYLE_CUSTOM = 300;

// Mac dinh: nghia nguoi hoc can + boi canh doi song / cong viec / IT.
const DEFAULT_EXAMPLE_STYLE = Object.freeze({
  contexts: ['daily', 'work', 'it'],
  skipRareSenses: true,
  custom: '',
});

function normalizeStyleCustom(raw) {
  return String(raw || '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, MAX_STYLE_CUSTOM);
}

// Chuan hoa cai dat "cach AI sinh vi du" do client gui len (khong tin du lieu client).
function normalizeExampleStyle(raw) {
  const source = raw && typeof raw === 'object' ? raw : {};
  const contexts = Array.isArray(source.contexts)
    ? [...new Set(source.contexts
      .map((id) => String(id || '').trim().toLowerCase())
      .filter((id) => Object.prototype.hasOwnProperty.call(EXAMPLE_CONTEXTS, id)))]
      .slice(0, Object.keys(EXAMPLE_CONTEXTS).length)
    : [...DEFAULT_EXAMPLE_STYLE.contexts];
  const skipRareSenses =
    source.skipRareSenses === undefined || source.skipRareSenses === null
      ? DEFAULT_EXAMPLE_STYLE.skipRareSenses
      : Boolean(source.skipRareSenses);
  return { contexts, skipRareSenses, custom: normalizeStyleCustom(source.custom) };
}

// Khoi "Learner preferences" chen vao prompt. Rong -> '' (prompt nhu cu).
function buildStylePrompt(rawStyle, { contexts = true } = {}) {
  const style = normalizeExampleStyle(rawStyle);
  const lines = [];
  if (style.skipRareSenses) {
    lines.push(
      '- Teach the sense a Vietnamese learner actually needs, not the rarest or most literal one: ' +
      'for "concrete" use "cụ thể, rõ ràng" (not the building material), ' +
      'for "harness" use "tận dụng, khai thác" (not horse tack).',
    );
  }
  if (contexts && style.contexts.length > 0) {
    lines.push(
      `- When it fits naturally, set the scene in: ${style.contexts.map((id) => EXAMPLE_CONTEXTS[id]).join(', ')}.`,
    );
  }
  if (style.custom) {
    lines.push(`- Extra notes from the learner: ${style.custom}`);
  }
  return lines.length === 0 ? '' : `Learner preferences:\n${lines.join('\n')}\n\n`;
}

function buildExamplePrompt({ word, meaning, wordType, topicTag, style }) {
  const w = String(word || '').trim();
  const topic = String(topicTag || '').trim();
  return `You write ONE natural English example sentence for a Vietnamese learner, plus its natural Vietnamese translation.

Create a fresh, concrete scene that makes the meaning obvious: a person doing something, a place, an object or a moment in time. Let the context teach the meaning instead of explaining it.

Rules:
- Exactly one sentence, 5-20 words.
- The sentence MUST contain the target word exactly as written (capitalization may differ).
- Do not follow a fixed sentence pattern and do not reuse clichés. Avoid openings like "The ___ was ...", "I usually ...", "Every day ..." or "Today ..." unless that is truly the most natural choice.
- Write in natural, correct English at whatever level the word itself needs: simple for common words, more advanced for advanced words. No definition, no quotes around the sentence.
- The Vietnamese translation must be natural spoken Vietnamese and match the sentence.

${buildStylePrompt(style)}Word: ${w}
Part of speech: ${wordType || 'unknown'}
Vietnamese meaning: ${firstMeaning(meaning)}
Topic: ${topic || 'general'}

Reply with JSON only: {"sentence":"...","translation":"..."}`;
}

function normalizeGeneratedExample(parsed, word) {
  const sentence = clean(parsed?.sentence, 240);
  const translation = clean(parsed?.translation, 1000);
  if (!sentence || !translation) throw new Error('AI returned an empty example');
  const target = String(word || '').trim();
  if (target && !sentence.toLowerCase().includes(target.toLowerCase())) {
    throw new Error('AI example is missing the target word');
  }
  return { sentence, translation, target };
}

// Loai tu ma app ho tro (trung voi CATEGORIES cua api va kWordTypeKeys cua app).
const WORD_TYPES = [
  'noun', 'verb', 'adjective', 'adverb', 'preposition',
  'conjunction', 'pronoun', 'interjection', 'phrasal_verb',
  'idiom', 'collocation', 'grammar',
];

// Nghia tieng Viet + loai tu cho mot tu nguoi dung dan vao khi import.
function buildWordInfoPrompt({ word, style }) {
  const w = String(word || '').trim();
  return `You classify ONE English word or phrase for a Vietnamese learner.

Rules:
- "meaning" is a short, natural Vietnamese meaning (2-8 words). No part of speech tag, no quotes, no explanation, no English.
- "wordType" is exactly one value from this list: ${WORD_TYPES.join(', ')}.
  * phrasal_verb for two-word verbs (give up, look after)
  * idiom for idioms and fixed figurative expressions
  * collocation for common word pairs or short phrases that are not idioms
  * grammar for grammar patterns or structures
  * interjection for exclamations (wow, oops)
- Pick the meaning a learner most needs first; do not list several senses.

${buildStylePrompt(style, { contexts: false })}Word: ${w}

Reply with JSON only: {"meaning":"...","wordType":"..."}`;
}

function normalizeGeneratedWordInfo(parsed, word) {
  const meaning = clean(parsed?.meaning, 200);
  if (!meaning) throw new Error('AI returned an empty meaning for word info');
  const rawType = String(parsed?.wordType || '')
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, '_');
  const wordType = rawType === 'exclamation' ? 'interjection' : rawType;
  if (!WORD_TYPES.includes(wordType)) {
    throw new Error(`AI returned an unknown word type for word info: ${rawType}`);
  }
  return { word: String(word || '').trim(), meaning, wordType };
}

function exampleErrorMessage(error) {
  const raw = String(error?.message || error || '');
  if (/Missing GEMINI_API_KEY/i.test(raw)) {
    return 'Máy chủ chưa cấu hình AI (GEMINI_API_KEY).';
  }
  if (/401|403|unauthorized|forbidden|invalid api key|api key.*invalid/i.test(raw)) {
    return 'API key không hợp lệ hoặc không có quyền.';
  }
  if (/404|model.*not found|unknown model|does not exist/i.test(raw)) {
    return 'Không tìm thấy model trên nhà cung cấp API.';
  }
  if (/abort|timeout|timed out/i.test(raw)) {
    return 'AI phản hồi quá chậm. Vui lòng thử lại.';
  }
  if (/fetch failed|network|ENOTFOUND|ECONN|socket/i.test(raw)) {
    return 'Không kết nối được tới AI. Vui lòng thử lại.';
  }
  if (/429|quota|rate limit|too many/i.test(raw)) {
    return 'AI đang quá tải. Vui lòng thử lại sau ít phút.';
  }
  if (/word info|unknown word type|empty meaning/i.test(raw)) {
    return 'AI không lấy được nghĩa cho từ này.';
  }
  if (/empty|missing the target|length|duplicat|json|unexpected|invalid/i.test(raw)) {
    return 'AI trả về câu ví dụ không hợp lệ. Vui lòng thử lại.';
  }
  return `Không tạo được ví dụ: ${raw}`;
}

function createAiChain(rawConfigs) {
  const configs = sanitizeAiConfigs(rawConfigs);
  const disabled = new Set();
  const timeoutCounts = new Map();
  let preferred = 0;

  // Goi lan luot cac provider da cau hinh, roi den Gemini tu env. `parse` bien
  // JSON tho thanh ket qua cuoi va co the nem loi de thu provider ke tiep.
  async function run(prompt, parse, { timeoutMs = 10000, deadline } = {}) {
    let lastError;
    let deadlineHit = false;

    // Gioi han tung lan goi theo deadline chung de request khong vuot 60s.
    const attemptTimeout = () => {
      if (!deadline) return timeoutMs;
      const remaining = deadline - Date.now();
      if (remaining < 1000) {
        deadlineHit = true;
        return 0;
      }
      return Math.min(timeoutMs, remaining);
    };

    const order = configs.map((_, index) => index);
    if (preferred > 0 && order.includes(preferred)) {
      order.splice(order.indexOf(preferred), 1);
      order.unshift(preferred);
    }

    for (const index of order) {
      if (disabled.has(index)) continue;
      const attemptMs = attemptTimeout();
      if (!attemptMs) break;
      const config = configs[index];
      try {
        const raw = await callOpenAiCompatible({
          endpoint: config.endpoint,
          apiKey: config.apiKey,
          model: config.model,
          prompt,
          timeoutMs: attemptMs,
        });
        const value = parse(parseJsonContent(raw));
        preferred = index;
        timeoutCounts.delete(index);
        return value;
      } catch (error) {
        lastError = error;
        if (isTimeoutError(error)) {
          const count = (timeoutCounts.get(index) || 0) + 1;
          timeoutCounts.set(index, count);
          // Timeout 2 lan lien tiep -> bo qua provider nay cho cac tu sau.
          if (count >= 2) disabled.add(index);
        }
        if (isPermanentProviderError(error)) disabled.add(index);
      }
    }

    const apiKey = process.env.GEMINI_API_KEY || process.env.XAI_API_KEY;
    if (apiKey) {
      for (const modelName of [model(), GEMINI_FALLBACK_MODEL]) {
        const attemptMs = attemptTimeout();
        if (!attemptMs) break;
        try {
          const parsed = await callGemini({ apiKey, modelName, prompt, timeoutMs: attemptMs });
          return parse(parsed);
        } catch (error) {
          lastError = error;
        }
      }
    }

    if (deadlineHit) throw new Error('AI phản hồi quá chậm. Vui lòng thử lại.');
    throw new Error(exampleErrorMessage(lastError || new Error('Missing GEMINI_API_KEY')));
  }

  async function generate(
    { word, meaning, wordType, topicTag, style },
    { timeoutMs = 10000, used, deadline } = {},
  ) {
    const w = String(word || '').trim();
    if (!w) throw new Error('Thiếu từ để tạo ví dụ.');
    const prompt = buildExamplePrompt({ word: w, meaning, wordType, topicTag, style });
    return run(
      prompt,
      (parsed) => {
        const example = normalizeGeneratedExample(parsed, w);
        if (used instanceof Set) {
          const key = normalizeSentenceKey(example.sentence);
          if (used.has(key)) throw new Error('AI example is duplicated in this batch');
          used.add(key);
        }
        return example;
      },
      { timeoutMs, deadline },
    );
  }

  // Nghia tieng Viet + loai tu cho tu nguoi dung dan vao (import / sua tu).
  async function generateWordInfo({ word }, { timeoutMs = 10000, deadline, style } = {}) {
    const w = String(word || '').trim();
    if (!w) throw new Error('Thiếu từ để lấy nghĩa.');
    return run(
      buildWordInfoPrompt({ word: w, style }),
      (parsed) => normalizeGeneratedWordInfo(parsed, w),
      { timeoutMs, deadline },
    );
  }

  return { generate, generateWordInfo, configs };
}

async function generateExample(input, { timeoutMs = 10000, used, aiConfigs, chain } = {}) {
  const activeChain = chain || createAiChain(aiConfigs);
  return activeChain.generate(input, { timeoutMs, used });
}

async function testAiProvider(raw, { timeoutMs = 15000 } = {}) {
  const configs = sanitizeAiConfigs([raw]);
  if (configs.length === 0) {
    return { ok: false, latencyMs: 0, message: 'Base URL, API key hoặc model không hợp lệ.' };
  }
  const config = configs[0];
  const startedAt = Date.now();
  try {
    await callOpenAiCompatible({
      endpoint: config.endpoint,
      apiKey: config.apiKey,
      model: config.model,
      prompt: 'Reply with exactly: OK',
      timeoutMs,
    });
    return { ok: true, latencyMs: Date.now() - startedAt, message: 'Kết nối thành công.' };
  } catch (error) {
    return { ok: false, latencyMs: Date.now() - startedAt, message: exampleErrorMessage(error) };
  }
}

module.exports = {
  TEMPLATE_BANK,
  WORD_TYPES,
  DEFAULT_EXAMPLE_STYLE,
  EXAMPLE_CONTEXTS,
  MAX_STYLE_CUSTOM,
  buildExamplePrompt,
  buildStylePrompt,
  buildWordInfoPrompt,
  callOpenAiCompatible,
  createAiChain,
  exampleErrorMessage,
  firstMeaning,
  generateExample,
  normalizeChatEndpoint,
  normalizeExampleStyle,
  normalizeGeneratedExample,
  normalizeGeneratedWordInfo,
  normalizeSentenceKey,
  parseJsonContent,
  pickUniqueExample,
  primaryType,
  sanitizeAiConfigs,
  templateExample,
  testAiProvider,
  MAX_AI_PROVIDERS,
  // Ten moi theo provider Gemini; giu ten cu de test/script cu van chay.
  GEMINI_MODEL,
  GEMINI_FALLBACK_MODEL,
  XAI_MODEL: GEMINI_MODEL,
};
