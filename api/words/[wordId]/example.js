const {
  ApiError,
  ensureExampleSchema,
  findOwnedWord,
  mapWord,
  parseWordId,
  query,
  readJsonBody,
  requireUserId,
  sendData,
  sendError,
  setCors,
  validateExamplePayload,
} = require('../../_lib/examples');

function getWordId(req) {
  let value = req.query?.wordId;
  if (Array.isArray(value)) value = value[0];
  if (!value) {
    const match = (req.url || '').match(/\/words\/([^/]+)\/example/);
    value = match?.[1];
  }
  return parseWordId(value);
}

async function getOwnedWordOrThrow(wordId, userId) {
  const row = await findOwnedWord(wordId, userId);
  if (!row) throw new ApiError(404, 'NOT_FOUND', 'Word not found.');
  return row;
}

module.exports = async function handler(req, res) {
  setCors(res);

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (!['GET', 'PUT', 'DELETE'].includes(req.method)) {
    res.status(405).json({ error: { code: 'METHOD_NOT_ALLOWED', message: 'Method not allowed.' } });
    return;
  }

  try {
    await ensureExampleSchema();
    const wordId = getWordId(req);
    const userId = await requireUserId(req);

    if (req.method === 'GET') {
      sendData(res, mapWord(await getOwnedWordOrThrow(wordId, userId)));
      return;
    }

    if (req.method === 'PUT') {
      const example = validateExamplePayload(readJsonBody(req));
      const rows = await query(
        `UPDATE vocabulary_words vw
         SET example_sentence = $1, example_translation = $2, example_target = $3
         WHERE vw.id = $4
           AND vw.list_id IN (SELECT id FROM vocabulary_lists WHERE user_id = $5)
         RETURNING vw.id, vw.word, vw.pronunciation, vw.meaning, vw.topic_tag,
                   vw.example_sentence, vw.example_translation, vw.example_target`,
        [example.sentence, example.translation, example.target, wordId, userId],
      );
      if (rows.length === 0) throw new ApiError(404, 'NOT_FOUND', 'Word not found.');
      sendData(res, mapWord(rows[0]));
      return;
    }

    const rows = await query(
      `UPDATE vocabulary_words vw
       SET example_sentence = NULL, example_translation = NULL, example_target = NULL
       WHERE vw.id = $1
         AND vw.list_id IN (SELECT id FROM vocabulary_lists WHERE user_id = $2)
       RETURNING vw.id`,
      [wordId, userId],
    );
    if (rows.length === 0) throw new ApiError(404, 'NOT_FOUND', 'Word not found.');
    sendData(res, { deleted: true });
  } catch (error) {
    sendError(res, error);
  }
};
