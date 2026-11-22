import { Kysely, sql } from 'kysely';
import { AssetFileType, ChecksumAlgorithm } from 'src/enum.js';
import { ConfigRepository } from 'src/repositories/config.repository.js';
import { DatabaseRepository } from 'src/repositories/database.repository.js';
import { LoggingRepository } from 'src/repositories/logging.repository.js';
import { DB } from 'src/schema/index.js';
import { BaseService } from 'src/services/base.service.js';
import { hashAssetPath } from 'src/utils/checksum.js';
import { mediumFactory, newMediumService } from 'test/medium.factory.js';
import { getKyselyDB } from 'test/utils.js';

const forkNames = [
  '1781748259837-AllowDuplicateExternalLibraryChecksums',
  '1781960000000-RestoreExternalLibraryChecksumUniqueness',
];
const lastUpstream = '1792568637987-AddAssetOwnerIdUpdateIdIndex';

let db: Kysely<DB>;
let sut: DatabaseRepository;

beforeEach(async () => {
  db = await getKyselyDB();
  sut = new DatabaseRepository(db, LoggingRepository.create(), new ConfigRepository());
});

afterEach(async () => {
  await db.destroy();
});

const seedForkHistory = async () => {
  await sql`
    INSERT INTO "kysely_migrations" ("name", "timestamp")
    VALUES (${forkNames[0]}, '2026-10-20T12:00:00.000Z'), (${forkNames[1]}, '2026-10-20T12:00:01.000Z')
  `.execute(db);
};

const useLegacyIndex = async () => {
  await sql`DROP INDEX "asset_ownerId_libraryId_checksum_idx"`.execute(db);
  await sql`
    CREATE INDEX "asset_ownerId_libraryId_checksum_idx"
    ON "asset" ("ownerId", "libraryId", "checksum") WHERE ("libraryId" IS NOT NULL)
  `.execute(db);
};

const getIndex = async () => {
  const { rows } = await sql<{ oid: string; unique: boolean }>`
    SELECT indexrelid::text AS oid, indisunique AS "unique"
    FROM pg_index WHERE indexrelid = '"asset_ownerId_libraryId_checksum_idx"'::regclass
  `.execute(db);
  return rows[0];
};

const seedExternalAssets = async (duplicate: boolean) => {
  const { ctx } = newMediumService(BaseService, { database: db, real: [], mock: [LoggingRepository] });
  const { result: user } = await ctx.newUser();
  const { id: libraryId } = await db
    .insertInto('library')
    .values({ name: 'External', ownerId: user.id, importPaths: [], exclusionPatterns: [] })
    .returning('id')
    .executeTakeFirstOrThrow();
  const assets = ['/first.jpg', '/second.jpg'].map((originalPath, index) =>
    mediumFactory.assetInsert({
      ownerId: user.id,
      libraryId,
      originalPath,
      isExternal: true,
      checksum: Buffer.alloc(20, duplicate ? 1 : index),
      checksumAlgorithm: ChecksumAlgorithm.sha1File,
    }),
  );
  await db.insertInto('asset').values(assets).execute();
};

const getChecksums = () =>
  db.selectFrom('asset').select(['id', 'checksum', 'checksumAlgorithm']).orderBy('id').execute();

