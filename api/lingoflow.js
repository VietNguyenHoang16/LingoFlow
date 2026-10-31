const { Pool } = require('pg');
const crypto = require('crypto');
const {
  createAiChain,
  generateExample,
  normalizeExampleStyle,
  templateExample,
  testAiProvider,
} = require('./_lib/xai');

// Tong ngan sach sinh vi du AI cho 1 request bulk. Het budget -> cac tu con
// lai duoc bao loi thay vi luu khong co vi du.
const BULK_AI_BUDGET_MS = 35000;
const BULK_AI_TIMEOUT_MS = 15000;
const BULK_AI_CONCURRENCY = 4;

// Loi tam thoi -> client tu dong thu lai qua request moi.
function isRetryableAiFailure(message) {
  const text = String(message || '');
  if (/API key không hợp lệ|Không tìm thấy model|Máy chủ chưa cấu hình AI/i.test(text)) {
    return false;
  }
  return /quá chậm|quá tải|Không kết nối|Không tạo được|HTTP 5\d\d|không hợp lệ/i.test(text);
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

let schemaReady;

function asInt(value) {
  if (value === null || value === undefined) return 0;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.round(parsed) : 0;
}

function normalizeDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value.toISOString();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

const CATEGORIES = [
  'noun', 'verb', 'adjective', 'adverb', 'preposition',
  'conjunction', 'pronoun', 'interjection', 'phrasal_verb',
  'idiom', 'collocation', 'grammar',
];


// Mot list duy nhat cho moi user (khong ten, khong category). word_type van
// nam tren tung tu nen khong can tach list theo loai tu nhu truoc.
async function ensureCanonicalList(userId) {
  const rows = await query(
    `SELECT id FROM vocabulary_lists
     WHERE user_id = $1 AND COALESCE(name, '') = '' AND COALESCE(category, '') = ''
     ORDER BY id LIMIT 1`,
    [userId],
  );
  if (rows.length > 0) return asInt(rows[0].id);
  const r = await query(
    `INSERT INTO vocabulary_lists (user_id, category, name) VALUES ($1, '', '') RETURNING id`,
    [userId],
  );
  return asInt(r[0].id);
}

/// 'active' = Hoc ngay, 'passive' = Nen biet. Gia tri la -> active.
function normalizeLearningMode(value) {
  return String(value || '').trim().toLowerCase() === 'passive' ? 'passive' : 'active';
}

/// Cum tu di kem: luu dang "comply with · be compliant with" (toi da 3 cum).
function normalizeCollocations(value) {
  const raw = Array.isArray(value) ? value : String(value || '').split(/[·;|,\n]+/);
  const out = [];
  for (const item of raw) {
    const s = String(item || '').trim().slice(0, 80);
    if (!s) continue;
    if (out.some((x) => x.toLowerCase() === s.toLowerCase())) continue;
    out.push(s);
    if (out.length >= 3) break;
  }
  return out.join(' · ');
}

function mapWordRow(row) {
  return {
    id: asInt(row.id),
    word: row.word || '',
    pronunciation: row.pronunciation || '',
    meaning: row.meaning || '',
    full_details: row.full_details || '',
    is_mastered: Boolean(row.is_mastered),
    is_difficult: Boolean(row.is_difficult),
    review_count: asInt(row.review_count),
    correct_streak: asInt(row.correct_streak),
    ease_factor: Number(row.ease_factor ?? 2.5),
    interval_days: asInt(row.interval_days),
    next_review_date: normalizeDate(row.next_review_date),
    last_reviewed_at: normalizeDate(row.last_reviewed_at),
    mastery_level: asInt(row.mastery_level),
    lapse_count: asInt(row.lapse_count),
    word_type: row.word_type || '',
    topic_tag: row.topic_tag || '',
    learning_mode: normalizeLearningMode(row.learning_mode),
    collocations: normalizeCollocations(row.collocations),
    example_sentence: row.example_sentence || '',
    example_translation: row.example_translation || '',
    example_target: row.example_target || '',
    common_synonyms: row.common_synonyms || '',
    created_at: normalizeDate(row.created_at),
    ...(row.list_id !== undefined ? { list_id: asInt(row.list_id) } : {}),
    ...(row.category !== undefined ? { category: row.category || '' } : {}),
  };
}

async function query(sql, params = []) {
  const result = await pool.query(sql, params);
  return result.rows;
}

async function addColumnIfNotExists(table, column, type) {
  const rows = await query(
    "SELECT column_name FROM information_schema.columns WHERE table_name = $1 AND column_name = $2",
    [table, column],
  );
  if (rows.length === 0) {
    await query(`ALTER TABLE ${table} ADD COLUMN ${column} ${type}`);
  }
}

async function dropColumnIfExists(table, column) {
  const rows = await query(
    "SELECT column_name FROM information_schema.columns WHERE table_name = $1 AND column_name = $2",
    [table, column],
  );
  if (rows.length > 0) {
    await query(`ALTER TABLE ${table} DROP COLUMN ${column}`);
  }
}

const MAX_AI_CONFIGS = 3;

function normalizeStoredAiConfigs(raw) {
  if (!Array.isArray(raw)) return [];
  const configs = [];
  for (const item of raw.slice(0, MAX_AI_CONFIGS)) {
    if (!item || typeof item !== 'object') continue;
    const name = String(item.name || '').trim().slice(0, 60);
    const baseUrl = String(item.baseUrl || '').trim().slice(0, 500);
    const apiKey = String(item.apiKey || '').trim().slice(0, 500);
    const model = String(item.model || '').trim().slice(0, 200);
    if (!baseUrl || !apiKey || !model) continue;
    configs.push({ name, baseUrl, apiKey, model });
  }
  return configs;
}

function parseStoredAiConfigs(raw) {
  if (!raw) return [];
  try {
    const value = typeof raw === 'string' ? JSON.parse(raw) : raw;
    return normalizeStoredAiConfigs(value);
  } catch (_) {
    return [];
  }
}

async function getUserAiConfigs(userId) {
  const rows = await query('SELECT ai_configs FROM users WHERE id = $1 LIMIT 1', [userId]);
  return rows.length > 0 ? parseStoredAiConfigs(rows[0].ai_configs) : [];
}

function parseStoredExampleStyle(raw) {
  if (!raw) return normalizeExampleStyle(null);
  try {
    const value = typeof raw === 'string' ? JSON.parse(raw) : raw;
    return normalizeExampleStyle(value);
  } catch (_) {
    return normalizeExampleStyle(null);
  }
}

async function getUserAiExampleStyle(userId) {
  const rows = await query(
    'SELECT ai_example_style FROM users WHERE id = $1 LIMIT 1',
    [userId],
  );
  return rows.length > 0
    ? parseStoredExampleStyle(rows[0].ai_example_style)
    : normalizeExampleStyle(null);
}

// Tang len moi khi them migration trong ensureSchema, neu khong se bi gate bo qua.
const SCHEMA_VERSION = 4;

async function ensureSchema() {
  if (!schemaReady) {
    schemaReady = (async () => {
      // Fast path: schema da dung version -> 2 query thay vi ~20 (cold start).
      await query(`CREATE TABLE IF NOT EXISTS schema_meta (id INTEGER PRIMARY KEY, version INTEGER NOT NULL)`);
      const meta = await query('SELECT version FROM schema_meta WHERE id = 1');
      if (meta.length > 0 && asInt(meta[0].version) >= SCHEMA_VERSION) return;

      // Core tables
      await query(`
        CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY,
          phone_number VARCHAR(20) UNIQUE NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      await addColumnIfNotExists('users', 'ai_configs', 'TEXT');
      await addColumnIfNotExists('users', 'ai_example_style', 'TEXT');

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
          word_count INTEGER DEFAULT 0,
          progress INTEGER DEFAULT 0,
          last_practiced TIMESTAMP,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);

      // Ensure vocabulary_words with all columns
      await query(`
        CREATE TABLE IF NOT EXISTS vocabulary_words (
          id SERIAL PRIMARY KEY,
          list_id INTEGER REFERENCES vocabulary_lists(id) ON DELETE CASCADE,
          word VARCHAR(255) NOT NULL,
          pronunciation VARCHAR(255),
          meaning TEXT NOT NULL,
          full_details TEXT,
          is_mastered BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);

      // Add columns that might be missing (legacy migration)
      await addColumnIfNotExists('vocabulary_words', 'full_details', 'TEXT');
      await addColumnIfNotExists('vocabulary_words', 'is_difficult', 'BOOLEAN DEFAULT FALSE');
      await addColumnIfNotExists('vocabulary_words', 'review_count', 'INTEGER DEFAULT 0');
      await addColumnIfNotExists('vocabulary_words', 'correct_streak', 'INTEGER DEFAULT 0');
      await addColumnIfNotExists('vocabulary_words', 'ease_factor', 'REAL DEFAULT 2.5');
      await addColumnIfNotExists('vocabulary_words', 'interval_days', 'INTEGER DEFAULT 0');
      await addColumnIfNotExists('vocabulary_words', 'next_review_date', 'TIMESTAMP');
      await addColumnIfNotExists('vocabulary_words', 'last_reviewed_at', 'TIMESTAMP');
      await addColumnIfNotExists('vocabulary_words', 'mastery_level', 'INTEGER DEFAULT 0');
      await addColumnIfNotExists('vocabulary_words', 'lapse_count', 'INTEGER DEFAULT 0');
      await addColumnIfNotExists('vocabulary_words', 'word_type', "VARCHAR(255) DEFAULT ''");
      await addColumnIfNotExists('vocabulary_words', 'topic_tag', "VARCHAR(100) DEFAULT ''");
      await addColumnIfNotExists('vocabulary_words', 'example_sentence', 'TEXT');
      await addColumnIfNotExists('vocabulary_words', 'example_translation', 'TEXT');
      await addColumnIfNotExists('vocabulary_words', 'example_target', 'VARCHAR(255)');
      await addColumnIfNotExists('vocabulary_words', 'common_synonyms', 'TEXT');
      await addColumnIfNotExists('vocabulary_words', 'learning_mode', "VARCHAR(10) DEFAULT 'active'");
      await addColumnIfNotExists('vocabulary_words', 'collocations', 'TEXT');
      // Gọn còn 3 từ common: xóa hẳn related/nuance + data (user xác nhận).
      await dropColumnIfExists('vocabulary_words', 'related_phrases');
      await dropColumnIfExists('vocabulary_words', 'nuance');

      // Migrate old is_mastered -> mastery_level
      await query(`
        UPDATE vocabulary_words
        SET mastery_level = 3, interval_days = 30, correct_streak = 5, ease_factor = 2.5
        WHERE is_mastered = TRUE AND (mastery_level IS NULL OR mastery_level = 0)
      `);

      // Strip duplicate wrapping slashes from IPA (dictionaryapi.dev returns "/ipa/")
      await query(`
        UPDATE vocabulary_words
        SET pronunciation = btrim(pronunciation, '/')
        WHERE pronunciation LIKE '/%'
      `);

      await addColumnIfNotExists('vocabulary_lists', 'word_count', 'INTEGER DEFAULT 0');
      await addColumnIfNotExists('vocabulary_lists', 'progress', 'INTEGER DEFAULT 0');
      await addColumnIfNotExists('vocabulary_lists', 'last_practiced', 'TIMESTAMP');

      // Index
      await query(`
        CREATE INDEX IF NOT EXISTS idx_vocabulary_lists_user_category
        ON vocabulary_lists(user_id, category)
      `);

      await query(
        'INSERT INTO schema_meta (id, version) VALUES (1, $1) ON CONFLICT (id) DO UPDATE SET version = $1',
        [SCHEMA_VERSION],
      );
    })().catch((error) => {
      schemaReady = undefined;
      throw error;
    });
  }

  await schemaReady;
}

function readPayload(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  if (typeof req.body === 'string' && req.body.trim()) return JSON.parse(req.body);
  return {};
}

async function handleAction(action, data) {
  await ensureSchema();

  switch (action) {
    case 'init':
      return null;

    // ---- Auth ----
    case 'registerUser': {
      try {
        await query('INSERT INTO users (phone_number) VALUES ($1)', [data.phoneNumber]);
        return true;
      } catch (error) {
        if (error.code === '23505') return false;
        throw error;
      }
    }

    case 'getUserId': {
      const rows = await query('SELECT id FROM users WHERE phone_number = $1', [data.phoneNumber]);
      return rows.length === 0 ? null : asInt(rows[0].id);
    }

    case 'loginUser': {
      const rows = await query('SELECT id FROM users WHERE phone_number = $1', [data.phoneNumber]);
      if (rows.length === 0) return null;
      const userId = asInt(rows[0].id);
      const token = crypto.randomBytes(32).toString('hex');
      await query('INSERT INTO auth_tokens (token, user_id) VALUES ($1, $2)', [token, userId]);
      return { userId, token };
    }

    case 'userExists': {
      const rows = await query('SELECT 1 FROM users WHERE id = $1 LIMIT 1', [data.userId]);
      return rows.length > 0;
    }

    // ---- Lists ----
    case 'createList': {
      const rows = await query(
        'INSERT INTO vocabulary_lists (user_id, category, name) VALUES ($1, $2, $3) RETURNING id',
        [data.userId, data.category, data.name],
      );
      return asInt(rows[0].id);
    }

    // Van tra ve dung 1 dong (client cu khong phai sua), nhung so lieu duoc
    // dem tren toan bo tu cua user theo word_type - khong con list rieng.
    case 'getListsByCategory': {
      const listId = await ensureCanonicalList(data.userId);
      const rows = await query(
        `SELECT COUNT(*) AS cat_word_count,
                COUNT(*) FILTER (WHERE vw.next_review_date IS NULL
                                   OR vw.next_review_date <= $2) AS due_count,
                ROUND(CASE WHEN COUNT(*) = 0 THEN 0
                      ELSE COUNT(*) FILTER (WHERE COALESCE(vw.mastery_level, 0) >= 3) * 100.0 / COUNT(*)
                 END) AS progress
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1
           AND $3 = ANY(string_to_array(REPLACE(COALESCE(vw.word_type, ''), ' ', ''), ','))`,
        [data.userId, new Date(), data.category],
      );
      return [{
        id: listId,
        name: '',
        wordCount: asInt(rows[0].cat_word_count),
        progress: asInt(rows[0].progress),
        lastPracticed: null,
        dueCount: asInt(rows[0].due_count),
      }];
    }

    case 'getAllLists': {
      const listId = await ensureCanonicalList(data.userId);
      const rows = await query(
        `SELECT COUNT(*) AS word_count,
                COUNT(*) FILTER (WHERE vw.next_review_date IS NULL
                                   OR vw.next_review_date <= $2) AS due_count,
                ROUND(CASE WHEN COUNT(*) = 0 THEN 0
                      ELSE COUNT(*) FILTER (WHERE COALESCE(vw.mastery_level, 0) >= 3) * 100.0 / COUNT(*)
                 END) AS progress
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1
           AND COALESCE(vw.word_type, '') NOT LIKE '%grammar%'`,
        [data.userId, new Date()],
      );
      return [{
        id: listId,
        name: '',
        category: '',
        wordCount: asInt(rows[0].word_count),
        progress: asInt(rows[0].progress),
        lastPracticed: null,
        dueCount: asInt(rows[0].due_count),
      }];
    }

    case 'updateListProgress':
      // listId client gui len co the la list cu -> cap nhat theo user.
      await query(
        'UPDATE vocabulary_lists SET progress = $1, word_count = $2, last_practiced = CURRENT_TIMESTAMP WHERE user_id = $3',
        [data.progress, data.wordCount, data.userId],
      );
      return null;

    // Chi con 1 list/user: khong cho xoa de tranh mat toan bo tu.
    case 'deleteList':
      throw new Error('Chi co mot danh sach duy nhat nen khong the xoa.');

    // ---- Categories (aggregated stats) ----
    case 'getCategoryStats': {
      const now = new Date();
      const results = await Promise.all(CATEGORIES.map(async (cat) => {
        const rows = await query(
          `SELECT COUNT(DISTINCT vw.id) AS word_count,
                  COUNT(DISTINCT vl.id) AS list_count,
                  SUM(CASE WHEN vw.next_review_date IS NULL OR vw.next_review_date <= $2 THEN 1 ELSE 0 END) AS due_count,
                  ROUND(CASE WHEN COUNT(vw.id) = 0 THEN 0 ELSE SUM(CASE WHEN COALESCE(vw.mastery_level, 0) >= 3 THEN 1 ELSE 0 END) * 100.0 / COUNT(vw.id) END) AS progress
           FROM vocabulary_words vw
           JOIN vocabulary_lists vl ON vw.list_id = vl.id
           WHERE vl.user_id = $1
                 AND $3 = ANY(string_to_array(REPLACE(COALESCE(vw.word_type, ''), ' ', ''), ','))`,
          [data.userId, now, cat],
        );
        return { category: cat, row: rows[0] };
      }));
      const stats = {};
      for (const { category, row } of results) {
        stats[category] = {
          listCount: asInt(row.list_count),
          wordCount: asInt(row.word_count),
          dueCount: asInt(row.due_count),
          progress: asInt(row.progress),
        };
      }
      return stats;
    }

    // Gop getCategoryStats + getReviewStats: 17 query -> 3 query
    case 'getDashboardStats': {
      const now = new Date();
      const catRows = await query(
        // Tach word_type dang ghep ('noun,adjective') thanh tung category rieng
        // de tu da loai duoc dem dung cho moi the loai thay vi bi bo qua.
        `SELECT t.cat,
                COUNT(DISTINCT vl.id) AS list_count,
                COUNT(DISTINCT vw.id) AS word_count,
                COUNT(DISTINCT vw.id) FILTER (WHERE vw.next_review_date IS NULL OR vw.next_review_date <= $2) AS due_count,
                ROUND(CASE WHEN COUNT(DISTINCT vw.id) = 0 THEN 0
                           ELSE COUNT(DISTINCT vw.id) FILTER (WHERE COALESCE(vw.mastery_level, 0) >= 3) * 100.0 / COUNT(DISTINCT vw.id) END) AS progress
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         CROSS JOIN LATERAL unnest(string_to_array(REPLACE(COALESCE(vw.word_type, ''), ' ', ''), ',')) AS t(cat)
         WHERE vl.user_id = $1 AND t.cat = ANY($3::text[])
         GROUP BY t.cat`,
        [data.userId, now, CATEGORIES],
      );
      const categoryStats = {};
      for (const cat of CATEGORIES) {
        categoryStats[cat] = { listCount: 0, wordCount: 0, dueCount: 0, progress: 0 };
      }
      for (const row of catRows) {
        const cat = row.cat || '';
        if (!categoryStats[cat]) continue;
        categoryStats[cat] = {
          listCount: asInt(row.list_count),
          wordCount: asInt(row.word_count),
          dueCount: asInt(row.due_count),
          progress: asInt(row.progress),
        };
      }

      const reviewRows = await query(
        // Luu y: khong duoc de NOT LIKE '%grammar%' o WHERE vi se loai bo cac dong
        // grammar truoc khi FILTER (LIKE '%grammar%') chay -> grammar_due luon = 0.
        // Dieu kien NOT LIKE phai nam trong tung FILTER de dem tu vung, rieng grammar_due dem rieng.
        `SELECT COUNT(*) FILTER (WHERE (vw.next_review_date IS NULL OR vw.next_review_date <= $2)
                                      AND COALESCE(vw.word_type, '') NOT LIKE '%grammar%') AS due_today,
                COUNT(*) FILTER (WHERE vw.mastery_level = 3
                                      AND COALESCE(vw.word_type, '') NOT LIKE '%grammar%') AS total_mastered,
                COUNT(*) FILTER (WHERE COALESCE(vw.word_type, '') NOT LIKE '%grammar%') AS total_words,
                COUNT(*) FILTER (WHERE vw.last_reviewed_at IS NOT NULL AND vw.last_reviewed_at >= CURRENT_DATE
                                      AND COALESCE(vw.word_type, '') NOT LIKE '%grammar%') AS reviewed_today,
                COUNT(*) FILTER (WHERE (vw.next_review_date IS NULL OR vw.next_review_date <= $2)
                                      AND COALESCE(vw.word_type, '') LIKE '%grammar%') AS grammar_due
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1`,
        [data.userId, now],
      );
      const breakdownRows = await query(
        `SELECT vw.mastery_level, COUNT(*) AS count
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1         AND COALESCE(vw.word_type, '') NOT LIKE '%grammar%'
         GROUP BY vw.mastery_level ORDER BY vw.mastery_level`,
        [data.userId],
      );
      const breakdown = {};
      for (const row of breakdownRows) breakdown[asInt(row.mastery_level)] = asInt(row.count);
      return {
        categoryStats,
        reviewStats: {
          dueToday: asInt(reviewRows[0].due_today),
          totalMastered: asInt(reviewRows[0].total_mastered),
          totalWords: asInt(reviewRows[0].total_words),
          reviewedToday: asInt(reviewRows[0].reviewed_today),
          grammarDue: asInt(reviewRows[0].grammar_due),
          breakdown,
        },
      };
    }

    // ---- Words ----
    case 'addVocabularyWord': {
      // Mot list duy nhat cho moi user: bo hoan toan listId/category tu client.
      const listId = await ensureCanonicalList(data.userId);
      // Chan trung tren toan bo tu cua user (truoc day chi chan trong 1 list).
      const userCheck = await query(
        `SELECT 1 FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND LOWER(vw.word) = LOWER($2) LIMIT 1`,
        [data.userId, data.word],
      );
      if (userCheck.length > 0) {
        throw new Error('Tu nay da ton tai');
      }
      const wordType = (data.wordType || '').trim() || data.category || '';
      const topicTag = String(data.topicTag || '').trim().slice(0, 100);
      const learningMode = normalizeLearningMode(data.learningMode);
      const collocations = normalizeCollocations(data.collocations);
      const aiConfigs = await getUserAiConfigs(data.userId);
      const style = await getUserAiExampleStyle(data.userId);
      // Sinh vi du truoc khi insert: AI loi -> khong luu tu, bao loi ro rang.
      const example = await generateExample(
        { word: data.word, meaning: data.meaning || '', wordType, topicTag, style },
        { timeoutMs: 10000, aiConfigs },
      );
      const rows = await query(
        `INSERT INTO vocabulary_words (list_id, word, pronunciation, meaning, full_details, word_type, topic_tag, common_synonyms, example_sentence, example_translation, example_target, learning_mode, collocations)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
         RETURNING id`,
        [listId, data.word, data.pronunciation || '', data.meaning || '', data.fullDetails || '', wordType, topicTag, (data.commonSynonyms || '').trim(), example.sentence, example.translation, example.target, learningMode, collocations],
      );
      return asInt(rows[0].id);
    }

    case 'generateWordExample': {
      const wordId = asInt(data.wordId);
      if (!wordId) throw new Error('Thieu wordId');
      const rows = await query(
        `SELECT vw.word, vw.meaning, vw.word_type, vw.topic_tag, vw.learning_mode, vw.collocations
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vw.id = $1 AND vl.user_id = $2
         LIMIT 1`,
        [wordId, data.userId],
      );
      if (rows.length === 0) throw new Error('Khong tim thay tu nay');
      const row = rows[0];
      return generateExample(
        {
          word: row.word || '',
          meaning: row.meaning || '',
          wordType: row.word_type || '',
          topicTag: row.topic_tag || '',
          style: await getUserAiExampleStyle(data.userId),
        },
        { timeoutMs: 10000, aiConfigs: await getUserAiConfigs(data.userId) },
      );
    }

    case 'updateWordExample': {
      const wordId = asInt(data.wordId);
      if (!wordId) throw new Error('Thieu wordId');
      const sentence = String(data.sentence || '').trim();
      const translation = String(data.translation || '').trim();
      const target = String(data.target || '').trim();
      if (sentence.length > 1000 || translation.length > 1000 || target.length > 255) {
        throw new Error('Vi du qua dai');
      }
      if (sentence && !translation) throw new Error('Thieu ban dich');
      const rows = await query(
        `UPDATE vocabulary_words
         SET example_sentence = $1, example_translation = $2, example_target = $3
         WHERE id = $4
           AND list_id IN (SELECT id FROM vocabulary_lists WHERE user_id = $5)
         RETURNING id`,
        [sentence || null, translation || null, target || null, wordId, data.userId],
      );
      if (rows.length === 0) throw new Error('Khong tim thay tu nay');
      return { sentence, translation, target };
    }

    case 'testAiProvider': {
      return testAiProvider({
        name: data.name,
        baseUrl: data.baseUrl,
        apiKey: data.apiKey,
        model: data.model,
      });
    }

    case 'getAiConfigs': {
      return getUserAiConfigs(data.userId);
    }

    case 'saveAiConfigs': {
      const configs = normalizeStoredAiConfigs(data.configs);
      await query('UPDATE users SET ai_configs = $1 WHERE id = $2', [
        JSON.stringify(configs),
        data.userId,
      ]);
      return configs;
    }

    // Cach AI chon nghia va dat cau vi du (theo tai khoan).
    case 'getAiExampleStyle': {
      return getUserAiExampleStyle(data.userId);
    }

    case 'saveAiExampleStyle': {
      const style = normalizeExampleStyle(data.style);
      await query('UPDATE users SET ai_example_style = $1 WHERE id = $2', [
        JSON.stringify(style),
        data.userId,
      ]);
      return style;
    }

    case 'filterExistingWords': {
      const words = Array.isArray(data.words) ? data.words.map((w) => String(w || '').toLowerCase()).filter(Boolean) : [];
      if (words.length === 0) return [];
      const rows = await query(
        `SELECT DISTINCT LOWER(vw.word) AS w
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND LOWER(vw.word) = ANY($2)`,
        [data.userId, words],
      );
      return rows.map((row) => row.w);
    }

    // Nhu filterExistingWords nhung tra kem nghia + loai tu da luu, de bang
    // import hien duoc nghia cua tu bi trung ngay tai dong do.
    case 'filterExistingWordsDetailed': {
      const words = Array.isArray(data.words)
        ? data.words.map((w) => String(w || '').toLowerCase()).filter(Boolean)
        : [];
      if (words.length === 0) return [];
      const rows = await query(
        `SELECT DISTINCT ON (LOWER(vw.word))
                LOWER(vw.word) AS w, vw.word, vw.meaning, vw.word_type
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND LOWER(vw.word) = ANY($2)
         ORDER BY LOWER(vw.word), vw.id`,
        [data.userId, words],
      );
      return rows.map((row) => ({
        word: row.word || row.w,
        meaning: row.meaning || '',
        wordType: row.word_type || '',
      }));
    }

    // Nghia tieng Viet + loai tu cho danh sach tu nguoi dung dan vao (import).
    // Moi tu loi duoc tra rieng trong `error` de client bo qua va bao lai.
    case 'enrichWords': {
      const rawWords = Array.isArray(data.words) ? data.words : [];
      const words = [];
      const seen = new Set();
      for (const raw of rawWords) {
        const word = String(raw || '').trim().slice(0, 100);
        if (!word) continue;
        const key = word.toLowerCase();
        if (seen.has(key)) continue;
        seen.add(key);
        words.push(word);
        if (words.length >= 60) break;
      }
      if (words.length === 0) return [];

      const chain = createAiChain(await getUserAiConfigs(data.userId));
      const style = await getUserAiExampleStyle(data.userId);
      const deadline = Date.now() + BULK_AI_BUDGET_MS;
      const results = [];
      let cursor = 0;
      async function worker() {
        while (true) {
          const index = cursor;
          cursor += 1;
          if (index >= words.length) return;
          const word = words[index];
          try {
            const info = await chain.generateWordInfo(
              { word },
              { timeoutMs: BULK_AI_TIMEOUT_MS, deadline, style },
            );
            results[index] = {
              word,
              meaning: info.meaning,
              wordType: info.wordType,
              learningMode: info.learningMode,
              collocations: info.collocations,
            };
          } catch (error) {
            results[index] = { word, meaning: '', wordType: '', error: error.message };
          }
        }
      }
      await Promise.all(
        Array.from({ length: Math.min(BULK_AI_CONCURRENCY, words.length) }, worker),
      );
      return words.map((word, index) => results[index] || {
        word,
        meaning: '',
        wordType: '',
        error: 'Hết thời gian lấy nghĩa.',
      });
    }

    case 'bulkAddWords': {
      const items = Array.isArray(data.words) ? data.words : [];
      if (items.length === 0) return { insertedCount: 0, failed: [] };

      // Mot list duy nhat cho moi user: bo listId/category tu client.
      const listId = await ensureCanonicalList(data.userId);

      // Loai tu trung (theo user, khong phai chi trong list nay).
      const lowerWords = [...new Set(items.map((it) => String(it.word || '').toLowerCase()).filter(Boolean))];
      const existingRows = lowerWords.length > 0 ? await query(
        `SELECT DISTINCT LOWER(vw.word) AS w
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND LOWER(vw.word) = ANY($2)`,
        [data.userId, lowerWords],
      ) : [];
      const existing = new Set(existingRows.map((row) => row.w));

      const candidates = [];
      const seenInPayload = new Set();
      for (const it of items) {
        const word = String(it.word || '').trim();
        if (!word) continue;
        const lower = word.toLowerCase();
        if (existing.has(lower) || seenInPayload.has(lower)) continue;
        seenInPayload.add(lower);
        candidates.push({
          word,
          pronunciation: it.pronunciation || '',
          meaning: it.meaning || '',
          fullDetails: it.fullDetails || '',
          wordType: (it.wordType || '').trim(),
          topicTag: String(it.topicTag || '').trim().slice(0, 100),
          commonSynonyms: (it.commonSynonyms || '').trim(),
          learningMode: normalizeLearningMode(it.learningMode),
          collocations: normalizeCollocations(it.collocations),
        });
      }
      if (candidates.length === 0) return { insertedCount: 0, failed: [] };

      // Sinh vi du truoc khi insert, gioi han concurrency + tong thoi gian.
      const deadline = Date.now() + BULK_AI_BUDGET_MS;
      const usedSentences = new Set();
      const aiChain = createAiChain(await getUserAiConfigs(data.userId));
      const style = await getUserAiExampleStyle(data.userId);
      const prepared = [];
      const failed = [];
      let cursor = 0;
      async function worker() {
        while (true) {
          const index = cursor;
          cursor += 1;
          if (index >= candidates.length) return;
          const info = candidates[index];
          if (Date.now() > deadline) {
            failed.push({
              word: info.word,
              message: 'Hết thời gian tạo ví dụ.',
              retryable: true,
            });
            continue;
          }
          try {
            const example = await aiChain.generate({ ...info, style }, {
              timeoutMs: BULK_AI_TIMEOUT_MS,
              used: usedSentences,
              deadline,
            });
            prepared.push({ ...info, example });
          } catch (error) {
            failed.push({
              word: info.word,
              message: error.message,
              retryable: isRetryableAiFailure(error.message),
            });
          }
        }
      }
      await Promise.all(
        Array.from({ length: Math.min(BULK_AI_CONCURRENCY, candidates.length) }, worker),
      );

      let insertedCount = 0;
      const CHUNK = 100;
      for (let i = 0; i < prepared.length; i += CHUNK) {
        const chunk = prepared.slice(i, i + CHUNK);
        const params = [listId];
        const values = chunk.map((it) => {
          const base = params.length;
          params.push(
            it.word, it.pronunciation, it.meaning, it.fullDetails, it.wordType,
            it.topicTag, it.commonSynonyms,
            it.example.sentence, it.example.translation, it.example.target,
            it.learningMode, it.collocations,
          );
          return `($1, $${base + 1}, $${base + 2}, $${base + 3}, $${base + 4}, $${base + 5}, $${base + 6}, $${base + 7}, $${base + 8}, $${base + 9}, $${base + 10}, $${base + 11}, $${base + 12})`;
        });
        try {
          const inserted = await query(
            `INSERT INTO vocabulary_words (list_id, word, pronunciation, meaning, full_details, word_type, topic_tag, common_synonyms, example_sentence, example_translation, example_target, learning_mode, collocations)
             VALUES ${values.join(', ')}
             RETURNING id`,
            params,
          );
          insertedCount += inserted.length;
        } catch (_) {
          // Loi ca lo - thu tung dong de giu toi da du lieu.
          for (const it of chunk) {
            try {
              await query(
                `INSERT INTO vocabulary_words (list_id, word, pronunciation, meaning, full_details, word_type, topic_tag, common_synonyms, example_sentence, example_translation, example_target, learning_mode, collocations)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
                [listId, it.word, it.pronunciation, it.meaning, it.fullDetails, it.wordType, it.topicTag, it.commonSynonyms, it.example.sentence, it.example.translation, it.example.target, it.learningMode, it.collocations],
              );
              insertedCount += 1;
            } catch (rowError) {
              failed.push({
                word: it.word,
                message: `Lỗi lưu dữ liệu: ${rowError.message}`,
                retryable: false,
              });
            }
          }
        }
      }
      return { insertedCount, failed };
    }

    case 'bulkDeleteWords': {
      const ids = Array.isArray(data.wordIds) ? data.wordIds.map((id) => asInt(id)).filter((id) => id > 0) : [];
      if (ids.length === 0) return { deletedCount: 0 };
      const result = await pool.query(
        'DELETE FROM vocabulary_words WHERE id = ANY($1::int[]) AND list_id IN (SELECT id FROM vocabulary_lists WHERE user_id = $2)',
        [ids, data.userId],
      );
      return { deletedCount: result.rowCount };
    }

    case 'getVocabularyWords': {
      const rows = await query(
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.example_sentence, vw.example_translation, vw.example_target, vw.common_synonyms, vw.is_mastered, vw.is_difficult,
                vw.review_count, vw.correct_streak, vw.ease_factor, vw.interval_days,
                vw.next_review_date, vw.last_reviewed_at, vw.mastery_level, vw.lapse_count, vw.word_type, vw.topic_tag, vw.learning_mode, vw.collocations
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1
         ORDER BY vw.created_at DESC, vw.id DESC`,
        [data.userId],
      );
      return rows.map(mapWordRow);
    }

    case 'getWordsByCategory': {
      const rows = await query(
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.example_sentence, vw.example_translation, vw.example_target, vw.common_synonyms, vw.is_mastered, vw.is_difficult,
                vw.review_count, vw.correct_streak, vw.ease_factor, vw.interval_days,
                vw.next_review_date, vw.last_reviewed_at, vw.mastery_level, vw.lapse_count, vw.word_type, vw.topic_tag, vw.learning_mode, vw.collocations,
                vl.id AS list_id
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1
               AND $2 = ANY(string_to_array(REPLACE(COALESCE(vw.word_type, ''), ' ', ''), ','))
         ORDER BY vw.created_at DESC`,
        [data.userId, data.category],
      );
      return rows.map(mapWordRow);
    }

    case 'getRecentWords': {
      const limit = Math.min(Math.max(asInt(data.limit) || 20, 1), 100);
      const rows = await query(
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.example_sentence, vw.example_translation, vw.example_target, vw.common_synonyms, vw.is_mastered, vw.is_difficult,
                vw.review_count, vw.correct_streak, vw.ease_factor, vw.interval_days,
                vw.next_review_date, vw.last_reviewed_at, vw.mastery_level, vw.lapse_count, vw.word_type, vw.topic_tag, vw.learning_mode, vw.collocations,
                vw.created_at,
                vl.id AS list_id
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1
         ORDER BY vw.created_at DESC
         LIMIT $2`,
        [data.userId, limit],
      );
      return rows.map(mapWordRow);
    }

    case 'getWordsMissingPronunciation': {
      const rows = await query(
        `SELECT vw.id, vw.word
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND (vw.pronunciation IS NULL OR vw.pronunciation = '')
         ORDER BY vw.created_at ASC`,
        [data.userId],
      );
      return rows;
    }

    case 'getUntaggedWords': {
      const rows = await query(
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.example_sentence, vw.example_translation, vw.example_target, vw.common_synonyms, vw.topic_tag
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND (vw.word_type IS NULL OR vw.word_type = '')
         ORDER BY vw.created_at ASC`,
        [data.userId],
      );
      return rows;
    }

    case 'updateWordPronunciation':
      await query(
        'UPDATE vocabulary_words SET pronunciation = $1 WHERE id = $2 AND list_id IN (SELECT id FROM vocabulary_lists WHERE user_id = $3)',
        [data.pronunciation || '', data.wordId, data.userId]);
      return null;

    case 'updateWordDifficult':
      await query(
        'UPDATE vocabulary_words SET is_difficult = $1 WHERE id = $2 AND list_id IN (SELECT id FROM vocabulary_lists WHERE user_id = $3)',
        [data.isDifficult, data.wordId, data.userId]);
      return null;

    case 'updateWordMastered':
      await query(
        'UPDATE vocabulary_words SET is_mastered = $1 WHERE id = $2 AND list_id IN (SELECT id FROM vocabulary_lists WHERE user_id = $3)',
        [data.isMastered, data.wordId, data.userId]);
      return null;

    case 'deleteVocabularyWord':
      await query(
        'DELETE FROM vocabulary_words WHERE id = $1 AND list_id IN (SELECT id FROM vocabulary_lists WHERE user_id = $2)',
        [data.wordId, data.userId]);
      return null;

    case 'updateVocabularyWordDetails': {
      const wordId = asInt(data.wordId);
      const current = await query(
        `SELECT vw.word
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vw.id = $1 AND vl.user_id = $2
         LIMIT 1`,
        [wordId, data.userId],
      );
      if (current.length === 0) throw new Error('Khong tim thay tu nay');

      const meaning = (data.meaning || '').trim();
      const pronunciation = (data.pronunciation || '').trim();
      const fullDetails = (data.fullDetails || '').trim();
      const wordType = (data.wordType || '').trim();
      const topicTag = String(data.topicTag || '').trim().slice(0, 100);
      const commonSynonyms = (data.commonSynonyms || '').trim();
      const refreshExample = data.refreshExample === true;
      const example = refreshExample
        ? await generateExample(
            {
              word: current[0].word,
              meaning,
              wordType,
              topicTag,
              style: await getUserAiExampleStyle(data.userId),
            },
            { timeoutMs: 10000, aiConfigs: await getUserAiConfigs(data.userId) },
          )
        : null;
      const values = [meaning, pronunciation, fullDetails, wordType, topicTag, commonSynonyms];
      let sql = `UPDATE vocabulary_words SET meaning = $1, pronunciation = $2, full_details = $3, word_type = $4, topic_tag = $5,
         common_synonyms = $6`;
      if (example) {
        values.push(example.sentence, example.translation, example.target);
        sql += ', example_sentence = $7, example_translation = $8, example_target = $9';
      }
      const idParam = values.length + 1;
      const userParam = values.length + 2;
      sql += ` WHERE id = $${idParam} AND list_id IN (SELECT id FROM vocabulary_lists WHERE user_id = $${userParam})`;
      values.push(wordId, data.userId);
      await query(sql, values);
      return example;
    }

    case 'updateVocabularyWord': {
      const word = (data.word || '').trim();
      const pronunciation = (data.pronunciation || '').trim();
      const meaning = (data.meaning || '').trim();
      const fullDetails = (data.fullDetails || '').trim();
      const wordType = (data.wordType || '').trim();
      const topicTag = String(data.topicTag || '').trim().slice(0, 100);
      const commonSynonyms = (data.commonSynonyms || '').trim();
      // Cho phep doi loai + cum tu khi sua tu; khong gui -> giu nguyen.
      const learningMode = data.learningMode === undefined
        ? null
        : normalizeLearningMode(data.learningMode);
      const collocations = data.collocations === undefined
        ? null
        : normalizeCollocations(data.collocations);
      const example = await generateExample(
        { word, meaning, wordType, topicTag, style: await getUserAiExampleStyle(data.userId) },
        { timeoutMs: 10000, aiConfigs: await getUserAiConfigs(data.userId) },
      );

      const rows = await query(
        `UPDATE vocabulary_words SET word = $1, pronunciation = $2, meaning = $3, full_details = $4, word_type = $5, topic_tag = $6,
         common_synonyms = $7, example_sentence = $8, example_translation = $9, example_target = $10,
         learning_mode = COALESCE($13, learning_mode), collocations = COALESCE($14, collocations)
         WHERE id = $11 AND list_id IN (SELECT id FROM vocabulary_lists WHERE user_id = $12)
         RETURNING id`,
        [word, pronunciation, meaning, fullDetails, wordType, topicTag, commonSynonyms,
          example.sentence, example.translation, example.target, data.wordId, data.userId,
          learningMode, collocations],
      );
      if (rows.length === 0) throw new Error('Khong tim thay tu nay');
      return example;
    }

    case 'updateWordReview': {
      const masteryLevel = asInt(data.masteryLevel);
      await query(
        `UPDATE vocabulary_words
         SET review_count = $1, correct_streak = $2, ease_factor = $3, interval_days = $4,
             next_review_date = $5, last_reviewed_at = CURRENT_TIMESTAMP, mastery_level = $6,
             is_mastered = $7, lapse_count = $8
         WHERE id = $9 AND list_id IN (SELECT id FROM vocabulary_lists WHERE user_id = $10)`,
        [data.reviewCount, data.correctStreak, data.easeFactor, data.intervalDays, new Date(data.nextReviewDate), masteryLevel, masteryLevel >= 3, asInt(data.lapseCount), data.wordId, data.userId],
      );
      return null;
    }

    // ---- Review ----
    case 'getWordsDueForReview': {
      const rows = await query(
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.example_sentence, vw.example_translation, vw.example_target, vw.common_synonyms, vw.is_mastered, vw.is_difficult,
                vw.review_count, vw.correct_streak, vw.ease_factor, vw.interval_days,
                vw.next_review_date, vw.last_reviewed_at, vw.mastery_level, vw.lapse_count, vw.word_type, vw.topic_tag, vw.learning_mode, vw.collocations
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND (vw.next_review_date IS NULL OR vw.next_review_date <= $2)
               AND COALESCE(vw.word_type, '') NOT LIKE '%grammar%'
         ORDER BY COALESCE(vw.next_review_date, CURRENT_TIMESTAMP) ASC`,
        [data.userId, new Date()],
      );
      return rows.map(mapWordRow);
    }

    case 'getAllWordsDueForReview': {
      const rows = await query(
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.example_sentence, vw.example_translation, vw.example_target, vw.common_synonyms, vw.is_mastered, vw.is_difficult,
                vw.review_count, vw.correct_streak, vw.ease_factor, vw.interval_days,
                vw.next_review_date, vw.last_reviewed_at, vw.mastery_level, vw.lapse_count, vw.word_type, vw.topic_tag, vw.learning_mode, vw.collocations,
                vl.id AS list_id
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND (vw.next_review_date IS NULL OR vw.next_review_date <= $2)
               AND COALESCE(vw.word_type, '') NOT LIKE '%grammar%'
         ORDER BY COALESCE(vw.next_review_date, CURRENT_TIMESTAMP) ASC`,
        [data.userId, new Date()],
      );
      return rows.map(mapWordRow);
    }

    case 'getWordsDueForReviewByCategory': {
      const rows = await query(
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.example_sentence, vw.example_translation, vw.example_target, vw.common_synonyms, vw.is_mastered, vw.is_difficult,
                vw.review_count, vw.correct_streak, vw.ease_factor, vw.interval_days,
                vw.next_review_date, vw.last_reviewed_at, vw.mastery_level, vw.lapse_count, vw.word_type, vw.topic_tag, vw.learning_mode, vw.collocations,
                vl.id AS list_id
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1
               AND $2 = ANY(string_to_array(REPLACE(COALESCE(vw.word_type, ''), ' ', ''), ','))
               AND (vw.next_review_date IS NULL OR vw.next_review_date <= $3)
         ORDER BY COALESCE(vw.next_review_date, CURRENT_TIMESTAMP) ASC`,
        [data.userId, data.category, new Date()],
      );
      return rows.map(mapWordRow);
    }

    case 'getWordsDueForReviewGrammar': {
      // ON tap cau truc: lay cac tu co 'grammar' trong word_type (bao gom tu lai loai
      // nhu 'noun,grammar' - nhung tu nay da bi loai khoi on tap tu vung).
      const rows = await query(
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.example_sentence, vw.example_translation, vw.example_target, vw.common_synonyms, vw.is_mastered, vw.is_difficult,
                vw.review_count, vw.correct_streak, vw.ease_factor, vw.interval_days,
                vw.next_review_date, vw.last_reviewed_at, vw.mastery_level, vw.lapse_count, vw.word_type, vw.topic_tag, vw.learning_mode, vw.collocations,
                vl.id AS list_id
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND (vw.next_review_date IS NULL OR vw.next_review_date <= $2)
               AND COALESCE(vw.word_type, '') LIKE '%grammar%'
         ORDER BY COALESCE(vw.next_review_date, CURRENT_TIMESTAMP) ASC`,
        [data.userId, new Date()],
      );
      return rows.map(mapWordRow);
    }

    case 'getReviewStats': {
      const due = await query(
        `SELECT COUNT(*) AS count FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND (vw.next_review_date IS NULL OR vw.next_review_date <= $2)
               AND COALESCE(vw.word_type, '') NOT LIKE '%grammar%'`,
        [data.userId, new Date()],
      );
      const mastered = await query(
        `SELECT COUNT(*) AS count FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND vw.mastery_level = 3
               AND COALESCE(vw.word_type, '') NOT LIKE '%grammar%'`,
        [data.userId],
      );
      const total = await query(
        `SELECT COUNT(*) AS count FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1
               AND COALESCE(vw.word_type, '') NOT LIKE '%grammar%'`,
        [data.userId],
      );
      const reviewedToday = await query(
        `SELECT COUNT(*) AS count FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND vw.last_reviewed_at IS NOT NULL AND vw.last_reviewed_at >= CURRENT_DATE
               AND COALESCE(vw.word_type, '') NOT LIKE '%grammar%'`,
        [data.userId],
      );
      const breakdownRows = await query(
        `SELECT vw.mastery_level, COUNT(*) AS count
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1
               AND COALESCE(vw.word_type, '') NOT LIKE '%grammar%'
         GROUP BY vw.mastery_level ORDER BY vw.mastery_level`,
        [data.userId],
      );
      const breakdown = {};
      for (const row of breakdownRows) breakdown[asInt(row.mastery_level)] = asInt(row.count);
      const grammarDue = await query(
        `SELECT COUNT(*) AS count FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND (vw.next_review_date IS NULL OR vw.next_review_date <= $2)
               AND COALESCE(vw.word_type, '') LIKE '%grammar%'`,
        [data.userId, new Date()],
      );
      return {
        dueToday: asInt(due[0].count),
        totalMastered: asInt(mastered[0].count),
        totalWords: asInt(total[0].count),
        reviewedToday: asInt(reviewedToday[0].count),
        grammarDue: asInt(grammarDue[0].count),
        breakdown,
      };
    }

    // Read-only: dung luong DB (toan DB + cua user hien tai)
    case 'getStorageStats': {
      const db = await query('SELECT pg_database_size(current_database()) AS bytes');
      const tables = await query(
        `SELECT relname AS name, pg_total_relation_size(relid) AS bytes
         FROM pg_catalog.pg_statio_user_tables
         ORDER BY pg_total_relation_size(relid) DESC`,
      );
      const counts = await query(
        `SELECT (SELECT COUNT(*) FROM users) AS users,
                (SELECT COUNT(*) FROM vocabulary_lists) AS lists,
                (SELECT COUNT(*) FROM vocabulary_words) AS words`,
      );
      const mine = await query(
        `SELECT COUNT(vw.id) AS words, COALESCE(SUM(pg_column_size(vw)), 0) AS bytes
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1`,
        [data.userId],
      );
      return {
        dbBytes: Number(db[0].bytes),
        tables: tables.map((t) => ({ name: t.name, bytes: Number(t.bytes) })),
        totalUsers: asInt(counts[0].users),
        totalLists: asInt(counts[0].lists),
        totalWords: asInt(counts[0].words),
        myWords: asInt(mine[0].words),
        myBytes: Number(mine[0].bytes),
      };
    }

    case 'getListMasteryBreakdown': {
      const rows = await query(
        `SELECT vw.mastery_level, COUNT(*) AS count FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 GROUP BY vw.mastery_level ORDER BY vw.mastery_level`,
        [data.userId],
      );
      const breakdown = {};
      for (const row of rows) breakdown[asInt(row.mastery_level)] = asInt(row.count);
      return breakdown;
    }

    case 'getCategoryMasteryBreakdown': {
      const rows = await query(
        `SELECT vw.mastery_level, COUNT(*) AS count
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND vw.word_type = $2
         GROUP BY vw.mastery_level ORDER BY vw.mastery_level`,
        [data.userId, data.category],
      );
      const breakdown = {};
      for (const row of rows) breakdown[asInt(row.mastery_level)] = asInt(row.count);
      return breakdown;
    }

    // ---- Search ----
    // Toan bo tu cua user voi payload nhe -> client loc ngay tai may.
    case 'getWordIndex': {
      const rows = await query(
        `SELECT vw.id, vw.word, vw.meaning, vw.word_type, vw.topic_tag, vw.learning_mode, vw.collocations,
                vl.id AS list_id
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1
         ORDER BY vw.word ASC`,
        [data.userId],
      );
      return rows.map((row) => ({
        id: asInt(row.id),
        word: row.word || '',
        meaning: row.meaning || '',
        word_type: row.word_type || '',
        topic_tag: row.topic_tag || '',
        list_id: asInt(row.list_id),
      }));
    }

    // Lay field nang (khong co trong getWordIndex) khi mo sheet sua tu.
    case 'getWordDetails': {
      const rows = await query(
        `SELECT vw.full_details, vw.common_synonyms
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vw.id = $1 AND vl.user_id = $2 LIMIT 1`,
        [data.wordId, data.userId],
      );
      if (rows.length === 0) return null;
      return {
        full_details: rows[0].full_details || '',
        common_synonyms: rows[0].common_synonyms || '',
      };
    }

    // Tim kiem tren toan bo tu da luu cua user (word / meaning / topic_tag).
    case 'searchWord': {
      const q = String(data.query || '').trim().toLowerCase();
      if (!q) return [];
      const rows = await query(
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.example_sentence, vw.example_translation, vw.example_target, vw.common_synonyms, vw.is_mastered, vw.is_difficult,
                vw.review_count, vw.correct_streak, vw.ease_factor, vw.interval_days,
                vw.next_review_date, vw.last_reviewed_at, vw.mastery_level, vw.lapse_count, vw.word_type, vw.topic_tag, vw.learning_mode, vw.collocations,
                vw.created_at, vl.id AS list_id
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1
               AND (LOWER(vw.word) LIKE $2 OR LOWER(vw.meaning) LIKE $2 OR LOWER(vw.topic_tag) LIKE $2)
         ORDER BY vw.word ASC
         LIMIT 200`,
        [data.userId, `%${q}%`],
      );
      return rows.map(mapWordRow);
    }

    case 'findWordByText': {
      const rows = await query(
        `SELECT vw.word, vw.pronunciation, vw.meaning
         FROM vocabulary_words vw
         WHERE LOWER(vw.word) = LOWER($1)
         LIMIT 1`,
        [data.word],
      );
      if (rows.length === 0) return { found: false };
      return {
        found: true,
        word: rows[0].word || '',
        pronunciation: rows[0].pronunciation || '',
        meaning: rows[0].meaning || '',
      };
    }

    // Sua cau vi du bi trung cho chinh user dang dang nhap. Truoc day
    // templateExample() chi co 1 cau co dinh cho moi loai tu, nen mot lo
    // import lon tao ra nhieu cau giong het nhau ("The X was easy to
    // recognize."). Action nay sinh lai bang template bank da da dang.
    case 'repairDuplicateExamples': {
      const apply = Boolean(data.apply);
      const limit = asInt(data.limit) || 0;

      const rows = await query(
        `SELECT vw.id, vw.word, vw.meaning, vw.word_type, vw.example_sentence
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND COALESCE(vw.example_sentence, '') <> ''
         ORDER BY vw.id
         ${limit > 0 ? 'LIMIT ' + Math.min(limit, 2000) : ''}`,
        [data.userId],
      );

      // Nhom theo "skeleton" = cau da bo tu di chinh -> hai tu cung khuon
      // cau se ra cung mot skeleton.
      const groups = new Map();
      for (const row of rows) {
        const word = String(row.word || '').toLowerCase().replace(/\s+/g, ' ').trim();
        let skeleton = normalizeSentenceKey(row.example_sentence);
        if (word) {
          const escaped = word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
          skeleton = skeleton.replace(new RegExp(escaped, 'g'), '{w}');
        }
        if (!groups.has(skeleton)) groups.set(skeleton, []);
        groups.get(skeleton).push(row);
      }

      const duplicateGroups = [...groups.entries()].filter(([, list]) => list.length > 1);
      const clicheGroups = [...groups.entries()].filter(([skeleton]) => LEGACY_CLAICHES.includes(skeleton));

      const targets = new Map();
      for (const [skeleton, list] of [...duplicateGroups, ...clicheGroups]) {
        for (const row of list) targets.set(asInt(row.id), row);
      }

      const report = {
        scanned: rows.length,
        duplicateGroups: duplicateGroups.length,
        clicheGroups: clicheGroups.length,
        toFix: targets.size,
        applied: false,
        updated: 0,
        preview: [],
      };

      if (targets.size === 0) return report;

      // Cau cua tu khong sua duoc giu vao `used` de cau moi sinh ra khong
      // trung voi chung (vd tu do co cau rieng tu AI).
      const used = new Set();
      for (const row of rows) {
        if (!targets.has(asInt(row.id))) used.add(normalizeSentenceKey(row.example_sentence));
      }

      const plan = [];
      for (const row of targets.values()) {
        const next = templateExample(
          { word: row.word, meaning: row.meaning || '', wordType: row.word_type || '' },
          { used },
        );
        plan.push({ id: asInt(row.id), word: row.word, before: row.example_sentence, next });
      }

      report.preview = plan.slice(0, 8).map((item) => ({
        word: item.word,
        before: item.before,
        after: item.next.sentence,
        translation: item.next.translation,
      }));

      if (!apply) return report;

      for (const item of plan) {
        await query(
          `UPDATE vocabulary_words
           SET example_sentence = $1, example_translation = $2, example_target = $3
           WHERE id = $4`,
          [item.next.sentence, item.next.translation, item.next.target, item.id],
        );
        report.updated += 1;
      }
      report.applied = true;
      return report;
    }

    default:
      throw new Error('Unknown action: ' + action);
  }
}

const PUBLIC_ACTIONS = new Set(['init', 'registerUser', 'loginUser']);

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const payload = readPayload(req);
    let data = payload.data || {};

    if (!PUBLIC_ACTIONS.has(payload.action)) {
      const header = req.headers['authorization'] || '';
      const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
      if (!token) {
        res.status(401).json({ error: 'Thieu token xac thuc' });
        return;
      }
      const rows = await query('SELECT user_id FROM auth_tokens WHERE token = $1 LIMIT 1', [token]);
      if (rows.length === 0) {
        res.status(401).json({ error: 'Phien dang nhap het han. Vui long dang nhap lai.' });
        return;
      }
      // userId luon lay tu token - khong tin client gui len
      data = { ...data, userId: asInt(rows[0].user_id) };
    }

    const result = await handleAction(payload.action, data);
    res.status(200).json({ data: result });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
};
