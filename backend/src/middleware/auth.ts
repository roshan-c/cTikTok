import { Context, Next } from 'hono';
import jwt from 'jsonwebtoken';
import { config } from '../utils/config';

export interface JWTPayload {
  userId: string;
  username: string;
}

declare module 'hono' {
  interface ContextVariableMap {
    user: JWTPayload;
  }
}

export async function authMiddleware(c: Context, next: Next) {
  const authHeader = c.req.header('Authorization');
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return c.json({ error: 'Missing or invalid authorization header' }, 401);
  }

  const token = authHeader.substring(7);

  try {
    const payload = jwt.verify(token, config.JWT_SECRET) as JWTPayload;
    c.set('user', payload);
    await next();
  } catch (error) {
    return c.json({ error: 'Invalid or expired token' }, 401);
  }
}

export function generateToken(payload: JWTPayload): string {
  return jwt.sign(payload, config.JWT_SECRET, { expiresIn: '30d' });
}
