import { Database } from 'bun:sqlite';
import { drizzle } from 'drizzle-orm/bun-sqlite';
import * as schema from './schema';
import { config } from '../utils/config';

// Ensure data directory exists
import { mkdirSync } from 'fs';
import { dirname } from 'path';

mkdirSync(dirname(config.DATABASE_PATH), { recursive: true });

const sqlite = new Database(config.DATABASE_PATH);
sqlite.exec('PRAGMA journal_mode = WAL;');

export const db = drizzle(sqlite, { schema });
