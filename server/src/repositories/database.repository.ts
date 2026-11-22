import { schemaDiff, schemaFromCode, schemaFromDatabase } from '@immich/sql-tools';
import { Injectable } from '@nestjs/common';
import AsyncLock from 'async-lock';
import { Kysely, sql } from 'kysely';
import { FileMigrationProvider, MIGRATION_LOCK_ID, Migrator } from 'kysely/migration';
import { InjectKysely } from 'nestjs-kysely';
import { readdir } from 'node:fs/promises';
import { join, normalize } from 'node:path';
import { diff } from 'semver';
import z from 'zod';
import {
  EXTENSION_NAMES,
  POSTGRES_VERSION_RANGE,
  VECTORCHORD_LIST_SLACK_FACTOR,
  VECTORCHORD_VERSION_RANGE,
  VECTOR_EXTENSIONS,
  VECTOR_INDEX_TABLES,
  VECTOR_VERSION_RANGE,
  serverVersion,
} from 'src/constants.js';
import { GenerateSql } from 'src/decorators.js';
import { ChecksumAlgorithm, DatabaseExtension, DatabaseLock, VectorIndex } from 'src/enum.js';
import { ConfigRepository } from 'src/repositories/config.repository.js';
import { LoggingRepository } from 'src/repositories/logging.repository.js';
import { immich_uuid_v7 } from 'src/schema/functions.js';
// eslint-disable-next-line import-x/no-duplicates
import 'src/schema/index.js'; // make sure all schema definitions are imported for schemaFromCode

// eslint-disable-next-line import-x/no-duplicates
import { DB } from 'src/schema/index.js';
import type { ExtensionVersion, VectorExtension } from 'src/types.js';
import { hashAssetPath } from 'src/utils/checksum.js';
import { vectorIndexQuery } from 'src/utils/database.js';

export let cachedVectorExtension: VectorExtension | undefined;
export async function getVectorExtension(runner: Kysely<DB>): Promise<VectorExtension> {
  if (cachedVectorExtension) {
    return cachedVectorExtension;
  }

  cachedVectorExtension = new ConfigRepository().getEnv().database.vectorExtension;
  if (cachedVectorExtension) {
    return cachedVectorExtension;
  }

  const query = `SELECT name FROM pg_available_extensions WHERE name IN (${VECTOR_EXTENSIONS.map((ext) => `'${ext}'`).join(', ')})`;
  const { rows: availableExtensions } = await sql.raw<{ name: VectorExtension }>(query).execute(runner);
  const extensionNames = new Set(availableExtensions.map((row) => row.name));
  cachedVectorExtension = VECTOR_EXTENSIONS.find((ext) => extensionNames.has(ext));
  if (!cachedVectorExtension) {
    throw new Error(`No vector extension found. Available extensions: ${VECTOR_EXTENSIONS.join(', ')}`);
  }
  return cachedVectorExtension;
}

export const probes: Record<VectorIndex, number> = {
  [VectorIndex.Clip]: 1,
  [VectorIndex.Face]: 1,
};

@Injectable()
export class DatabaseRepository {
  private readonly asyncLock = new AsyncLock();

  constructor(
    @InjectKysely() private db: Kysely<DB>,
    private logger: LoggingRepository,
    private configRepository: ConfigRepository,
  ) {
    this.logger.setContext(DatabaseRepository.name);
  }

  async shutdown() {
    await this.db.destroy();
  }

  getVectorExtension(): Promise<VectorExtension> {
    return getVectorExtension(this.db);
  }

  @GenerateSql({ params: [[DatabaseExtension.Vector]] })
  async getExtensionVersions(extensions: readonly DatabaseExtension[]): Promise<ExtensionVersion[]> {
    const { rows } = await sql<ExtensionVersion>`
      SELECT name, default_version as "availableVersion", installed_version as "installedVersion"
      FROM pg_available_extensions
      WHERE name in (${sql.join(extensions)})
    `.execute(this.db);
    return rows;
  }

