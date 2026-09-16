const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

let schemaReady;

class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function validateExamplePayload(payload) {
  const body = payload && typeof payload === 'object' ? payload : {};
  const sentence = typeof body.sentence === 'string' ? body.sentence.trim() : '';
  const translation = typeof body.translation === 'string' ? body.translation.trim() : '';
  const target = typeof body.target === 'string' ? body.target.trim() : '';

  if (!sentence || !translation) {
    throw new ApiError(422, 'VALIDATION_ERROR', 'Sentence and translation are required.');
  }
  if (sentence.length > 1000 || translation.length > 1000 || target.length > 255) {
    throw new ApiError(422, 'VALIDATION_ERROR', 'Example fields exceed their length limits.');
  }

  return {
    sentence,
    translation,
    target: target || null,
  };
}

function parsePageParams(searchParams) {
  const rawPage = Number.parseInt(searchParams.get('page') || '1', 10);
  const rawPageSize = Number.parseInt(searchParams.get('pageSize') || '50', 10);
  const page = Number.isFinite(rawPage) ? Math.max(rawPage, 1) : 1;
  const pageSize = Number.isFinite(rawPageSize) ? Math.min(Math.max(rawPageSize, 1), 100) : 50;
  const rawHasExample = (searchParams.get('hasExample') || '').toLowerCase();
  const hasExample = rawHasExample === 'true' ? true : rawHasExample === 'false' ? false : null;

  return {
    page,
    pageSize,
    query: (searchParams.get('q') || '').trim(),
    hasExample,
  };
}

function asInt(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.round(parsed) : 0;
}

function parseWordId(value) {
  const id = Number.parseInt(String(value), 10);
  if (!Number.isInteger(id) || id < 1) {
    throw new ApiError(422, 'VALIDATION_ERROR', 'wordId must be a positive integer.');
  }
  return id;
}

async function query(sql, params = []) {
  const result = await pool.query(sql, params);
  return result.rows;
}

async function ensureExampleSchema() {
  if (!schemaReady) {
    schemaReady = (async () => {
      await query(`
        CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY,
          phone_number VARCHAR(20) UNIQUE NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      await query(`
        CREATE TABLE IF NOT EXISTS auth_tokens (
          token VARCHAR(64) PRIMARY KEY,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      await query(`
        CREATE TABLE IF NOT EXISTS vocabulary_lists (
          id SERIAL PRIMARY KEY,
          user_id INTEGER REFERENCES users(id),
          category VARCHAR(50) NOT NULL,
          name VARCHAR(255) NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      await query(`
        CREATE TABLE IF NOT EXISTS vocabulary_words (
          id SERIAL PRIMARY KEY,
          list_id INTEGER REFERENCES vocabulary_lists(id) ON DELETE CASCADE,
          word VARCHAR(255) NOT NULL,
          pronunciation VARCHAR(255),
          meaning TEXT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      await query('ALTER TABLE vocabulary_words ADD COLUMN IF NOT EXISTS example_sentence TEXT');
      await query('ALTER TABLE vocabulary_words ADD COLUMN IF NOT EXISTS example_translation TEXT');
      await query('ALTER TABLE vocabulary_words ADD COLUMN IF NOT EXISTS example_target VARCHAR(255)');
      await query('ALTER TABLE vocabulary_words ADD COLUMN IF NOT EXISTS common_synonyms TEXT');
      await query('ALTER TABLE vocabulary_words ADD COLUMN IF NOT EXISTS related_phrases TEXT');
      await query('ALTER TABLE vocabulary_words ADD COLUMN IF NOT EXISTS nuance TEXT');
    })().catch((error) => {
      schemaReady = undefined;
      throw error;
    });
  }
  await schemaReady;
}

function readJsonBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  if (typeof req.body === 'string' && req.body.trim()) {
    try {
      return JSON.parse(req.body);
    } catch (_) {
      throw new ApiError(422, 'VALIDATION_ERROR', 'Request body must be valid JSON.');
    }
  }
  return {};
}

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

async function requireUserId(req) {
  const header = req.headers?.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!token) throw new ApiError(401, 'UNAUTHENTICATED', 'Authentication is required.');

  const rows = await query('SELECT user_id FROM auth_tokens WHERE token = $1 LIMIT 1', [token]);
  if (rows.length === 0) {
    throw new ApiError(401, 'UNAUTHENTICATED', 'The session has expired.');
  }
  return asInt(rows[0].user_id);
}

async function findOwnedWord(wordId, userId) {
  const rows = await query(
    `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.topic_tag,
            vw.example_sentence, vw.example_translation, vw.example_target,
            vw.common_synonyms, vw.related_phrases, vw.nuance
     FROM vocabulary_words vw
     JOIN vocabulary_lists vl ON vw.list_id = vl.id
     WHERE vw.id = $1 AND vl.user_id = $2
     LIMIT 1`,
    [wordId, userId],
  );
  return rows[0] || null;
}

function mapWord(row) {
  return {
    id: asInt(row.id),
    word: row.word || '',
    pronunciation: row.pronunciation || '',
    meaning: row.meaning || '',
    topicTag: row.topic_tag || '',
    exampleSentence: row.example_sentence || '',
    exampleTranslation: row.example_translation || '',
    exampleTarget: row.example_target || '',
    commonSynonyms: row.common_synonyms || '',
    relatedPhrases: row.related_phrases || '',
    nuance: row.nuance || '',
  };
}

function sendError(res, error) {
  const status = Number.isInteger(error?.status) ? error.status : 500;
  const code = error?.code || 'INTERNAL_ERROR';
  const message = status === 500 ? 'Internal server error.' : error.message;
  if (status === 500) console.error(error);
  res.status(status).json({ error: { code, message } });
}

function sendData(res, data) {
  res.status(200).json({ data });
}

module.exports = {
  ApiError,
  ensureExampleSchema,
  findOwnedWord,
  mapWord,
  parsePageParams,
  parseWordId,
  query,
  readJsonBody,
  requireUserId,
  sendData,
  sendError,
  setCors,
  validateExamplePayload,
};
