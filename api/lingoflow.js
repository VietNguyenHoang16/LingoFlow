const { Pool } = require('pg');

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

function mapWordRow(row) {
  return {
    id: asInt(row.id),
    word: row.word || '',
    pronunciation: row.pronunciation || '',
    meaning: row.meaning || '',
    full_details: row.full_details || '',
    is_mastered: Boolean(row.is_mastered),
    review_count: asInt(row.review_count),
    correct_streak: asInt(row.correct_streak),
    ease_factor: Number(row.ease_factor ?? 2.5),
    interval_days: asInt(row.interval_days),
    next_review_date: normalizeDate(row.next_review_date),
    last_reviewed_at: normalizeDate(row.last_reviewed_at),
    mastery_level: asInt(row.mastery_level),
    ...(row.set_name !== undefined ? { set_name: row.set_name || '' } : {}),
    ...(row.set_id !== undefined ? { set_id: asInt(row.set_id) } : {}),
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

async function resolveGroupIdForUser(userId) {
  const existing = await query(
    'SELECT id FROM vocabulary_groups WHERE user_id = $1 ORDER BY created_at ASC LIMIT 1',
    [userId],
  );
  if (existing.length > 0) return asInt(existing[0].id);

  const created = await query(
    'INSERT INTO vocabulary_groups (user_id, name) VALUES ($1, $2) RETURNING id',
    [userId, 'Default Pack'],
  );
  if (created.length === 0) throw new Error('Failed to create default vocabulary group');
  return asInt(created[0].id);
}

async function migrateGroupsForExistingSets() {
  const rows = await query(`
    SELECT DISTINCT user_id
    FROM vocabulary_sets
    WHERE group_id IS NULL AND user_id IS NOT NULL
  `);

  for (const row of rows) {
    const userId = asInt(row.user_id);
    const groupId = await resolveGroupIdForUser(userId);
    await query(
      'UPDATE vocabulary_sets SET group_id = $1 WHERE user_id = $2 AND group_id IS NULL',
      [groupId, userId],
    );
  }
}

async function ensureSchema() {
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
        CREATE TABLE IF NOT EXISTS vocabulary_groups (
          id SERIAL PRIMARY KEY,
          user_id INTEGER REFERENCES users(id),
          name VARCHAR(255) NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);

      await query(`
        CREATE TABLE IF NOT EXISTS vocabulary_sets (
          id SERIAL PRIMARY KEY,
          group_id INTEGER REFERENCES vocabulary_groups(id) ON DELETE CASCADE,
          user_id INTEGER REFERENCES users(id),
          name VARCHAR(255) NOT NULL,
          word_count INTEGER DEFAULT 0,
          progress INTEGER DEFAULT 0,
          last_practiced TIMESTAMP,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);

      await query(`
        CREATE TABLE IF NOT EXISTS vocabulary_words (
          id SERIAL PRIMARY KEY,
          set_id INTEGER REFERENCES vocabulary_sets(id) ON DELETE CASCADE,
          word VARCHAR(255) NOT NULL,
          pronunciation VARCHAR(255),
          meaning TEXT NOT NULL,
          full_details TEXT,
          is_mastered BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);

      await addColumnIfNotExists('vocabulary_words', 'full_details', 'TEXT');
      await addColumnIfNotExists('vocabulary_words', 'review_count', 'INTEGER DEFAULT 0');
      await addColumnIfNotExists('vocabulary_words', 'correct_streak', 'INTEGER DEFAULT 0');
      await addColumnIfNotExists('vocabulary_words', 'ease_factor', 'REAL DEFAULT 2.5');
      await addColumnIfNotExists('vocabulary_words', 'interval_days', 'INTEGER DEFAULT 0');
      await addColumnIfNotExists('vocabulary_words', 'next_review_date', 'TIMESTAMP');
      await addColumnIfNotExists('vocabulary_words', 'last_reviewed_at', 'TIMESTAMP');
      await addColumnIfNotExists('vocabulary_words', 'mastery_level', 'INTEGER DEFAULT 0');
      await addColumnIfNotExists(
        'vocabulary_sets',
        'group_id',
        'INTEGER REFERENCES vocabulary_groups(id) ON DELETE CASCADE',
      );

      await query(`
        UPDATE vocabulary_words
        SET mastery_level = 3, interval_days = 30, correct_streak = 5, ease_factor = 2.5
        WHERE is_mastered = TRUE AND (mastery_level IS NULL OR mastery_level = 0)
      `);
      await migrateGroupsForExistingSets();
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
      return rows.length > 0;
    }

    case 'userExists': {
      const rows = await query('SELECT 1 FROM users WHERE id = $1 LIMIT 1', [data.userId]);
      return rows.length > 0;
    }

    case 'createVocabularyGroup': {
      const rows = await query(
        'INSERT INTO vocabulary_groups (user_id, name) VALUES ($1, $2) RETURNING id',
        [data.userId, data.name],
      );
      return asInt(rows[0].id);
    }

    case 'getVocabularyGroups': {
      const rows = await query(
        `SELECT vg.id,
                vg.name,
                COUNT(DISTINCT vs.id) AS list_count,
                COUNT(vw.id) AS word_count,
                SUM(CASE
                  WHEN vw.id IS NOT NULL AND (vw.next_review_date IS NULL OR vw.next_review_date <= $2)
                  THEN 1 ELSE 0
                END) AS due_count,
                ROUND(CASE
                  WHEN COUNT(vw.id) = 0 THEN 0
                  ELSE SUM(CASE WHEN vw.mastery_level >= 3 THEN 1 ELSE 0 END) * 100.0 / COUNT(vw.id)
                END) AS progress,
                MAX(vs.last_practiced) AS last_practiced
         FROM vocabulary_groups vg
         LEFT JOIN vocabulary_sets vs ON vs.group_id = vg.id
         LEFT JOIN vocabulary_words vw ON vw.set_id = vs.id
         WHERE vg.user_id = $1
         GROUP BY vg.id, vg.name, vg.created_at
         ORDER BY vg.created_at DESC`,
        [data.userId, new Date()],
      );
      return rows.map((row) => ({
        id: asInt(row.id),
        name: row.name || '',
        listCount: asInt(row.list_count),
        wordCount: asInt(row.word_count),
        dueCount: asInt(row.due_count),
        progress: asInt(row.progress),
        lastPracticed: normalizeDate(row.last_practiced),
      }));
    }

    case 'deleteVocabularyGroup':
      await query('DELETE FROM vocabulary_groups WHERE id = $1', [data.groupId]);
      return null;

    case 'createVocabularySet': {
      const groupId = data.groupId ?? (await resolveGroupIdForUser(data.userId));
      const rows = await query(
        'INSERT INTO vocabulary_sets (group_id, user_id, name) VALUES ($1, $2, $3) RETURNING id',
        [groupId, data.userId, data.name],
      );
      return asInt(rows[0].id);
    }

    case 'getVocabularySets': {
      const rows = await query(
        `SELECT vs.id, vs.group_id, vs.name, vs.word_count, vs.progress, vs.last_practiced,
                (SELECT COUNT(*) FROM vocabulary_words vw
                 WHERE vw.set_id = vs.id
                 AND (vw.next_review_date IS NULL OR vw.next_review_date <= $2)) AS due_count
         FROM vocabulary_sets vs
         WHERE vs.user_id = $1
         ORDER BY vs.created_at DESC`,
        [data.userId, new Date()],
      );
      return rows.map((row) => ({
        id: asInt(row.id),
        groupId: row.group_id === null ? null : asInt(row.group_id),
        name: row.name || '',
        wordCount: asInt(row.word_count),
        progress: asInt(row.progress),
        lastPracticed: normalizeDate(row.last_practiced),
        dueCount: asInt(row.due_count),
      }));
    }

    case 'getVocabularySetsByGroup': {
      const rows = await query(
        `SELECT vs.id, vs.name, vs.word_count, vs.progress, vs.last_practiced,
                (SELECT COUNT(*) FROM vocabulary_words vw
                 WHERE vw.set_id = vs.id
                 AND (vw.next_review_date IS NULL OR vw.next_review_date <= $3)) AS due_count
         FROM vocabulary_sets vs
         WHERE vs.user_id = $1 AND vs.group_id = $2
         ORDER BY vs.created_at DESC`,
        [data.userId, data.groupId, new Date()],
      );
      return rows.map((row) => ({
        id: asInt(row.id),
        name: row.name || '',
        wordCount: asInt(row.word_count),
        progress: asInt(row.progress),
        lastPracticed: normalizeDate(row.last_practiced),
        dueCount: asInt(row.due_count),
      }));
    }

    case 'updateVocabularySetProgress':
      await query(
        'UPDATE vocabulary_sets SET progress = $1, word_count = $2, last_practiced = CURRENT_TIMESTAMP WHERE id = $3',
        [data.progress, data.wordCount, data.setId],
      );
      return null;

    case 'deleteVocabularySet':
      await query('DELETE FROM vocabulary_sets WHERE id = $1', [data.setId]);
      return null;

    case 'addVocabularyWord': {
      const rows = await query(
        `INSERT INTO vocabulary_words (set_id, word, pronunciation, meaning, full_details)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id`,
        [data.setId, data.word, data.pronunciation || '', data.meaning || '', data.fullDetails || ''],
      );
      return asInt(rows[0].id);
    }

    case 'getVocabularyWords': {
      const rows = await query(
        `SELECT id, word, pronunciation, meaning, full_details, is_mastered,
                review_count, correct_streak, ease_factor, interval_days,
                next_review_date, last_reviewed_at, mastery_level
         FROM vocabulary_words
         WHERE set_id = $1
         ORDER BY created_at DESC`,
        [data.setId],
      );
      return rows.map(mapWordRow);
    }

    case 'updateWordMastered':
      await query('UPDATE vocabulary_words SET is_mastered = $1 WHERE id = $2', [
        data.isMastered,
        data.wordId,
      ]);
      return null;

    case 'deleteVocabularyWord':
      await query('DELETE FROM vocabulary_words WHERE id = $1', [data.wordId]);
      return null;

    case 'updateVocabularyWordDetails':
      await query(
        `UPDATE vocabulary_words
         SET meaning = $1, pronunciation = $2, full_details = $3
         WHERE id = $4`,
        [
          (data.meaning || '').trim(),
          (data.pronunciation || '').trim(),
          (data.fullDetails || '').trim(),
          data.wordId,
        ],
      );
      return null;

    case 'updateWordReview': {
      const masteryLevel = asInt(data.masteryLevel);
      await query(
        `UPDATE vocabulary_words
         SET review_count = $1,
             correct_streak = $2,
             ease_factor = $3,
             interval_days = $4,
             next_review_date = $5,
             last_reviewed_at = CURRENT_TIMESTAMP,
             mastery_level = $6,
             is_mastered = $7
         WHERE id = $8`,
        [
          data.reviewCount,
          data.correctStreak,
          data.easeFactor,
          data.intervalDays,
          new Date(data.nextReviewDate),
          masteryLevel,
          masteryLevel >= 3,
          data.wordId,
        ],
      );
      return null;
    }

    case 'getWordsDueForReview': {
      const rows = await query(
        `SELECT id, word, pronunciation, meaning, full_details, is_mastered,
                review_count, correct_streak, ease_factor, interval_days,
                next_review_date, last_reviewed_at, mastery_level
         FROM vocabulary_words
         WHERE set_id = $1
           AND (next_review_date IS NULL OR next_review_date <= $2)
         ORDER BY COALESCE(next_review_date, CURRENT_TIMESTAMP) ASC`,
        [data.setId, new Date()],
      );
      return rows.map(mapWordRow);
    }

    case 'getAllWordsDueForReview': {
      const rows = await query(
        `SELECT vw.id, vw.word, vw.pronunciation, vw.meaning, vw.full_details, vw.is_mastered,
                vw.review_count, vw.correct_streak, vw.ease_factor, vw.interval_days,
                vw.next_review_date, vw.last_reviewed_at, vw.mastery_level,
                vs.name AS set_name, vs.id AS set_id
         FROM vocabulary_words vw
         JOIN vocabulary_sets vs ON vw.set_id = vs.id
         WHERE vs.user_id = $1
           AND (vw.next_review_date IS NULL OR vw.next_review_date <= $2)
         ORDER BY COALESCE(vw.next_review_date, CURRENT_TIMESTAMP) ASC`,
        [data.userId, new Date()],
      );
      return rows.map(mapWordRow);
    }

    case 'getReviewStats': {
      const due = await query(
        `SELECT COUNT(*) AS count FROM vocabulary_words vw
         JOIN vocabulary_sets vs ON vw.set_id = vs.id
         WHERE vs.user_id = $1
           AND (vw.next_review_date IS NULL OR vw.next_review_date <= $2)`,
        [data.userId, new Date()],
      );
      const mastered = await query(
        `SELECT COUNT(*) AS count FROM vocabulary_words vw
         JOIN vocabulary_sets vs ON vw.set_id = vs.id
         WHERE vs.user_id = $1 AND vw.mastery_level = 3`,
        [data.userId],
      );
      const total = await query(
        `SELECT COUNT(*) AS count FROM vocabulary_words vw
         JOIN vocabulary_sets vs ON vw.set_id = vs.id
         WHERE vs.user_id = $1`,
        [data.userId],
      );
      const reviewedToday = await query(
        `SELECT COUNT(*) AS count FROM vocabulary_words vw
         JOIN vocabulary_sets vs ON vw.set_id = vs.id
         WHERE vs.user_id = $1
           AND vw.last_reviewed_at IS NOT NULL
           AND vw.last_reviewed_at >= CURRENT_DATE`,
        [data.userId],
      );
      const breakdownRows = await query(
        `SELECT vw.mastery_level, COUNT(*) AS count
         FROM vocabulary_words vw
         JOIN vocabulary_sets vs ON vw.set_id = vs.id
         WHERE vs.user_id = $1
         GROUP BY vw.mastery_level
         ORDER BY vw.mastery_level`,
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

    case 'getSetMasteryBreakdown': {
      const rows = await query(
        `SELECT mastery_level, COUNT(*) AS count
         FROM vocabulary_words
         WHERE set_id = $1
         GROUP BY mastery_level
         ORDER BY mastery_level`,
        [data.setId],
      );
      const breakdown = {};
      for (const row of rows) breakdown[asInt(row.mastery_level)] = asInt(row.count);
      return breakdown;
    }

    case 'searchWord': {
      const rows = await query(
        `SELECT vw.id, vw.word, vw.meaning, vs.id AS set_id, vs.name AS set_name,
                vg.id AS group_id, vg.name AS group_name
         FROM vocabulary_words vw
         JOIN vocabulary_sets vs ON vw.set_id = vs.id
         JOIN vocabulary_groups vg ON vs.group_id = vg.id
         WHERE vg.user_id = $1 AND LOWER(vw.word) LIKE LOWER($2)
         ORDER BY vw.word ASC`,
        [data.userId, `%${data.query || ''}%`],
      );
      return rows.map((row) => ({
        word: row.word || '',
        meaning: row.meaning || '',
        set_id: asInt(row.set_id),
        set_name: row.set_name || '',
        group_id: asInt(row.group_id),
        group_name: row.group_name || '',
      }));
    }

    default:
      throw new Error(`Unknown action: ${action}`);
  }
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

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
    const data = await handleAction(payload.action, payload.data || {});
    res.status(200).json({ data });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
};
