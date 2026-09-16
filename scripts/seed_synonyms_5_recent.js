const BASE_URL = process.env.LINGOFLOW_API_URL || 'https://vocab-virid.vercel.app';

function args(argv) {
  const o = {};
  for (let i = 0; i < argv.length; i += 1) {
    if (!argv[i].startsWith('--')) continue;
    const k = argv[i].slice(2);
    const v = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : true;
    o[k] = v;
    if (v !== true) i += 1;
  }
  return o;
}

function phone(raw) {
  let d = String(raw || '').replace(/\D/g, '');
  if (d.length === 10 && d.startsWith('0')) d = d.slice(1);
  if (d.length !== 9) throw new Error('Phone phai co 9 chu so (vd 09xxxxxxx).');
  return `+84${d}`;
}

async function api(action, data, token) {
  const r = await fetch(`${BASE_URL}/api/lingoflow`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify({ action, data }),
  });
  const j = await r.json();
  if (!r.ok) throw new Error(j?.error || `HTTP ${r.status}`);
  return j.data;
}

// Curated tay cho demo. Them tu cua ban vao day neu muon.
const CURATED = {
  solid: { common: 'good · reliable · decent' },
};

async function dictTop3(word) {
  try {
    const r = await fetch(`https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(word)}`);
    if (!r.ok) return null;
    const j = await r.json();
    const syns = (j?.[0]?.meanings || [])
      .flatMap((m) => (m.definitions || []).flatMap((d) => d.synonyms || []))
      .map((s) => String(s).trim())
      .filter(Boolean);
    const uniq = [...new Set(syns.map((s) => s.toLowerCase()))].slice(0, 3);
    if (!uniq.length) return null;
    return { common: uniq.join(' · ') };
  } catch (_) {
    return null;
  }
}

async function main() {
  const a = args(process.argv.slice(2));
  if (!a.phone) {
    console.log('Dung: node scripts/seed_synonyms_5_recent.js --phone 09xxxxxxx [--dry]');
    process.exit(1);
  }
  const login = await api('loginUser', { phoneNumber: phone(a.phone) });
  const { userId, token } = login;
  const recents = await api('getRecentWords', { userId, limit: 5 }, token);
  console.log(`5 tu moi nhat (${recents.length}):`);
  for (const w of recents) console.log(`- #${w.id} ${w.word} | meaning=${w.meaning} | common=[${w.common_synonyms || ''}]`);

  if (a.dry) return;
  for (const w of recents) {
    if ((w.common_synonyms || '').trim()) {
      console.log(`skip #${w.id} ${w.word} (da co synonyms)`);
      continue;
    }
    const key = String(w.word || '').toLowerCase();
    let seed = CURATED[key] || (await dictTop3(w.word));
    if (!seed) {
      console.log(`skip #${w.id} ${w.word} (khong tim duoc synonyms, tu nhap tay trong app)`);
      continue;
    }
    await api('updateVocabularyWordDetails', {
      userId,
      wordId: w.id,
      meaning: w.meaning || '',
      pronunciation: w.pronunciation || '',
      fullDetails: w.full_details || '',
      wordType: w.word_type || '',
      topicTag: w.topic_tag || '',
      commonSynonyms: seed.common || '',
    }, token);
    console.log(`updated #${w.id} ${w.word} -> common=[${seed.common}]`);
  }
}

main().catch((e) => { console.error('Loi:', e.message); process.exit(1); });
