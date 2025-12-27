import { Hono } from 'hono';
import { z } from 'zod';
import bcrypt from 'bcrypt';
import { db } from '../db';
import { users, friendCodes, friendRequests } from '../db/schema';
import { eq, and, sql } from 'drizzle-orm';
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
  console.log(`[Auth] Generating friend code ${code} for new user ${userId}`);
  try {
    await db.insert(friendCodes).values({
      id: generateId(),
      userId,
      code,
    });
    console.log(`[Auth] Friend code saved successfully`);
  } catch (error) {
    console.error(`[Auth] Error saving friend code:`, error);
  }

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
  let friendCode: string | null = null;
  try {
    let codeRecord = await db.query.friendCodes.findFirst({
      where: eq(friendCodes.userId, user.id),
    });

    // Generate if doesn't exist (for existing users before this update)
    if (!codeRecord) {
      const newCode = generateFriendCode();
      console.log(`[Auth/login] Generating friend code ${newCode} for existing user ${user.id}`);
      await db.insert(friendCodes).values({
        id: generateId(),
        userId: user.id,
        code: newCode,
      });
      friendCode = newCode;
    } else {
      friendCode = codeRecord.code;
    }
  } catch (error) {
    console.error('[Auth/login] Error with friend code:', error);
  }

  return c.json({
    message: 'Login successful',
    token,
    user: { id: user.id, username: user.username, friendCode },
  });
});

// Get current user (protected)
auth.get('/me', authMiddleware, async (c) => {
  const { userId, username } = c.get('user');

  // Get friend code
  let friendCode: string | null = null;
  let pendingRequestCount = 0;
  
  try {
    let codeRecord = await db.query.friendCodes.findFirst({
      where: eq(friendCodes.userId, userId),
    });

    // Generate if doesn't exist (for existing users before this update)
    if (!codeRecord) {
      const newCode = generateFriendCode();
      console.log(`[Auth/me] Generating friend code ${newCode} for user ${userId}`);
      await db.insert(friendCodes).values({
        id: generateId(),
        userId,
        code: newCode,
      });
      friendCode = newCode;
    } else {
      friendCode = codeRecord.code;
    }
  } catch (error) {
    console.error('[Auth/me] Error with friend code:', error);
  }

  try {
    // Count pending friend requests using SQL COUNT for efficiency
    const countResult = await db
      .select({ count: sql<number>`COUNT(*)` })
      .from(friendRequests)
      .where(and(
        eq(friendRequests.toUserId, userId),
        eq(friendRequests.status, 'pending')
      ));
    
    pendingRequestCount = countResult[0]?.count ?? 0;
  } catch (error) {
    console.error('[Auth/me] Error counting pending requests:', error);
  }

  return c.json({ 
    id: userId, 
    username,
    friendCode,
    pendingRequestCount,
  });
});

export default auth;
