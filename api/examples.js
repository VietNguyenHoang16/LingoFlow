const {
  ensureExampleSchema,
  mapWord,
  parsePageParams,
  query,
  requireUserId,
  sendData,
  sendError,
  setCors,
} = require('./_lib/examples');

module.exports = async function handler(req, res) {
  setCors(res);

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (req.method !== 'GET') {
    res.status(405).json({ error: { code: 'METHOD_NOT_ALLOWED', message: 'Method not allowed.' } });
    return;
  }

  try {
    await ensureExampleSchema();
    const userId = await requireUserId(req);
    const params = parsePageParams(new URL(req.url || '/', 'http://localhost').searchParams);
    const values = [userId];
    const filters = ['vl.user_id = $1'];

    if (params.query) {
      values.push(`%${params.query}%`);
      const index = values.length;
      filters.push(`(
        vw.word ILIKE $${index}
        OR vw.meaning ILIKE $${index}
        OR COALESCE(vw.topic_tag, '') ILIKE $${index}
      )`);
    }
    if (params.hasExample !== null) {
      filters.push(params.hasExample
        ? '(vw.example_sentence IS NOT NULL AND vw.example_sentence <> \'\')'
        : '(vw.example_sentence IS NULL OR vw.example_sentence = \'\')');
    }

    const limitIndex = values.push(params.pageSize);
    const offsetIndex = values.push((params.page - 1) * params.pageSize);
    const rows = await query(
      `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.topic_tag,
              vw.example_sentence, vw.example_translation, vw.example_target,
              COUNT(*) OVER() AS total_count
       FROM vocabulary_words vw
       JOIN vocabulary_lists vl ON vw.list_id = vl.id
       WHERE ${filters.join(' AND ')}
       ORDER BY LOWER(vw.word) ASC, vw.id ASC
       LIMIT $${limitIndex} OFFSET $${offsetIndex}`,
      values,
    );

    const totalItems = rows.length === 0 ? 0 : Number(rows[0].total_count) || 0;
    sendData(res, {
      data: rows.map(mapWord),
      pagination: {
        page: params.page,
        pageSize: params.pageSize,
        totalItems,
        totalPages: Math.ceil(totalItems / params.pageSize),
      },
    });
  } catch (error) {
    sendError(res, error);
  }
};
