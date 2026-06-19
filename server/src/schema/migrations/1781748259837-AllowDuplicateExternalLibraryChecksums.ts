import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await sql`DROP INDEX IF EXISTS "asset_ownerId_libraryId_checksum_idx";`.execute(db);
  await sql`
    CREATE INDEX "asset_ownerId_libraryId_checksum_idx"
    ON "asset" ("ownerId", "libraryId", "checksum")
    WHERE ("libraryId" IS NOT NULL);
  `.execute(db);
}

export async function down(db: Kysely<any>): Promise<void> {
  await sql`DROP INDEX IF EXISTS "asset_ownerId_libraryId_checksum_idx";`.execute(db);
  await sql`
    CREATE UNIQUE INDEX "asset_ownerId_libraryId_checksum_idx"
    ON "asset" ("ownerId", "libraryId", "checksum")
    WHERE ("libraryId" IS NOT NULL);
  `.execute(db);
}
