#!/usr/bin/env node
'use strict';

// Audit chat luong tu vung. CHI DOC - khong insert/update/delete.
//
//   node scripts/audit-vocabulary.js                 # toan bo DB
//   node scripts/audit-vocabulary.js --user 3        # chi 1 user
//   node scripts/audit-vocabulary.js --user 3 --json
//
// Exit code: 0 = khong co loi nghiem trong, 1 = co FAIL, 2 = loi cau hinh/ket noi.

const { Client } = require('pg');

const USAGE = `Kiem tra chat luong tu vung (read-only).

Cach dung:
  node scripts/audit-vocabulary.js [--user <id>] [--json] [--limit <n>]

Tuy chon:
  --user, -u   Chi audit tu cua 1 user (mac dinh: toan bo DB)
  --json       In ket qua dang JSON (cho CI)
  --limit      So vi du toi da moi muc (mac dinh 10)
  --help, -h   Hien tro giup

Bien moi truong:
  DATABASE_URL  chuoi ket noi Postgres (bat buoc)

Nguong:
  FAIL  thieu nghia, trung tu, vi du khong chua tu, vi du bi dung lai
  WARN  thieu IPA/loai tu/vi du/ban dich, nghia sai format, nghia dung chung
  INFO  phan bo mastery, tu leech, tu qua han (khong anh huong exit code)
`;

function parseArgs(argv) {
  const args = { user: null, json: false, help: false, limit: 10 };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') {
      args.help = true;
    } else if (arg === '--json') {
      args.json = true;
    } else if (arg === '--user' || arg === '-u') {
      const value = Number(argv[i + 1]);
      if (!Number.isInteger(value) || value <= 0) {
        throw new Error('--user phai la so nguyen duong');
      }
      args.user = value;
      i += 1;
    } else if (arg === '--limit') {
      const value = Number(argv[i + 1]);
      if (!Number.isInteger(value) || value <= 0) {
        throw new Error('--limit phai la so nguyen duong');
      }
      args.limit = value;
      i += 1;
    } else {
      throw new Error(`Tham so khong hop le: ${arg}`);
    }
  }
  return args;
}

function buildQueries(scope) {
  const from = `FROM vocabulary_words vw
    JOIN vocabulary_lists vl ON vw.list_id = vl.id
    WHERE 1 = 1 ${scope}`;
  return {
    totals: `
      SELECT COUNT(*)::int AS total,
             COUNT(DISTINCT LOWER(vw.word))::int AS distinct_words,
             COUNT(*) FILTER (WHERE COALESCE(vw.meaning, '') = '')::int AS no_meaning,
             COUNT(*) FILTER (WHERE COALESCE(vw.pronunciation, '') = '')::int AS no_ipa,
             COUNT(*) FILTER (WHERE COALESCE(vw.word_type, '') = '')::int AS no_word_type,
             COUNT(*) FILTER (WHERE COALESCE(vw.example_sentence, '') = '')::int AS no_example,
             COUNT(*) FILTER (WHERE COALESCE(vw.example_translation, '') = '')::int AS no_example_vi
      ${from}`,
    duplicateWords: `
      SELECT LOWER(vw.word) AS word,
             COUNT(*)::int AS n,
             string_agg(DISTINCT COALESCE(NULLIF(vw.word_type, ''), '(trong)'), ', ') AS types
      ${from}
      GROUP BY 1 HAVING COUNT(*) > 1
      ORDER BY n DESC, word ASC`,
    sharedMeanings: `
      SELECT vw.meaning,
             COUNT(DISTINCT LOWER(vw.word))::int AS n,
             string_agg(DISTINCT vw.word, ', ') AS words
      ${from} AND COALESCE(vw.meaning, '') <> ''
      GROUP BY 1 HAVING COUNT(DISTINCT LOWER(vw.word)) > 1
      ORDER BY n DESC, vw.meaning ASC`,
    meaningFormat: `
      SELECT vw.word, vw.meaning
      ${from}
        AND (vw.meaning !~ '[À-ỹ]'
             OR vw.meaning ~ '[;/]'
             OR vw.meaning ~ '\\s{2,}'
             OR vw.meaning ~ '^\\s|\\s$'
             OR length(vw.meaning) > 80)
      ORDER BY vw.word ASC`,
    exampleMissingWord: `
      SELECT vw.word, vw.example_sentence
      ${from}
        AND COALESCE(vw.example_sentence, '') <> ''
        AND POSITION(LOWER(vw.word) IN LOWER(vw.example_sentence)) = 0
      ORDER BY vw.word ASC`,
    duplicateExamples: `
      SELECT LOWER(vw.example_sentence) AS sentence,
             COUNT(*)::int AS n,
             string_agg(DISTINCT vw.word, ', ') AS words
      ${from} AND COALESCE(vw.example_sentence, '') <> ''
      GROUP BY 1 HAVING COUNT(*) > 1
      ORDER BY n DESC`,
    learning: `
      SELECT COALESCE(vw.mastery_level, 0) AS level,
             COUNT(*)::int AS n,
             COUNT(*) FILTER (WHERE COALESCE(vw.lapse_count, 0) >= 3)::int AS leech,
             COUNT(*) FILTER (WHERE vw.next_review_date IS NOT NULL
                                AND vw.next_review_date < now())::int AS overdue
      ${from}
      GROUP BY 1 ORDER BY 1`,
    leeches: `
      SELECT vw.word, vw.meaning, vw.review_count, vw.lapse_count
      ${from} AND COALESCE(vw.lapse_count, 0) >= 3
      ORDER BY vw.lapse_count DESC, vw.review_count DESC
      LIMIT 20`,
  };
}