describe('migrateFilePaths', () => {
  it('rehashes the remapped Chinese path while preserving content checksums', async () => {
    await seedExternalAssets(false);
    const first = await db
      .updateTable('asset')
      .set({ originalPath: '/旧库/照片.JPG', checksumAlgorithm: ChecksumAlgorithm.sha1Path })
      .where('originalPath', '=', '/first.jpg')
      .returning('id')
      .executeTakeFirstOrThrow();
    const second = await db
      .updateTable('asset')
      .set({ originalPath: '/旧库/影片.mp4' })
      .where('originalPath', '=', '/second.jpg')
      .returning(['id', 'checksum'])
      .executeTakeFirstOrThrow();
    await db
      .insertInto('asset_file')
      .values({
        assetId: first.id,
        type: AssetFileType.Sidecar,
        path: '/旧库/照片.JPG.xmp',
      })
      .execute();

    await sut.migrateFilePaths('/旧库/', '/新库/');

    const rows = await db.selectFrom('asset').selectAll().execute();
    expect(rows.find(({ id }) => id === first.id)).toMatchObject({
      originalPath: '/新库/照片.JPG',
      checksum: hashAssetPath('/新库/照片.JPG'),
      checksumAlgorithm: ChecksumAlgorithm.sha1Path,
    });
    expect(rows.find(({ id }) => id === second.id)).toMatchObject({
      originalPath: '/新库/影片.mp4',
      checksum: second.checksum,
      checksumAlgorithm: ChecksumAlgorithm.sha1File,
    });
    expect(await db.selectFrom('asset_file').select('path').where('assetId', '=', first.id).execute()).toEqual([
      { path: '/新库/照片.JPG.xmp' },
    ]);
  });

  it('rolls back path and checksum writes when a later table rejects the migration', async () => {
    await seedExternalAssets(false);
    const asset = await db
      .updateTable('asset')
      .set({ originalPath: '/旧库/照片.JPG', checksumAlgorithm: ChecksumAlgorithm.sha1Path })
      .where('originalPath', '=', '/first.jpg')
      .returningAll()
      .executeTakeFirstOrThrow();
    await db
      .insertInto('asset_file')
      .values({
        assetId: asset.id,
        type: AssetFileType.Sidecar,
        path: '/旧库/照片.JPG.xmp',
      })
      .execute();
    await sql`ALTER TABLE asset_file ADD CHECK (path NOT LIKE '/新库/%')`.execute(db);

    await expect(sut.migrateFilePaths('/旧库', '/新库')).rejects.toMatchObject({ code: '23514' });
    expect(await db.selectFrom('asset').selectAll().where('id', '=', asset.id).executeTakeFirstOrThrow()).toEqual(
      asset,
    );
    expect(await db.selectFrom('asset_file').select('path').where('assetId', '=', asset.id).execute()).toEqual([
      { path: '/旧库/照片.JPG.xmp' },
    ]);
  });

  it('rejects a destination already used in the same external library', async () => {
    await seedExternalAssets(false);
    await db
      .updateTable('asset')
      .set({ originalPath: '/旧库/照片.JPG' })
      .where('originalPath', '=', '/first.jpg')
      .execute();
    await db
      .updateTable('asset')
      .set({ originalPath: '/新库/照片.JPG' })
      .where('originalPath', '=', '/second.jpg')
      .execute();
    const before = await db.selectFrom('asset').selectAll().orderBy('id').execute();

    await expect(sut.migrateFilePaths('/旧库', '/新库')).rejects.toThrow('multiple external assets would share a path');
    expect(await db.selectFrom('asset').selectAll().orderBy('id').execute()).toEqual(before);
  });
});

