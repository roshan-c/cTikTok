import { mkdirSync } from 'fs';
import app from './app';
import { config } from './utils/config';
import { startCleanupScheduler } from './services/cleanup';

// Ensure directories exist
mkdirSync(config.VIDEOS_PATH, { recursive: true });
mkdirSync('./data', { recursive: true });

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
