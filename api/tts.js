module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({error: 'Method not allowed'});
  }

  const text = typeof req.query?.q === 'string' ? req.query.q.trim() : '';
  if (!text || text.length > 2000) {
    return res.status(400).json({error: 'q must contain 1-2000 characters'});
  }

  const target = new URL('https://translate.google.com/translate_tts');
  target.search = new URLSearchParams({
    ie: 'UTF-8',
    client: 'tw-ob',
    tl: 'en',
    q: text,
  });

  try {
    const upstream = await fetch(target, {
      headers: {
        Accept: 'audio/mpeg',
        'User-Agent': 'Mozilla/5.0',
      },
    });

    if (!upstream.ok) {
      return res.status(502).json({error: `TTS upstream returned ${upstream.status}`});
    }

    const audio = Buffer.from(await upstream.arrayBuffer());
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cache-Control', 'public, s-maxage=86400');
    res.setHeader('Content-Type', upstream.headers.get('content-type') || 'audio/mpeg');
    return res.status(200).send(audio);
  } catch (_) {
    return res.status(502).json({error: 'TTS upstream unavailable'});
  }
}