describe('external library migration compatibility', () => {
  it('keeps a valid index with custom storage options and identifier quoting', async () => {
    await sql`ALTER INDEX "asset_ownerId_libraryId_checksum_idx" SET (fillfactor = 80)`.execute(db);
    const index = await getIndex();
    expect(index.unique).toBe(true);

    await db.connection().execute(async (connection) => {
      await sql`SET quote_all_identifiers = on`.execute(connection);
      try {
        const repository = new DatabaseRepository(connection, LoggingRepository.create(), new ConfigRepository());
        expect(await repository.runMigrations()).toBe(0);
      } finally {
        await sql`RESET quote_all_identifiers`.execute(connection);
      }
    });

    expect(await getIndex()).toEqual(index);
  });

  it.each([
    ['key order', '("libraryId", "ownerId", "checksum") WHERE ("libraryId" IS NOT NULL)'],
    ['predicate', '("ownerId", "libraryId", "checksum") WHERE ("libraryId" IS NOT NULL AND "checksum" IS NOT NULL)'],
  ])('rejects an unexpected %s without pruning history', async (_case, definition) => {
    await seedForkHistory();
    const history = await sut.getMigrations();
    await sql`DROP INDEX "asset_ownerId_libraryId_checksum_idx"`.execute(db);
    await sql`
      CREATE UNIQUE INDEX "asset_ownerId_libraryId_checksum_idx" ON "asset" ${sql.raw(definition)}
    `.execute(db);
    const index = await getIndex();

    await expect(sut.runMigrations()).rejects.toThrow('Missing or unexpected external library checksum index');
    expect(await sut.getMigrations()).toEqual(history);
    expect(await getIndex()).toEqual(index);
  });

  it('keeps the upstream index intact while retiring the old names, including on retry', async () => {
    const upstream = await sut.getMigrations();
    const index = await getIndex();
    expect(index.unique).toBe(true);
    await seedForkHistory();

    expect(await sut.runMigrations()).toBe(0);
    expect(await sut.runMigrations()).toBe(0);
    expect(await sut.getMigrations()).toEqual(upstream);
    expect(await getIndex()).toEqual(index);
  });

  it('restores a legacy index without changing asset hashes', async () => {
    const upstream = await sut.getMigrations();
    await seedForkHistory();
    await useLegacyIndex();
    await seedExternalAssets(false);
    const before = await getChecksums();

    expect(await sut.runMigrations()).toBe(0);
    expect(await getIndex()).toMatchObject({ unique: true });
    expect(await getChecksums()).toEqual(before);
    expect(await sut.getMigrations()).toEqual(upstream);
  });

  it('rolls back history cleanup and pending upstream DDL if unique index creation fails', async () => {
    await seedForkHistory();
    await useLegacyIndex();
    await seedExternalAssets(true);
    await sql`DROP INDEX "asset_ownerId_updateId_idx"`.execute(db);
    await sql`DELETE FROM "kysely_migrations" WHERE "name" = ${lastUpstream}`.execute(db);
    const history = await sut.getMigrations();
    const index = await getIndex();
    const before = await getChecksums();

    await expect(sut.runMigrations()).rejects.toThrow('Cannot restore external library checksum uniqueness');
    expect(await sut.getMigrations()).toEqual(history);
    expect(await getIndex()).toEqual(index);
    expect(await getChecksums()).toEqual(before);
    const { rows } = await sql<{ restored: boolean }>`
      SELECT to_regclass('"asset_ownerId_updateId_idx"') IS NOT NULL AS restored
    `.execute(db);
    expect(rows[0].restored).toBe(false);
  });

  it('releases the migration lock after an upstream SQL failure and can retry', async () => {
    await seedForkHistory();
    // Keep the index, so replaying its upstream migration fails inside PostgreSQL.
    await sql`DELETE FROM "kysely_migrations" WHERE "name" = ${lastUpstream}`.execute(db);
    const history = await sut.getMigrations();
    await expect(sut.runMigrations()).rejects.toThrow();
    expect(await sut.getMigrations()).toEqual(history);
    const { rows } = await sql<{ locked: boolean }>`
      SELECT EXISTS (
        SELECT 1 FROM pg_locks
        WHERE locktype = 'advisory'
          AND database = (SELECT oid FROM pg_database WHERE datname = current_database())
          AND objsubid = 1
          AND classid::bigint = (3853314791062309107::bigint >> 32)
          AND objid::bigint = (3853314791062309107::bigint & 4294967295)
      ) AS locked
    `.execute(db);
    expect(rows[0].locked).toBe(false);

    await sql`DROP INDEX "asset_ownerId_updateId_idx"`.execute(db);
    expect(await sut.runMigrations()).toBe(1);
  });
});