  getExtensionVersionRange(extension: VectorExtension): string {
    switch (extension) {
      case DatabaseExtension.VectorChord: {
        return VECTORCHORD_VERSION_RANGE;
      }
      case DatabaseExtension.Vector: {
        return VECTOR_VERSION_RANGE;
      }
      default: {
        throw new Error(`Unsupported vector extension: '${extension}'`);
      }
    }
  }

  @GenerateSql()
  async getPostgresVersion(): Promise<string> {
    const { rows } = await sql<{ server_version: string }>`SHOW server_version`.execute(this.db);
    return rows[0].server_version;
  }

  getPostgresVersionRange(): string {
    return POSTGRES_VERSION_RANGE;
  }

  async createExtension(extension: DatabaseExtension): Promise<void> {
    this.logger.log(`Creating ${EXTENSION_NAMES[extension]} extension`);
    await sql`CREATE EXTENSION IF NOT EXISTS ${sql.raw(extension)} CASCADE`.execute(this.db);
    if (extension !== DatabaseExtension.VectorChord) {
      return;
    }

    const dbName = sql.id(await this.getDatabaseName());
    await sql`ALTER DATABASE ${dbName} SET vchordrq.probes = 1`.execute(this.db);
    await sql`SET vchordrq.probes = 1`.execute(this.db);
  }

  async dropExtension(extension: DatabaseExtension): Promise<void> {
    this.logger.log(`Dropping ${EXTENSION_NAMES[extension]} extension`);
    await sql`DROP EXTENSION IF EXISTS ${sql.raw(extension)}`.execute(this.db);
  }

  async updateVectorExtension(extension: VectorExtension, targetVersion?: string): Promise<void> {
    const [{ availableVersion, installedVersion }] = await this.getExtensionVersions([extension]);
    if (!installedVersion) {
      throw new Error(`${EXTENSION_NAMES[extension]} extension is not installed`);
    }

    if (!availableVersion) {
      throw new Error(`No available version for ${EXTENSION_NAMES[extension]} extension`);
    }
    targetVersion ??= availableVersion;

    if (!diff(installedVersion, targetVersion)) {
      return;
    }

    await Promise.all([
      this.db.schema.dropIndex(VectorIndex.Clip).ifExists().execute(),
      this.db.schema.dropIndex(VectorIndex.Face).ifExists().execute(),
    ]);

    await sql`ALTER EXTENSION ${sql.raw(extension)} UPDATE TO ${sql.lit(targetVersion)}`.execute(this.db);
    await Promise.all([this.reindexVectors(VectorIndex.Clip), this.reindexVectors(VectorIndex.Face)]);
  }

  async prewarm(index: VectorIndex): Promise<void> {
    const vectorExtension = await getVectorExtension(this.db);
    if (vectorExtension !== DatabaseExtension.VectorChord) {
      return;
    }
    this.logger.debug(`Prewarming ${index}`);
    await sql`SELECT vchordrq_prewarm(${index})`.execute(this.db);
  }

