#!/usr/bin/env node
'use strict';

// Gop tat ca danh sach cua moi user ve MOT list duy nhat (khong ten).
//
//   node scripts/migrate-single-list.js               # dry-run: chay SQL roi ROLLBACK
//   node scripts/migrate-single-list.js --apply       # commit + tao bang backup
//   node scripts/migrate-single-list.js --user 3 --apply
//
// An toan du lieu:
//  - Chi UPDATE vocabulary_words.list_id, KHONG xoa tu nao.
//  - Chi xoa cac list da rong sau khi chuyen tu.
//  - Chay trong 1 transaction; so sanh so tu + tong id truoc/sau, lech -> ROLLBACK.
//  - Khi --apply se tao ban sao vocabulary_words_backup_<ts> /
//    vocabulary_lists_backup_<ts> trong cung transaction de khoi phuc thu cong.
//  - Chay lai nhieu lan khong doi ket qua (idempotent).

const { Client } = require('pg');

const USAGE = `Gop ve mot list duy nhat cho moi user.

Cach dung:
  node scripts/migrate-single-list.js [--apply] [--user <id>]

Tuy chon:
  --apply      Thuc su ghi thay doi (mac dinh: dry-run, luon ROLLBACK)
  --user, -u   Chi xu ly 1 user
  --help, -h   Hien tro giup

Bien moi truong:
  DATABASE_URL  chuoi ket noi Postgres (bat buoc)
`;

function parseArgs(argv) {
  const args = { apply: false, user: null, help: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--apply') {
      args.apply = true;
    } else if (arg === '--help' || arg === '-h') {
      args.help = true;
    } else if (arg === '--user' || arg === '-u') {
      const value = Number(argv[i + 1]);
      if (!Number.isInteger(value) || value <= 0) {
        throw new Error('--user phai la so nguyen duong');
      }
      args.user = value;
      i += 1;
    } else {
      throw new Error(`Tham so khong hop le: ${arg}`);
    }
  }
  return args;
}

function backupSuffix() {
  return new Date().toISOString().replace(/\D/g, '').slice(0, 14);
}

async function snapshot(client, userId) {
  const rows = userId
    ? (
        await client.query(
          `SELECT COUNT(*)::int AS words, COALESCE(SUM(vw.id), 0)::bigint AS id_sum
           FROM vocabulary_words vw
           JOIN vocabulary_lists vl ON vw.list_id = vl.id
           WHERE vl.user_id = $1`,
          [userId],
        )
      ).rows
    : (
        await client.query(
          `SELECT COUNT(*)::int AS words, COALESCE(SUM(vw.id), 0)::bigint AS id_sum
           FROM vocabulary_words vw`,
        )
      ).rows;
  return { words: rows[0].words, idSum: String(rows[0].id_sum) };
}

async function mergeUser(client, userId) {
  const before = (
    await client.query(
      `SELECT v.id, COALESCE(v.name, '') AS name, COALESCE(v.category, '') AS category,
              (SELECT COUNT(*)::int FROM vocabulary_words w WHERE w.list_id = v.id) AS words
       FROM vocabulary_lists v
       WHERE v.user_id = $1
       ORDER BY v.id`,
      [userId],
    )
  ).rows;

  const canonical = (
    await client.query(
      `SELECT id FROM vocabulary_lists
       WHERE user_id = $1 AND COALESCE(name, '') = '' AND COALESCE(category, '') = ''
       ORDER BY id LIMIT 1`,
      [userId],
    )
  ).rows[0];
  let canonicalId = canonical ? canonical.id : null;
  if (!canonicalId) {
    canonicalId = (
      await client.query(
        `INSERT INTO vocabulary_lists (user_id, category, name)
         VALUES ($1, '', '') RETURNING id`,
        [userId],
      )
    ).rows[0].id;
  }

  const moved = await client.query(
    `UPDATE vocabulary_words
     SET list_id = $1
     WHERE list_id IN (SELECT id FROM vocabulary_lists WHERE user_id = $2)
       AND list_id <> $1`,
    [canonicalId, userId],
  );

  const removed = await client.query(
    `DELETE FROM vocabulary_lists vl
     WHERE vl.user_id = $1 AND vl.id <> $2
       AND NOT EXISTS (SELECT 1 FROM vocabulary_words vw WHERE vw.list_id = vl.id)`,
    [userId, canonicalId],
  );

  const leftover = (
    await client.query(
      `SELECT COUNT(*)::int AS n
       FROM vocabulary_words vw
       JOIN vocabulary_lists vl ON vw.list_id = vl.id
       WHERE vl.user_id = $1 AND vl.id <> $2`,
      [userId, canonicalId],
    )
  ).rows[0].n;

  const after = (
    await client.query(
      `SELECT COUNT(*)::int AS lists,
              (SELECT COUNT(*)::int FROM vocabulary_words w WHERE w.list_id = $2) AS words_in_list
       FROM vocabulary_lists WHERE user_id = $1`,
      [userId, canonicalId],
    )
  ).rows[0];

  return {
    userId,
    canonicalId,
    listsBefore: before.length,
    listsAfter: after.lists,
    wordsBefore: before.reduce((sum, row) => sum + row.words, 0),
    wordsInList: after.words_in_list,
    wordsMoved: moved.rowCount,
    listsRemoved: removed.rowCount,
    leftover,
    renamedLists: before.filter(
      (row) => row.id !== canonicalId && (row.name !== '' || row.category !== ''),
    ).map((row) => `#${row.id} ${row.name || '(khong ten)'}/${row.category || '-'}`),
  };
}

