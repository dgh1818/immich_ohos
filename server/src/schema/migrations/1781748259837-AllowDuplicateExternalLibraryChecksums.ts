import { Kysely, sql } from 'kysely';

// Compatibility marker for releases that already recorded this migration.
// Do not relax the checksum index here; the following restore migration owns the final schema.
export async function up(db: Kysely<any>): Promise<void> {
  await sql`SELECT 1;`.execute(db);
}

export async function down(db: Kysely<any>): Promise<void> {
  await sql`SELECT 1;`.execute(db);
}
