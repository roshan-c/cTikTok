import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { readFile } from 'fs/promises';
import { existsSync } from 'fs';
import { join } from 'path';

console.log('[App] Loading routes...');

import authRoutes from './routes/auth';
console.log('[App] Auth routes loaded');

import videosRoutes from './routes/videos';
console.log('[App] Videos routes loaded');

import friendsRoutes from './routes/friends';
console.log('[App] Friends routes loaded');

import altstoreRoutes from './routes/altstore';
console.log('[App] Altstore routes loaded');

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
console.log('[App] Registering routes...');
app.route('/api/auth', authRoutes);
app.route('/api/videos', videosRoutes);
app.route('/api/friends', friendsRoutes);
app.route('/altstore', altstoreRoutes);
console.log('[App] All routes registered');

// 404 handler
app.notFound((c) => c.json({ error: 'Not found' }, 404));

// Error handler
app.onError((err, c) => {
  console.error('Unhandled error:', err);
  return c.json({ error: 'Internal server error' }, 500);
});

export default app;
