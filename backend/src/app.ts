import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import authRoutes from './routes/auth';
import videosRoutes from './routes/videos';
import altstoreRoutes from './routes/altstore';

const app = new Hono();

// Middleware
app.use('*', logger());
app.use('*', cors({
  origin: '*', // In production, restrict this
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
}));

// Health check
app.get('/', (c) => c.json({ 
  status: 'ok', 
  name: 'cTikTok API',
  version: '1.0.0',
}));

app.get('/health', (c) => c.json({ status: 'healthy' }));

// Routes
app.route('/api/auth', authRoutes);
app.route('/api/videos', videosRoutes);
app.route('/altstore', altstoreRoutes);

// 404 handler
app.notFound((c) => c.json({ error: 'Not found' }, 404));

// Error handler
app.onError((err, c) => {
  console.error('Unhandled error:', err);
  return c.json({ error: 'Internal server error' }, 500);
});

export default app;
