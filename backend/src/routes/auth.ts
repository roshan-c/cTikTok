import { Hono } from 'hono';
import { z } from 'zod';
import bcrypt from 'bcrypt';
import { db } from '../db';
import { users } from '../db/schema';
import { eq } from 'drizzle-orm';
import { generateId } from '../utils/id';
import { generateToken, authMiddleware } from '../middleware/auth';

const auth = new Hono();

const registerSchema = z.object({
  username: z.string().min(3).max(30).regex(/^[a-zA-Z0-9_]+$/, 'Username can only contain letters, numbers, and underscores'),
  password: z.string().min(6).max(100),
});

const loginSchema = z.object({
  username: z.string(),
  password: z.string(),
});

// Register
auth.post('/register', async (c) => {
  const body = await c.req.json();
  const parsed = registerSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: 'Invalid input', details: parsed.error.flatten() }, 400);
  }

  const { username, password } = parsed.data;

  // Check if user exists
  const existing = await db.query.users.findFirst({
    where: eq(users.username, username.toLowerCase()),
  });

  if (existing) {
    return c.json({ error: 'Username already taken' }, 409);
  }

  // Hash password and create user
  const passwordHash = await bcrypt.hash(password, 10);
  const userId = generateId();

  await db.insert(users).values({
    id: userId,
    username: username.toLowerCase(),
    passwordHash,
  });

  const token = generateToken({ userId, username: username.toLowerCase() });

  return c.json({
    message: 'Account created successfully',
    token,
    user: { id: userId, username: username.toLowerCase() },
  }, 201);
});

// Login
auth.post('/login', async (c) => {
  const body = await c.req.json();
  const parsed = loginSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: 'Invalid input' }, 400);
  }

  const { username, password } = parsed.data;

  const user = await db.query.users.findFirst({
    where: eq(users.username, username.toLowerCase()),
  });

  if (!user) {
    return c.json({ error: 'Invalid username or password' }, 401);
  }

  const validPassword = await bcrypt.compare(password, user.passwordHash);

  if (!validPassword) {
    return c.json({ error: 'Invalid username or password' }, 401);
  }

  const token = generateToken({ userId: user.id, username: user.username });

  return c.json({
    message: 'Login successful',
    token,
    user: { id: user.id, username: user.username },
  });
});

// Get current user (protected)
auth.get('/me', authMiddleware, async (c) => {
  const { userId, username } = c.get('user');
  return c.json({ id: userId, username });
});

export default auth;