  async reindexVectorsIfNeeded(names: VectorIndex[]): Promise<void> {
    const { rows } = await sql<{
      indexdef: string;
      indexname: string;
    }>`SELECT indexdef, indexname FROM pg_indexes WHERE indexname = ANY(ARRAY[${sql.join(names)}])`.execute(this.db);

    const vectorExtension = await getVectorExtension(this.db);

    const promises = [];
    for (const indexName of names) {
      const row = rows.find((index) => index.indexname === indexName);
      const table = VECTOR_INDEX_TABLES[indexName];
      if (!row) {
        promises.push(this.reindexVectors(indexName));
        continue;
      }

      switch (vectorExtension) {
        case DatabaseExtension.Vector: {
          if (!row.indexdef.toLowerCase().includes('using hnsw')) {
            promises.push(this.reindexVectors(indexName));
          }
          break;
        }
        case DatabaseExtension.VectorChord: {
          const matches = row.indexdef.match(/(?<=lists = \[)\d+/g);
          const lists = matches && matches.length > 0 ? Number(matches[0]) : 1;
          promises.push(
            this.getRowCount(table).then((count) => {
              const targetLists = this.targetListCount(count);
              this.logger.log(`targetLists=${targetLists}, current=${lists} for ${indexName} of ${count} rows`);
              if (
                !row.indexdef.toLowerCase().includes('using vchordrq') ||
                // slack factor is to avoid frequent reindexing if the count is borderline
                (lists !== targetLists && lists !== this.targetListCount(count * VECTORCHORD_LIST_SLACK_FACTOR))
              ) {
                probes[indexName] = this.targetProbeCount(targetLists);
                return this.reindexVectors(indexName, { lists: targetLists });
              }
              probes[indexName] = this.targetProbeCount(lists);
            }),
          );
          break;
        }
      }
    }

    if (promises.length > 0) {
      await Promise.all(promises);
    }
  }

  private async reindexVectors(indexName: VectorIndex, { lists }: { lists?: number } = {}): Promise<void> {
    this.logger.log(`Reindexing ${indexName} (This may take a while, do not restart)`);
    const table = VECTOR_INDEX_TABLES[indexName];
    const vectorExtension = await getVectorExtension(this.db);

    const { rows } = await sql<{
      columnName: string;
    }>`SELECT column_name as "columnName" FROM information_schema.columns WHERE table_name = ${table}`.execute(this.db);
    if (rows.length === 0) {
      this.logger.warn(
        `Table ${table} does not exist, skipping reindexing. This is only normal if this is a new Immich instance.`,
      );
      return;
    }
    const dimSize = await this.getDimensionSize(table);
    lists ||= this.targetListCount(await this.getRowCount(table));
    await this.db.transaction().execute(async (tx) => {
      await sql`DROP INDEX IF EXISTS ${sql.raw(indexName)}`.execute(tx);
      if (table === 'smart_search') {
        await sql`ALTER TABLE ${sql.raw(table)} DROP CONSTRAINT IF EXISTS dim_size_constraint`.execute(tx);
      }
      if (rows.every((row) => row.columnName !== 'embedding')) {
        this.logger.warn(`Column 'embedding' does not exist in table '${table}', truncating and adding column.`);
        await sql`TRUNCATE TABLE ${sql.raw(table)}`.execute(tx);
        await sql`ALTER TABLE ${sql.raw(table)} ADD COLUMN embedding real[] NOT NULL`.execute(tx);
      }
      await sql`ALTER TABLE ${sql.raw(table)} ALTER COLUMN embedding SET DATA TYPE real[]`.execute(tx);
      await sql`
        ALTER TABLE ${sql.raw(table)}
        ALTER COLUMN embedding
        SET DATA TYPE vector(${sql.raw(String(dimSize))})
      `.execute(tx);
      await sql.raw(vectorIndexQuery({ vectorExtension, table, indexName, lists })).execute(tx);
    });
    this.logger.log(`Reindexed ${indexName}`);
    void this.vacuum({ table }).catch((error) => this.logger.warn(`Failed to vacuum ${table}: ${error}`));
  }

  async vacuum({ analyze = false, table }: { analyze?: boolean; table?: keyof DB } = {}): Promise<void> {
    try {
      await sql`VACUUM ${sql.raw(analyze ? 'ANALYZE' : '')} ${sql.raw(table ?? '')}`.execute(this.db);
    } catch (error) {
      this.logger.warn(`Failed to vacuum ${table || 'database'}: ${error}`);
      this.logger.warn('If using Docker, consider increasing shm_size for the database.');
    }
  }

  reindex(table: keyof DB, { concurrently = false } = {}): Promise<unknown> {
    return sql`REINDEX TABLE ${sql.raw(concurrently ? 'CONCURRENTLY' : '')} ${sql.raw(table)}`.execute(this.db);
  }

  private async getDatabaseName(): Promise<string> {
    const { rows } = await sql<{ db: string }>`SELECT current_database() as db`.execute(this.db);
    return rows[0].db;
  }

  getMigrations() {
    return this.db.selectFrom('kysely_migrations').select(['name', 'timestamp']).orderBy('name', 'asc').execute();
  }

  async getSchemaDrift() {
    const source = schemaFromCode({
      overrides: true,
      namingStrategy: 'default',
      uuidFunction: (version) => (version === 7 ? `${immich_uuid_v7.name}()` : 'uuid_generate_v4()'),
    });
    const { database } = this.configRepository.getEnv();
    const target = await schemaFromDatabase({ connection: database.config });

    const drift = schemaDiff(source, target, {
      tables: { ignoreExtra: true },
      constraints: { ignoreExtra: false },
      indexes: { ignoreExtra: true },
      triggers: { ignoreExtra: true },
      columns: { ignoreExtra: true },
      functions: { ignoreExtra: false },
      parameters: { ignoreExtra: true },
      extensions: { ignoreExtra: true },
      ignorePrefixes: ['futo_backups_'],
    });

    return drift;
  }

  async getDimensionSize(table: string, column = 'embedding'): Promise<number> {
    const { rows } = await sql<{ dimsize: number }>`
      SELECT atttypmod as dimsize
      FROM pg_attribute f
        JOIN pg_class c ON c.oid = f.attrelid
      WHERE c.relkind = 'r'::char
        AND f.attnum > 0
        AND c.relname = ${table}::text
        AND f.attname = ${column}::text
    `.execute(this.db);

    const dimSize = rows[0]?.dimsize;
    if (
      !z
        .int()
        .min(1)
        .max(2 ** 16)
        .safeParse(dimSize).success
    ) {
      this.logger.warn(`Could not retrieve dimension size of column '${column}' in table '${table}', assuming 512`);
      return 512;
    }
    return dimSize;
  }

  async setDimensionSize(dimSize: number): Promise<void> {
    if (
      !z
        .int()
        .min(1)
        .max(2 ** 16)
        .safeParse(dimSize).success
    ) {
      throw new Error(`Invalid CLIP dimension size: ${dimSize}`);
    }

    // this is done in two transactions to handle concurrent writes
    await this.db.transaction().execute(async (trx) => {
      await sql`delete from ${sql.table('smart_search')}`.execute(trx);
      await trx.schema.alterTable('smart_search').dropConstraint('dim_size_constraint').ifExists().execute();
      await sql`alter table ${sql.table('smart_search')} add constraint dim_size_constraint check (array_length(embedding::real[], 1) = ${sql.lit(dimSize)})`.execute(
        trx,
      );
    });

    const vectorExtension = await this.getVectorExtension();
    await this.db.transaction().execute(async (trx) => {
      await sql`drop index if exists clip_index`.execute(trx);
      await trx.schema
        .alterTable('smart_search')
        .alterColumn('embedding', (col) => col.setDataType(sql.raw(`vector(${dimSize})`)))
        .execute();
      await sql
        .raw(vectorIndexQuery({ vectorExtension, table: 'smart_search', indexName: VectorIndex.Clip }))
        .execute(trx);
      await trx.schema.alterTable('smart_search').dropConstraint('dim_size_constraint').ifExists().execute();
    });
    probes[VectorIndex.Clip] = 1;

    await sql`vacuum analyze ${sql.table('smart_search')}`.execute(this.db);
  }

  async deleteAllSearchEmbeddings(): Promise<void> {
    await sql`truncate ${sql.table('smart_search')}`.execute(this.db);
  }

  private targetListCount(count: number) {
    if (count < 128_000) {
      return 1;
    }

    return count < 2_048_000 ? 1 << (32 - Math.clz32(count / 1000)) : 1 << (33 - Math.clz32(Math.sqrt(count)));
  }

  private targetProbeCount(lists: number) {
    return Math.ceil(lists / 8);
  }

  private async getRowCount(table: keyof DB): Promise<number> {
    const { count } = await this.db
      .selectFrom(this.db.dynamic.table(table).as('t'))
      .select((eb) => eb.fn.countAll<number>().as('count'))
      .executeTakeFirstOrThrow();
    return count;
  }

  async runMigrations(): Promise<number> {
    this.logger.log('Running migrations');

    const results = await this.db.connection().execute(async (connection) => {
      const adapter = connection.getExecutor().adapter;
      const lockOptions = { lockTable: 'kysely_migrations_lock', lockRowId: MIGRATION_LOCK_ID };
      // Hold the same lock as upstream until this outer transaction commits.
      await adapter.acquireMigrationLock(connection, lockOptions);
      try {
        return await connection.transaction().execute(async (tx) => {
          await sql`
            DO $$
            BEGIN
              IF to_regclass('kysely_migrations') IS NOT NULL THEN
                DELETE FROM "kysely_migrations"
                WHERE "name" IN (
                  '1781748259837-AllowDuplicateExternalLibraryChecksums',
                  '1781960000000-RestoreExternalLibraryChecksumUniqueness'
                );
              END IF;
            END $$;
          `.execute(tx);

          const { error, results = [] } = await this.createMigrator(tx).migrateToLatest();
          if (error) {
            const missing =
              error instanceof Error ? error.message.match(/previously executed migration (.+) is missing/u) : null;
            if (missing) {
              throw new Error(
                `Migration "${missing[1]}" was already applied to this database but is not in this version of Immich (${serverVersion}). ` +
                  `This usually means the database was migrated by a newer version. Downgrades are not supported.`,
                { cause: error },
              );
            }

            throw error;
          }

          await this.restoreExternalLibraryChecksumIndex(tx);
          return results;
        });
      } finally {
        await adapter.releaseMigrationLock(connection, lockOptions);
        // Kysely 0.29.7 also takes this session lock inside the supplied transaction.
        // If its transaction aborts, the inner unlock SQL can fail with 25P02.
        // Release only that leftover lock on this pinned connection.
        await sql`
          SELECT pg_advisory_unlock(3853314791062309107::bigint)
          FROM pg_locks
          WHERE locktype = 'advisory' AND pid = pg_backend_pid() AND granted
            AND objsubid = 1
            AND classid::bigint = (3853314791062309107::bigint >> 32)
            AND objid::bigint = (3853314791062309107::bigint & 4294967295)
        `.execute(connection);
      }
    });

    for (const result of results) {
      this.logger.log(`Migration "${result.migrationName}" succeeded`);
    }

    this.logger.log('Finished running migrations');
    return results.length;
  }

  private async restoreExternalLibraryChecksumIndex(tx: Kysely<DB>): Promise<void> {
    await sql`
      DO $$
      DECLARE
        index_is_unique boolean;
        index_schema name;
      BEGIN
        SET LOCAL lock_timeout = '5s';
        LOCK TABLE "asset" IN ACCESS SHARE MODE;
        SELECT i.indisunique, ns.nspname INTO STRICT index_is_unique, index_schema
        FROM pg_index i
        JOIN pg_class idx ON idx.oid = i.indexrelid
        JOIN pg_class tbl ON tbl.oid = i.indrelid AND tbl.relnamespace = idx.relnamespace
        JOIN pg_namespace ns ON ns.oid = idx.relnamespace
        JOIN pg_am am ON am.oid = idx.relam
        JOIN pg_attribute owner_col ON owner_col.attrelid = i.indrelid AND owner_col.attnum = i.indkey[0]
        JOIN pg_attribute library_col ON library_col.attrelid = i.indrelid AND library_col.attnum = i.indkey[1]
        JOIN pg_attribute checksum_col ON checksum_col.attrelid = i.indrelid AND checksum_col.attnum = i.indkey[2]
        JOIN pg_opclass uuid_ops ON uuid_ops.oid = i.indclass[0] AND uuid_ops.oid = i.indclass[1]
        JOIN pg_opclass bytea_ops ON bytea_ops.oid = i.indclass[2]
        WHERE tbl.oid = to_regclass('asset')
          AND idx.relname = 'asset_ownerId_libraryId_checksum_idx'
          AND am.amname = 'btree'
          AND i.indisvalid AND i.indisready AND i.indislive AND i.indimmediate
          AND NOT i.indisexclusion AND i.indexprs IS NULL
          AND i.indnkeyatts = 3 AND i.indnatts = 3
          AND owner_col.attname = 'ownerId' AND NOT owner_col.attisdropped
          AND library_col.attname = 'libraryId' AND NOT library_col.attisdropped
          AND checksum_col.attname = 'checksum' AND NOT checksum_col.attisdropped
          AND uuid_ops.opcname = 'uuid_ops' AND uuid_ops.opcmethod = am.oid
          AND uuid_ops.opcnamespace = 'pg_catalog'::regnamespace
          AND bytea_ops.opcname = 'bytea_ops' AND bytea_ops.opcmethod = am.oid
          AND bytea_ops.opcnamespace = 'pg_catalog'::regnamespace
          AND i.indcollation[0] = 0 AND i.indcollation[1] = 0 AND i.indcollation[2] = 0
          AND i.indoption[0] = 0 AND i.indoption[1] = 0 AND i.indoption[2] = 0
          -- PostgreSQL 14 has no indnullsnotdistinct column.
          AND NOT COALESCE((to_jsonb(i)->>'indnullsnotdistinct')::boolean, false)
          -- The predicate contains only a mixed-case identifier, always quoted.
          AND pg_get_expr(i.indpred, i.indrelid, false) = '("libraryId" IS NOT NULL)';

        IF NOT index_is_unique THEN
          -- Hold the write lock from validation through the replacement. CREATE
          -- UNIQUE INDEX validates the data itself and aborts on any collision.
          LOCK TABLE "asset" IN ACCESS EXCLUSIVE MODE;
          CREATE UNIQUE INDEX "asset_ownerId_libraryId_checksum_compat_idx"
            ON "asset" ("ownerId", "libraryId", "checksum")
            WHERE ("libraryId" IS NOT NULL);
          EXECUTE format('DROP INDEX %I.%I', index_schema, 'asset_ownerId_libraryId_checksum_idx');
          EXECUTE format('ALTER INDEX %I.%I RENAME TO %I',
            index_schema, 'asset_ownerId_libraryId_checksum_compat_idx', 'asset_ownerId_libraryId_checksum_idx');
        END IF;
      EXCEPTION
        WHEN no_data_found THEN
          RAISE EXCEPTION 'Missing or unexpected external library checksum index: asset_ownerId_libraryId_checksum_idx';
        WHEN unique_violation THEN
          RAISE EXCEPTION 'Cannot restore external library checksum uniqueness: %', SQLERRM
            USING ERRCODE = 'unique_violation', DETAIL = 'Conflicting asset checksums were left unchanged.';
      END $$;
    `.execute(tx);
  }

  async migrateFilePaths(sourceFolder: string, targetFolder: string): Promise<void> {
    targetFolder = normalize(targetFolder);

    // remove trailing slashes
    if (sourceFolder.endsWith('/')) {
      sourceFolder = sourceFolder.slice(0, -1);
    }

    if (targetFolder.endsWith('/')) {
      targetFolder = targetFolder.slice(0, -1);
    }

    // escaping regex special characters with a backslash
    const sourceRegex = '^' + sourceFolder.replaceAll(/[-[\]{}()*+?.,\\^$|#\s]/g, String.raw`\$&`);
    const source = sql.lit(sourceRegex);
    const target = sql.lit(targetFolder);
    const remappedAssetPath = sql<string>`REGEXP_REPLACE("originalPath", ${source}, ${target})`;

    await this.db.transaction().execute(async (tx) => {
      // Keep path selection stable against imports and other path writes until all tables are updated.
      await sql`SET LOCAL lock_timeout = '5s'`.execute(tx);
      await sql`LOCK TABLE asset, asset_file, person, "user" IN SHARE ROW EXCLUSIVE MODE`.execute(tx);
      const {
        rows: [collision],
      } = await sql<{ exists: boolean }>`
        WITH moved AS (
          SELECT id, "libraryId", ${remappedAssetPath} AS path
          FROM asset
          WHERE "isExternal" AND "libraryId" IS NOT NULL
            AND "originalPath" ~ ${sourceRegex} AND "originalPath" <> ${remappedAssetPath}
        )
        SELECT EXISTS (
          SELECT 1 FROM moved GROUP BY "libraryId", path HAVING COUNT(*) > 1
          UNION ALL
          SELECT 1 FROM moved
          JOIN asset ON asset."libraryId" = moved."libraryId" AND asset."originalPath" = moved.path
          WHERE asset."isExternal" AND asset.id <> moved.id
            AND NOT EXISTS (SELECT 1 FROM moved AS other WHERE other.id = asset.id)
        )
      `.execute(tx);
      if (collision.exists) {
        throw new Error('Cannot migrate file paths: multiple external assets would share a path in the same library');
      }

      let afterId: string | undefined;
      while (true) {
        const assets = await tx
          .selectFrom('asset')
          .select(['id', remappedAssetPath.as('path')])
          .where('isExternal', '=', true)
          .where('checksumAlgorithm', '=', ChecksumAlgorithm.sha1Path)
          .where('originalPath', '~', sourceRegex)
          .$if(afterId !== undefined, (query) => query.where('id', '>', afterId!))
          .orderBy('id')
          .limit(1000)
          .execute();
        if (assets.length === 0) {
          break;
        }

        const values = assets.map(({ id, path }) => sql`(${id}::uuid, ${path}::text, ${hashAssetPath(path)}::bytea)`);
        await sql`
          UPDATE asset SET "originalPath" = input.path, checksum = input.checksum
          FROM (VALUES ${sql.join(values)}) AS input(id, path, checksum)
          WHERE asset.id = input.id
        `.execute(tx);
        afterId = assets.at(-1)!.id;
      }

      await tx
        .updateTable('asset')
        .set({ originalPath: remappedAssetPath })
        .where((eb) => eb.or([eb('isExternal', '=', false), eb('checksumAlgorithm', '!=', ChecksumAlgorithm.sha1Path)]))
        .execute();

      await tx
        .updateTable('asset_file')
        .set((eb) => ({ path: eb.fn('REGEXP_REPLACE', ['path', source, target]) }))
        .execute();

      await tx
        .updateTable('person')
        .set((eb) => ({ thumbnailPath: eb.fn('REGEXP_REPLACE', ['thumbnailPath', source, target]) }))
        .execute();

      await tx
        .updateTable('user')
        .set((eb) => ({ profileImagePath: eb.fn('REGEXP_REPLACE', ['profileImagePath', source, target]) }))
        .execute();
    });
  }

  async withLock<R>(lock: DatabaseLock, callback: () => Promise<R>): Promise<R> {
    let res;
    await this.asyncLock.acquire(DatabaseLock[lock], async () => {
      await this.db.connection().execute(async (connection) => {
        try {
          await this.acquireLock(lock, connection);
          res = await callback();
        } finally {
          await this.releaseLock(lock, connection);
        }
      });
    });

    return res as R;
  }

  tryLock(lock: DatabaseLock): Promise<boolean> {
    return this.db.connection().execute(async (connection) => this.acquireTryLock(lock, connection));
  }

  isBusy(lock: DatabaseLock): boolean {
    return this.asyncLock.isBusy(DatabaseLock[lock]);
  }

  async wait(lock: DatabaseLock): Promise<void> {
    await this.asyncLock.acquire(DatabaseLock[lock], () => {});
  }

  private async acquireLock(lock: DatabaseLock, connection: Kysely<DB>): Promise<void> {
    await sql`SELECT pg_advisory_lock(${lock})`.execute(connection);
  }

  private async acquireTryLock(lock: DatabaseLock, connection: Kysely<DB>): Promise<boolean> {
    const { rows } = await sql<{
      pg_try_advisory_lock: boolean;
    }>`SELECT pg_try_advisory_lock(${lock})`.execute(connection);
    return rows[0].pg_try_advisory_lock;
  }

  private async releaseLock(lock: DatabaseLock, connection: Kysely<DB>): Promise<void> {
    await sql`SELECT pg_advisory_unlock(${lock})`.execute(connection);
  }

  private createMigrator(db: Kysely<DB>): Migrator {
    return new Migrator({
      db,
      migrationLockTableName: 'kysely_migrations_lock',
      allowUnorderedMigrations: this.configRepository.isDev(),
      migrationTableName: 'kysely_migrations',
      provider: new FileMigrationProvider({
        fs: { readdir },
        path: { join },
        import: (filePath) => import(filePath),
        migrationFolder: join(import.meta.dirname, '..', 'schema/migrations'),
      }),
    });
  }
}
