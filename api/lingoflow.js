const { Pool } = require('pg');
const crypto = require('crypto');

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


async function ensureCanonicalList(userId, category) {
  const rows = await query(
    'SELECT id FROM vocabulary_lists WHERE user_id = $1 AND category = $2 LIMIT 1',
    [userId, category],
  );
  if (rows.length > 0) return asInt(rows[0].id);
  const r = await query(
    'INSERT INTO vocabulary_lists (user_id, category, name) VALUES ($1, $2, $3) RETURNING id',
    [userId, category, category.charAt(0).toUpperCase() + category.slice(1)],
  );
  return asInt(r[0].id);
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
    created_at: normalizeDate(row.created_at),
    ...(row.list_name !== undefined ? { list_name: row.list_name || '' } : {}),
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

async function ensureSchema() {
  if (!schemaReady) {
    schemaReady = (async () => {
      // Core tables
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
      await dropColumnIfExists('vocabulary_words', 'example_sentence');

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

    case 'getListsByCategory': {
      const rows = await query(
        `SELECT vl.id, vl.name, vl.word_count, vl.progress, vl.last_practiced,
                (SELECT COUNT(*) FROM vocabulary_words vw2
                 WHERE vw2.list_id = vl.id AND vw2.word_type = $3
                 AND (vw2.next_review_date IS NULL OR vw2.next_review_date <= $2)) AS due_count,
                (SELECT COUNT(*) FROM vocabulary_words vw2
                 WHERE vw2.list_id = vl.id AND vw2.word_type = $3) AS cat_word_count
         FROM vocabulary_lists vl
         WHERE vl.user_id = $1
           AND EXISTS (SELECT 1 FROM vocabulary_words vw WHERE vw.list_id = vl.id AND vw.word_type = $3)
         ORDER BY vl.created_at DESC`,
        [data.userId, new Date(), data.category],
      );
      return rows.map((row) => ({
        id: asInt(row.id),
        name: row.name || '',
        wordCount: asInt(row.cat_word_count),
        progress: asInt(row.progress),
        lastPracticed: normalizeDate(row.last_practiced),
        dueCount: asInt(row.due_count),
      }));
    }

    case 'getAllLists': {
      const rows = await query(
        `SELECT vl.id, vl.name, vl.category, vl.word_count, vl.progress, vl.last_practiced,
                 (SELECT COUNT(*) FROM vocabulary_words vw
                  WHERE vw.list_id = vl.id
                  AND (vw.next_review_date IS NULL OR vw.next_review_date <= $2)
                  AND vw.word_type != 'grammar') AS due_count
         FROM vocabulary_lists vl
         WHERE vl.user_id = $1
         ORDER BY vl.category, vl.created_at DESC`,
        [data.userId, new Date()],
      );
      return rows.map((row) => ({
        id: asInt(row.id),
        name: row.name || '',
        category: row.category || '',
        wordCount: asInt(row.word_count),
        progress: asInt(row.progress),
        lastPracticed: normalizeDate(row.last_practiced),
        dueCount: asInt(row.due_count),
      }));
    }

    case 'updateListProgress':
      await query(
        'UPDATE vocabulary_lists SET progress = $1, word_count = $2, last_practiced = CURRENT_TIMESTAMP WHERE id = $3 AND user_id = $4',
        [data.progress, data.wordCount, data.listId, data.userId],
      );
      return null;

    case 'deleteList':
      await query('DELETE FROM vocabulary_lists WHERE id = $1 AND user_id = $2', [data.listId, data.userId]);
      return null;

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
           WHERE vl.user_id = $1 AND vw.word_type = $3`,
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
        `SELECT vw.word_type AS cat,
                COUNT(DISTINCT vl.id) AS list_count,
                COUNT(DISTINCT vw.id) AS word_count,
                SUM(CASE WHEN vw.next_review_date IS NULL OR vw.next_review_date <= $2 THEN 1 ELSE 0 END) AS due_count,
                ROUND(CASE WHEN COUNT(vw.id) = 0 THEN 0 ELSE SUM(CASE WHEN COALESCE(vw.mastery_level, 0) >= 3 THEN 1 ELSE 0 END) * 100.0 / COUNT(vw.id) END) AS progress
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1
         GROUP BY vw.word_type`,
        [data.userId, now],
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
        `SELECT COUNT(*) FILTER (WHERE vw.next_review_date IS NULL OR vw.next_review_date <= $2) AS due_today,
                COUNT(*) FILTER (WHERE vw.mastery_level = 3) AS total_mastered,
                COUNT(*) AS total_words,
                COUNT(*) FILTER (WHERE vw.last_reviewed_at IS NOT NULL AND vw.last_reviewed_at >= CURRENT_DATE) AS reviewed_today
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND vw.word_type != 'grammar'`,
        [data.userId, now],
      );
      const breakdownRows = await query(
        `SELECT vw.mastery_level, COUNT(*) AS count
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND vw.word_type != 'grammar'
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
          breakdown,
        },
      };
    }

    // ---- Words ----
    case 'addVocabularyWord': {
      let listId = data.listId;
      if (!listId && data.category) {
        listId = await ensureCanonicalList(data.userId, data.category);
      }
      if (!listId) throw new Error('Thieu listId hoac category');
      const ownerCheck = await query(
        'SELECT user_id FROM vocabulary_lists WHERE id = $1 LIMIT 1',
        [listId],
      );
      if (ownerCheck.length === 0 || asInt(ownerCheck[0].user_id) !== asInt(data.userId)) {
        throw new Error('Khong co quyen them vao danh sach nay');
      }
      const userCheck = await query(
        'SELECT id FROM vocabulary_words WHERE list_id = $1 AND LOWER(word) = LOWER($2) LIMIT 1',
        [listId, data.word],
      );
      if (userCheck.length > 0) {
        throw new Error('Tu nay da ton tai');
      }
      const wordType = (data.wordType || '').trim() || data.category || '';
      const rows = await query(
        `INSERT INTO vocabulary_words (list_id, word, pronunciation, meaning, full_details, word_type)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id`,
        [listId, data.word, data.pronunciation || '', data.meaning || '', data.fullDetails || '', wordType],
      );
      return asInt(rows[0].id);
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

    case 'bulkAddWords': {
      const items = Array.isArray(data.words) ? data.words : [];
      if (items.length === 0) return { insertedCount: 0 };

      let listId = data.listId;
      if (!listId && data.category) {
        listId = await ensureCanonicalList(data.userId, data.category);
      }
      if (!listId) throw new Error('Thieu listId hoac category');
      const ownerCheck = await query(
        'SELECT user_id FROM vocabulary_lists WHERE id = $1 LIMIT 1',
        [listId],
      );
      if (ownerCheck.length === 0 || asInt(ownerCheck[0].user_id) !== asInt(data.userId)) {
        throw new Error('Khong co quyen them vao danh sach nay');
      }

      // Loai tu trung (theo user, khong phai chi trong list nay)
      const candidates = [...new Set(items.map((it) => String(it.word || '').toLowerCase()).filter(Boolean))];
      const existingRows = candidates.length > 0 ? await query(
        `SELECT DISTINCT LOWER(vw.word) AS w
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND LOWER(vw.word) = ANY($2)`,
        [data.userId, candidates],
      ) : [];
      const existing = new Set(existingRows.map((row) => row.w));

      let insertedCount = 0;
      const CHUNK = 100;
      for (let i = 0; i < items.length; i += CHUNK) {
        const chunk = [];
        const params = [listId];
        const seenInPayload = new Set();
        for (const it of items.slice(i, i + CHUNK)) {
          const word = String(it.word || '').trim();
          if (!word) continue;
          const lower = word.toLowerCase();
          if (existing.has(lower) || seenInPayload.has(lower)) continue;
          seenInPayload.add(lower);
          const base = params.length;
          params.push(word, it.pronunciation || '', it.meaning || '', it.fullDetails || '', (it.wordType || '').trim());
          chunk.push(`($1, $${base + 1}, $${base + 2}, $${base + 3}, $${base + 4}, $${base + 5})`);
        }
        if (chunk.length === 0) continue;
        await query(
          `INSERT INTO vocabulary_words (list_id, word, pronunciation, meaning, full_details, word_type)
           VALUES ${chunk.join(', ')}`,
          params,
        );
        insertedCount += chunk.length;
      }
      return { insertedCount };
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
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.is_mastered, vw.is_difficult,
                vw.review_count, vw.correct_streak, vw.ease_factor, vw.interval_days,
                vw.next_review_date, vw.last_reviewed_at, vw.mastery_level, vw.lapse_count, vw.word_type
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.id = $1 AND vl.user_id = $2
         ORDER BY vw.created_at DESC, vw.id DESC`,
        [data.listId, data.userId],
      );
      return rows.map(mapWordRow);
    }

    case 'getWordsByCategory': {
      const rows = await query(
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.is_mastered, vw.is_difficult,
                vw.review_count, vw.correct_streak, vw.ease_factor, vw.interval_days,
                vw.next_review_date, vw.last_reviewed_at, vw.mastery_level, vw.lapse_count, vw.word_type,
                vl.name AS list_name, vl.id AS list_id
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND vw.word_type = $2
         ORDER BY vw.created_at DESC`,
        [data.userId, data.category],
      );
      return rows.map(mapWordRow);
    }

    case 'getRecentWords': {
      const limit = Math.min(Math.max(asInt(data.limit) || 20, 1), 100);
      const rows = await query(
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.is_mastered, vw.is_difficult,
                vw.review_count, vw.correct_streak, vw.ease_factor, vw.interval_days,
                vw.next_review_date, vw.last_reviewed_at, vw.mastery_level, vw.lapse_count, vw.word_type,
                vw.created_at,
                vl.name AS list_name, vl.id AS list_id
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
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details
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

    case 'updateVocabularyWordDetails':
      await query(
        `UPDATE vocabulary_words SET meaning = $1, pronunciation = $2, full_details = $3, word_type = $4
         WHERE id = $5 AND list_id IN (SELECT id FROM vocabulary_lists WHERE user_id = $6)`,
        [(data.meaning || '').trim(), (data.pronunciation || '').trim(), (data.fullDetails || '').trim(), (data.wordType || '').trim(), data.wordId, data.userId],
      );
      return null;

    case 'updateVocabularyWord':
      await query(
        `UPDATE vocabulary_words SET word = $1, pronunciation = $2, meaning = $3, full_details = $4, word_type = $5
         WHERE id = $6 AND list_id IN (SELECT id FROM vocabulary_lists WHERE user_id = $7)`,
        [(data.word || '').trim(), (data.pronunciation || '').trim(), (data.meaning || '').trim(), (data.fullDetails || '').trim(), (data.wordType || '').trim(), data.wordId, data.userId],
      );
      return null;

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
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.is_mastered, vw.is_difficult,
                vw.review_count, vw.correct_streak, vw.ease_factor, vw.interval_days,
                vw.next_review_date, vw.last_reviewed_at, vw.mastery_level, vw.lapse_count, vw.word_type
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.id = $1 AND vl.user_id = $2 AND (vw.next_review_date IS NULL OR vw.next_review_date <= $3)
               AND vw.word_type != 'grammar'
         ORDER BY COALESCE(vw.next_review_date, CURRENT_TIMESTAMP) ASC`,
        [data.listId, data.userId, new Date()],
      );
      return rows.map(mapWordRow);
    }

    case 'getAllWordsDueForReview': {
      const rows = await query(
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.is_mastered, vw.is_difficult,
                vw.review_count, vw.correct_streak, vw.ease_factor, vw.interval_days,
                vw.next_review_date, vw.last_reviewed_at, vw.mastery_level, vw.lapse_count, vw.word_type,
                vl.name AS list_name, vl.id AS list_id
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND (vw.next_review_date IS NULL OR vw.next_review_date <= $2)
               AND vw.word_type != 'grammar'
         ORDER BY COALESCE(vw.next_review_date, CURRENT_TIMESTAMP) ASC`,
        [data.userId, new Date()],
      );
      return rows.map(mapWordRow);
    }

    case 'getWordsDueForReviewByCategory': {
      const rows = await query(
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.is_mastered, vw.is_difficult,
                vw.review_count, vw.correct_streak, vw.ease_factor, vw.interval_days,
                vw.next_review_date, vw.last_reviewed_at, vw.mastery_level, vw.lapse_count, vw.word_type,
                vl.name AS list_name, vl.id AS list_id
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND vw.word_type = $2 AND (vw.next_review_date IS NULL OR vw.next_review_date <= $3)
         ORDER BY COALESCE(vw.next_review_date, CURRENT_TIMESTAMP) ASC`,
        [data.userId, data.category, new Date()],
      );
      return rows.map(mapWordRow);
    }

    case 'getReviewStats': {
      const due = await query(
        `SELECT COUNT(*) AS count FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND (vw.next_review_date IS NULL OR vw.next_review_date <= $2)
               AND vw.word_type != 'grammar'`,
        [data.userId, new Date()],
      );
      const mastered = await query(
        `SELECT COUNT(*) AS count FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND vw.mastery_level = 3
               AND vw.word_type != 'grammar'`,
        [data.userId],
      );
      const total = await query(
        `SELECT COUNT(*) AS count FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1
               AND vw.word_type != 'grammar'`,
        [data.userId],
      );
      const reviewedToday = await query(
        `SELECT COUNT(*) AS count FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND vw.last_reviewed_at IS NOT NULL AND vw.last_reviewed_at >= CURRENT_DATE
               AND vw.word_type != 'grammar'`,
        [data.userId],
      );
      const breakdownRows = await query(
        `SELECT vw.mastery_level, COUNT(*) AS count
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1
               AND vw.word_type != 'grammar'
         GROUP BY vw.mastery_level ORDER BY vw.mastery_level`,
        [data.userId],
      );
      const breakdown = {};
      for (const row of breakdownRows) breakdown[asInt(row.mastery_level)] = asInt(row.count);
      return {
        dueToday: asInt(due[0].count),
        totalMastered: asInt(mastered[0].count),
        totalWords: asInt(total[0].count),
        reviewedToday: asInt(reviewedToday[0].count),
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
         WHERE vl.id = $1 AND vl.user_id = $2 GROUP BY vw.mastery_level ORDER BY vw.mastery_level`,
        [data.listId, data.userId],
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
    case 'searchWord': {
      const rows = await query(
        `SELECT vw.id, vw.word, vw.meaning, vw.word_type, vl.id AS list_id, vl.name AS list_name,
                vl.category AS category
         FROM vocabulary_words vw
         JOIN vocabulary_lists vl ON vw.list_id = vl.id
         WHERE vl.user_id = $1 AND LOWER(vw.word) LIKE LOWER($2)
         ORDER BY vw.word ASC`,
        [data.userId, '%' + (data.query || '') + '%'],
      );
      return rows.map((row) => ({
        id: asInt(row.id),
        word: row.word || '',
        meaning: row.meaning || '',
        word_type: row.word_type || '',
        list_id: asInt(row.list_id),
        list_name: row.list_name || '',
        category: row.category || '',
      }));
    }

    case 'findWordByText': {
      const rows = await query(
        `SELECT vw.word, vw.pronunciation, vw.meaning, vl.name AS list_name
         FROM vocabulary_words vw
         LEFT JOIN vocabulary_lists vl ON vw.list_id = vl.id
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
        list_name: rows[0].list_name || '',
      };
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