function listOf(rows, pick) {
  return rows.slice(0, 10).map(pick);
}

function main(argv) {
  let args;
  try {
    args = parseArgs(argv);
  } catch (error) {
    console.error(error.message);
    console.error(USAGE);
    process.exitCode = 2;
    return Promise.resolve();
  }
  if (args.help) {
    console.log(USAGE);
    return Promise.resolve();
  }
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('Thieu DATABASE_URL. Dat bien moi truong nay roi chay lai.');
    process.exitCode = 2;
    return Promise.resolve();
  }

  const client = new Client({
    connectionString,
    ssl: process.env.PGSSLMODE === 'disable'
      ? false
      : { rejectUnauthorized: false },
  });

  return (async () => {
    await client.connect();
    try {
      const scope = args.user ? 'AND vl.user_id = $1' : '';
      const params = args.user ? [args.user] : [];
      const queries = buildQueries(scope);
      const run = async (sql) => (await client.query(sql, params)).rows;

      const totals = (await run(queries.totals))[0];
      const duplicates = await run(queries.duplicateWords);
      const sharedMeanings = await run(queries.sharedMeanings);
      const meaningFormat = await run(queries.meaningFormat);
      const exampleMissingWord = await run(queries.exampleMissingWord);
      const duplicateExamples = await run(queries.duplicateExamples);
      const learning = await run(queries.learning);
      const leeches = await run(queries.leeches);

      const checks = [
        {
          severity: 'FAIL',
          name: 'Tu thieu nghia',
          count: totals.no_meaning,
          samples: [],
          hint: 'Moi tu phai co nghia tieng Viet.',
        },
        {
          severity: 'FAIL',
          name: 'Trung tu',
          count: duplicates.length,
          samples: listOf(duplicates, (r) => `${r.word} x${r.n} (${r.types})`),
          hint: 'Chi giu 1 dong cho moi tu; xoa bang tay de khong mat du lieu.',
        },
        {
          severity: 'FAIL',
          name: 'Vi du khong chua tu',
          count: exampleMissingWord.length,
          samples: listOf(exampleMissingWord, (r) => `${r.word}: ${r.example_sentence}`),
          hint: 'Vi du phai dung chinh tu (hoac dang bien the cua no).',
        },
        {
          severity: 'FAIL',
          name: 'Vi du bi dung lai',
          count: duplicateExamples.length,
          samples: listOf(duplicateExamples, (r) => `x${r.n} (${r.words}): ${r.sentence}`),
          hint: 'Moi tu nen co cau rieng; cau dung chung lam mat ngu canh.',
        },
        {
          severity: 'WARN',
          name: 'Tu thieu IPA',
          count: totals.no_ipa,
          samples: [],
          hint: 'Co the lam day bang chuc nang lam giau tu.',
        },
        {
          severity: 'WARN',
          name: 'Tu thieu loai tu',
          count: totals.no_word_type,
          samples: [],
          hint: 'Thieu word_type thi the loai/on tap theo loai tu se bo sot.',
        },
        {
          severity: 'WARN',
          name: 'Tu thieu vi du',
          count: totals.no_example,
          samples: [],
          hint: 'Nen co vi du + ban dich de on tap co ngu canh.',
        },
        {
          severity: 'WARN',
          name: 'Vi du thieu ban dich',
          count: totals.no_example_vi,
          samples: [],
          hint: 'Ban dich giup hieu nghia cau.',
        },
        {
          severity: 'WARN',
          name: 'Nghia sai format',
          count: meaningFormat.length,
          samples: listOf(meaningFormat, (r) => `${r.word}: ${r.meaning}`),
          hint: 'Thong nhat 1 kieu: "(pos) nghia", khong dau ; hoac /, khong khoang trang thua.',
        },
        {
          severity: 'WARN',
          name: 'Nghia dung chung cho nhieu tu',
          count: sharedMeanings.length,
          samples: listOf(sharedMeanings, (r) => `${r.meaning} <- ${r.words}`),
          hint: 'Quiz nghia -> tu se co nhieu dap an dung.',
        },
      ];

      const failed = checks.filter((c) => c.severity === 'FAIL' && c.count > 0);
      const warned = checks.filter((c) => c.severity === 'WARN' && c.count > 0);
      const payload = {
        scope: args.user ? { userId: args.user } : { scope: 'all' },
        totals,
        checks,
        learning,
        leeches,
        summary: {
          fail: failed.length,
          warn: warned.length,
          ok: failed.length === 0,
        },
      };

      if (args.json) {
        console.log(JSON.stringify(payload, null, 2));
      } else {
        console.log('=== KIEM TRA CHAT LUONG TU VUNG (read-only) ===');
        console.log(
          `Pham vi: ${args.user ? `user ${args.user}` : 'toan bo DB'} | ` +
            `${totals.total} tu (${totals.distinct_words} tu khac nhau)`,
        );
        console.log('');
        for (const check of checks) {
          if (check.count === 0) continue;
          console.log(`[${check.severity}] ${check.name}: ${check.count}`);
          if (check.samples.length > 0) {
            for (const sample of check.samples.slice(0, args.limit)) {
              console.log(`   - ${sample}`);
            }
            if (check.count > args.limit) {
              console.log(`   ... va ${check.count - args.limit} muc khac`);
            }
          }
          console.log(`   Goi y: ${check.hint}`);
        }
        if (failed.length === 0 && warned.length === 0) {
          console.log('Khong phat hien van de nao.');
        }
        console.log('');
        console.log('--- Suc khoe on tap (tham khao, khong tinh FAIL) ---');
        if (learning.length === 0) {
          console.log('Chua co du lieu on tap.');
        } else {
          const labels = ['New', 'Learning', 'Reviewing', 'Mastered'];
          for (const row of learning) {
            const label = labels[row.level] || `level ${row.level}`;
            console.log(
              `  ${label.padEnd(10)} ${String(row.n).padStart(5)} tu` +
                ` | leech ${row.leech} | qua han ${row.overdue}`,
            );
          }
        }
        if (leeches.length > 0) {
          console.log('  Tu leech (lapse >= 3):');
          for (const row of leeches.slice(0, args.limit)) {
            console.log(
              `   - ${row.word} (${row.lapse_count} lan quen / ${row.review_count} lan on) - ${row.meaning}`,
            );
          }
        }
        console.log('');
        console.log(
          `Ket qua: ${failed.length} FAIL, ${warned.length} WARN` +
            (failed.length === 0 ? ' -> OK' : ' -> CAN SUA'),
        );
      }

      if (failed.length > 0) process.exitCode = 1;
    } finally {
      await client.end();
    }
  })().catch((error) => {
    console.error(`Loi audit: ${error.message}`);
    process.exitCode = 2;
  });
}

if (require.main === module) {
  main(process.argv.slice(2));
}

module.exports = { buildQueries, parseArgs };