async function main(argv) {
  let args;
  try {
    args = parseArgs(argv);
  } catch (error) {
    console.error(error.message);
    console.error(USAGE);
    process.exitCode = 2;
    return;
  }
  if (args.help) {
    console.log(USAGE);
    return;
  }
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('Thieu DATABASE_URL. Dat bien moi truong nay roi chay lai.');
    process.exitCode = 2;
    return;
  }

  const client = new Client({
    connectionString,
    ssl: process.env.PGSSLMODE === 'disable'
      ? false
      : { rejectUnauthorized: false },
  });
  try {
    await client.connect();
  } catch (error) {
    console.error(`Khong ket noi duoc DB: ${error.message}`);
    process.exitCode = 2;
    return;
  }

  let committed = false;
  try {
    await client.query('BEGIN');
    const before = await snapshot(client, args.user);
    if (before.words === 0) {
      console.log('Khong co tu nao trong pham vi. Khong co gi de gop.');
      await client.query('ROLLBACK');
      return;
    }

    console.log(`Che do: ${args.apply ? 'APPLY (ghi that)' : 'DRY-RUN (chi chay, se ROLLBACK)'}`);
    console.log(`Pham vi: ${args.user ? `user ${args.user}` : 'toan bo DB'}`);
    console.log(`Tu truoc khi chay: ${before.words} (tong id ${before.idSum})`);
    console.log('');

    if (args.apply) {
      const ts = backupSuffix();
      await client.query(
        `CREATE TABLE IF NOT EXISTS vocabulary_words_backup_${ts} AS SELECT * FROM vocabulary_words`,
      );
      await client.query(
        `CREATE TABLE IF NOT EXISTS vocabulary_lists_backup_${ts} AS SELECT * FROM vocabulary_lists`,
      );
      console.log(`Da tao backup: vocabulary_words_backup_${ts}, vocabulary_lists_backup_${ts}`);
      console.log('');
    }

    const users = (
      await client.query(
        `SELECT DISTINCT user_id FROM vocabulary_lists
         WHERE user_id IS NOT NULL ${args.user ? 'AND user_id = $1' : ''}
         ORDER BY user_id`,
        args.user ? [args.user] : [],
      )
    ).rows.map((row) => row.user_id);

    const report = [];
    for (const userId of users) {
      report.push(await mergeUser(client, userId));
    }

    for (const row of report) {
      console.log(
        `user ${row.userId}: ${row.listsBefore} list -> ${row.listsAfter} list | ` +
          `${row.wordsBefore} tu -> list #${row.canonicalId} (${row.wordsInList} tu) | ` +
          `chuyen ${row.wordsMoved}, xoa ${row.listsRemoved} list rong`,
      );
      if (row.renamedLists.length > 0) {
        console.log(`   list duoc gop: ${row.renamedLists.join(', ')}`);
      }
      if (row.leftover !== 0) {
        throw new Error(
          `user ${row.userId}: con ${row.leftover} tu nam ngoai list chuan -> huy toan bo thay doi`,
        );
      }
    }

    const after = await snapshot(client, args.user);
    if (after.words !== before.words || after.idSum !== before.idSum) {
      throw new Error(
        `So tu/tong id thay doi (${before.words}/${before.idSum} -> ${after.words}/${after.idSum}) -> huy`,
      );
    }
    console.log('');
    console.log(`Kiem tra: ${before.words} tu truoc / ${after.words} tu sau - khong mat tu nao. OK`);

    if (args.apply) {
      await client.query('COMMIT');
      committed = true;
      console.log('Da commit. Chay lai script de kiem tra (se bao 1 list/user).');
    } else {
      await client.query('ROLLBACK');
      console.log('Dry-run xong - chua ghi gi. Them --apply de thuc thi.');
    }
  } catch (error) {
    if (!committed) {
      await client.query('ROLLBACK').catch(() => {});
    }
    console.error(`Loi migration: ${error.message}`);
    console.error('Da ROLLBACK, du lieu giu nguyen.');
    process.exitCode = 1;
  } finally {
    await client.end();
  }
}

if (require.main === module) {
  main(process.argv.slice(2));
}

module.exports = { mergeUser, parseArgs, snapshot };
