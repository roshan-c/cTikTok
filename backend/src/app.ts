import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { readFile } from 'fs/promises';
import { existsSync } from 'fs';
import { join } from 'path';
import authRoutes from './routes/auth';
import videosRoutes from './routes/videos';
import altstoreRoutes from './routes/altstore';

// Import friends routes with error handling
let friendsRoutes: Hono | null = null;
try {
  const friendsModule = await import('./routes/friends');
  friendsRoutes = friendsModule.default;
  console.log('[App] Friends routes loaded successfully');
} catch (error) {
  console.error('[App] Failed to load friends routes:', error);
}

const app = new Hono();

// Middleware
app.use('*', logger());
app.use('*', cors({
  origin: '*', // In production, restrict this
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
}));

// Serve the installation guide homepage
app.get('/', async (c) => {
  const htmlPath = join('./public', 'index.html');
  
  if (existsSync(htmlPath)) {
    const html = await readFile(htmlPath, 'utf-8');
    return c.html(html);
  }
  
  return c.json({ 
    status: 'ok', 
    name: 'cTikTok API',
    version: '1.0.0',
  });
});

app.get('/health', (c) => c.json({ status: 'healthy' }));

// Routes
app.route('/api/auth', authRoutes);
app.route('/api/videos', videosRoutes);
if (friendsRoutes) {
  app.route('/api/friends', friendsRoutes);
  console.log('[App] Friends routes registered at /api/friends');
} else {
  console.error('[App] Friends routes NOT registered - routes failed to load');
}
app.route('/altstore', altstoreRoutes);

// 404 handler
app.notFound((c) => c.json({ error: 'Not found' }, 404));

// Error handler
app.onError((err, c) => {
  console.error('Unhandled error:', err);
  return c.json({ error: 'Internal server error' }, 500);
});

export default app;
