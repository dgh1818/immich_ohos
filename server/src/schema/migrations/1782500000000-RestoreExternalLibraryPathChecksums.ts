import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await sql`CREATE EXTENSION IF NOT EXISTS "pgcrypto";`.execute(db);

  await sql`
    UPDATE "asset"
    SET
      "checksum" = digest('path:' || "originalPath", 'sha1'),
      "checksumAlgorithm" = 'sha1-path'::asset_checksum_algorithm_enum
    WHERE "isExternal" = true
      AND "libraryId" IS NOT NULL
      AND "checksumAlgorithm" = 'sha1'::asset_checksum_algorithm_enum;
  `.execute(db);
}

export async function down(_db: Kysely<any>): Promise<void> {}
