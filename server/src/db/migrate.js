import 'dotenv/config';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { getPool } from './pool.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const migrationsDir = path.join(__dirname, 'migrations');

async function migrate() {
  const pool = getPool();

  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      filename TEXT PRIMARY KEY,
      executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  const files = fs
    .readdirSync(migrationsDir)
    .filter(file => file.endsWith('.sql'))
    .sort();

  for (const file of files) {
    const exists = await pool.query(
      'SELECT 1 FROM schema_migrations WHERE filename = $1',
      [file],
    );

    if (exists.rowCount > 0) {
      console.log(`Skipping ${file}`);
      continue;
    }

    console.log(`Running ${file}`);

    const sql = fs.readFileSync(
      path.join(migrationsDir, file),
      'utf8',
    );

    await pool.query(sql);

    await pool.query(
      'INSERT INTO schema_migrations(filename) VALUES($1)',
      [file],
    );

    console.log(`Completed ${file}`);
  }

  console.log('All migrations complete.');

  await pool.end();
}

migrate().catch(err => {
  console.error(err);
  process.exit(1);
});