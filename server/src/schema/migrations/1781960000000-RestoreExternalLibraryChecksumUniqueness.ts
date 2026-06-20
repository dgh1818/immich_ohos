import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await sql`CREATE EXTENSION IF NOT EXISTS "pgcrypto";`.execute(db);

  await sql`
    WITH duplicate_assets AS (
      SELECT
        "id",
        ROW_NUMBER() OVER (
          PARTITION BY "ownerId", "libraryId", "checksum"
          ORDER BY "createdAt", "id"
        ) AS "rowNumber"
      FROM "asset"
      WHERE "libraryId" IS NOT NULL
    )
    UPDATE "asset"
    SET
      "checksum" = digest('path:' || "asset"."originalPath", 'sha1'),
      "checksumAlgorithm" = 'sha1-path'::asset_checksum_algorithm_enum
    FROM duplicate_assets
    WHERE "asset"."id" = duplicate_assets."id"
      AND duplicate_assets."rowNumber" > 1;
  `.execute(db);

  await sql`DROP INDEX IF EXISTS "asset_ownerId_libraryId_checksum_idx";`.execute(db);
  await sql`
    CREATE UNIQUE INDEX "asset_ownerId_libraryId_checksum_idx"
    ON "asset" ("ownerId", "libraryId", "checksum")
    WHERE ("libraryId" IS NOT NULL);
  `.execute(db);
}

export async function down(db: Kysely<any>): Promise<void> {
  await sql`DROP INDEX IF EXISTS "asset_ownerId_libraryId_checksum_idx";`.execute(db);
  await sql`
    CREATE INDEX "asset_ownerId_libraryId_checksum_idx"
    ON "asset" ("ownerId", "libraryId", "checksum")
    WHERE ("libraryId" IS NOT NULL);
  `.execute(db);
}
