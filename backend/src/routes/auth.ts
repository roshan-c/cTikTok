import { Hono } from 'hono';
import { z } from 'zod';
import bcrypt from 'bcrypt';
import { db } from '../db';
import { users, friendCodes, friendRequests } from '../db/schema';
import { eq } from 'drizzle-orm';
import { generateId } from '../utils/id';
import { generateFriendCode } from '../utils/friendCode';
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

  // Generate friend code for new user
  const code = generateFriendCode();
  await db.insert(friendCodes).values({
    id: generateId(),
    userId,
    code,
  });

  const token = generateToken({ userId, username: username.toLowerCase() });

  return c.json({
    message: 'Account created successfully',
    token,
    user: { id: userId, username: username.toLowerCase(), friendCode: code },
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

  // Get friend code
  let codeRecord = await db.query.friendCodes.findFirst({
    where: eq(friendCodes.userId, user.id),
  });

  // Generate if doesn't exist (for existing users before this update)
  if (!codeRecord) {
    const newCode = generateFriendCode();
    await db.insert(friendCodes).values({
      id: generateId(),
      userId: user.id,
      code: newCode,
    });
    codeRecord = { id: '', userId: user.id, code: newCode, createdAt: new Date() };
  }

  return c.json({
    message: 'Login successful',
    token,
    user: { id: user.id, username: user.username, friendCode: codeRecord.code },
  });
});

// Get current user (protected)
auth.get('/me', authMiddleware, async (c) => {
  const { userId, username } = c.get('user');

  // Get friend code
  let codeRecord = await db.query.friendCodes.findFirst({
    where: eq(friendCodes.userId, userId),
  });

  // Generate if doesn't exist (for existing users before this update)
  if (!codeRecord) {
    const newCode = generateFriendCode();
    await db.insert(friendCodes).values({
      id: generateId(),
      userId,
      code: newCode,
    });
    codeRecord = { id: '', userId, code: newCode, createdAt: new Date() };
  }

  // Count pending friend requests
  const pendingRequests = await db
    .select()
    .from(friendRequests)
    .where(eq(friendRequests.toUserId, userId));
  
  const pendingRequestCount = pendingRequests.filter(r => r.status === 'pending').length;

  return c.json({ 
    id: userId, 
    username,
    friendCode: codeRecord.code,
    pendingRequestCount,
  });
});

export default auth;
