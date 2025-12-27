import { mkdirSync } from 'fs';
import { Database } from 'bun:sqlite';
import { config } from './utils/config';
import { startCleanupScheduler } from './services/cleanup';

console.log('[Startup] Beginning server initialization v4...');

// Ensure directories exist
mkdirSync(config.VIDEOS_PATH, { recursive: true });
mkdirSync('./data', { recursive: true });

// Verify database tables exist
function checkDatabaseTables() {
  try {
    const sqlite = new Database(config.DATABASE_PATH, { readonly: true });
    const tables = sqlite.query("SELECT name FROM sqlite_master WHERE type='table'").all() as { name: string }[];
    const tableNames = tables.map((t) => t.name);
    console.log('[DB] Tables found:', tableNames.join(', '));
    
    const requiredTables = ['users', 'videos', 'friend_codes', 'friend_requests', 'friendships'];
    const missingTables = requiredTables.filter(t => !tableNames.includes(t));
    
    if (missingTables.length > 0) {
      console.error('[DB] WARNING: Missing tables:', missingTables.join(', '));
      console.error('[DB] Please run migrations: bun run db:migrate');
    } else {
      console.log('[DB] All required tables present');
    }
    sqlite.close();
  } catch (error) {
    console.error('[DB] Error checking tables:', error);
  }
}

checkDatabaseTables();

console.log('[Startup] Loading app...');
import app from './app';
console.log('[Startup] App loaded');

// Start cleanup scheduler
startCleanupScheduler();

// Start server
console.log(`
  ██████╗████████╗██╗██╗  ██╗████████╗ ██████╗ ██╗  ██╗
 ██╔════╝╚══██╔══╝██║██║ ██╔╝╚══██╔══╝██╔═══██╗██║ ██╔╝
 ██║        ██║   ██║█████╔╝    ██║   ██║   ██║█████╔╝ 
 ██║        ██║   ██║██╔═██╗    ██║   ██║   ██║██╔═██╗ 
 ╚██████╗   ██║   ██║██║  ██╗   ██║   ╚██████╔╝██║  ██╗
  ╚═════╝   ╚═╝   ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝
`);

export default {
  port: config.PORT,
  fetch: app.fetch,
};

console.log(`Server running at http://localhost:${config.PORT}`);
console.log(`Video expiry: ${config.VIDEO_EXPIRY_DAYS} days`);
