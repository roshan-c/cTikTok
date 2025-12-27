import { Hono } from 'hono';
import { eq, and, or } from 'drizzle-orm';
import { db } from '../db';
import { users, friendCodes, friendRequests, friendships } from '../db/schema';
import { authMiddleware } from '../middleware/auth';
import { generateId } from '../utils/id';
import { generateFriendCode } from '../utils/friendCode';

const friends = new Hono();

// All routes require authentication
friends.use('*', authMiddleware);

// Get all friends
friends.get('/', async (c) => {
  const user = c.get('user');

  const userFriendships = await db
    .select({
      id: friendships.id,
      friendId: friendships.friendId,
      username: users.username,
      createdAt: friendships.createdAt,
    })
    .from(friendships)
    .innerJoin(users, eq(friendships.friendId, users.id))
    .where(eq(friendships.userId, user.userId));

  const friendsList = userFriendships.map((f) => ({
    id: f.friendId,
    username: f.username,
    createdAt: f.createdAt,
  }));

  return c.json({ friends: friendsList });
});

// Get incoming friend requests
friends.get('/requests', async (c) => {
  const user = c.get('user');

  const requests = await db
    .select({
      id: friendRequests.id,
      fromUserId: friendRequests.fromUserId,
      fromUsername: users.username,
      status: friendRequests.status,
      createdAt: friendRequests.createdAt,
    })
    .from(friendRequests)
    .innerJoin(users, eq(friendRequests.fromUserId, users.id))
    .where(
      and(
        eq(friendRequests.toUserId, user.userId),
        eq(friendRequests.status, 'pending')
      )
    );

  const requestsList = requests.map((r) => ({
    id: r.id,
    fromUser: {
      id: r.fromUserId,
      username: r.fromUsername,
    },
    status: r.status,
    createdAt: r.createdAt,
  }));

  return c.json({ requests: requestsList });
});

// Get outgoing friend requests
friends.get('/requests/outgoing', async (c) => {
  const user = c.get('user');

  const requests = await db
    .select({
      id: friendRequests.id,
      toUserId: friendRequests.toUserId,
      toUsername: users.username,
      status: friendRequests.status,
      createdAt: friendRequests.createdAt,
    })
    .from(friendRequests)
    .innerJoin(users, eq(friendRequests.toUserId, users.id))
    .where(
      and(
        eq(friendRequests.fromUserId, user.userId),
        eq(friendRequests.status, 'pending')
      )
    );

  const requestsList = requests.map((r) => ({
    id: r.id,
    toUser: {
      id: r.toUserId,
      username: r.toUsername,
    },
    status: r.status,
    createdAt: r.createdAt,
  }));

  return c.json({ requests: requestsList });
});

// Send friend request by code
friends.post('/request', async (c) => {
  const user = c.get('user');
  const { code } = await c.req.json<{ code: string }>();

  if (!code || typeof code !== 'string') {
    return c.json({ error: 'Friend code is required' }, 400);
  }

  const normalizedCode = code.toUpperCase().trim();

  // Find user by friend code
  const friendCodeRecord = await db
    .select()
    .from(friendCodes)
    .where(eq(friendCodes.code, normalizedCode))
    .get();

  if (!friendCodeRecord) {
    return c.json({ error: 'Invalid friend code' }, 404);
  }

  const targetUserId = friendCodeRecord.userId;

  // Can't add yourself
  if (targetUserId === user.userId) {
    return c.json({ error: 'You cannot add yourself as a friend' }, 400);
  }

  // Check if already friends
  const existingFriendship = await db
    .select()
    .from(friendships)
    .where(
      and(
        eq(friendships.userId, user.userId),
        eq(friendships.friendId, targetUserId)
      )
    )
    .get();

  if (existingFriendship) {
    return c.json({ error: 'You are already friends with this user' }, 400);
  }

  // Check for existing pending request (either direction)
  const existingRequest = await db
    .select()
    .from(friendRequests)
    .where(
      and(
        or(
          and(
            eq(friendRequests.fromUserId, user.userId),
            eq(friendRequests.toUserId, targetUserId)
          ),
          and(
            eq(friendRequests.fromUserId, targetUserId),
            eq(friendRequests.toUserId, user.userId)
          )
        ),
        eq(friendRequests.status, 'pending')
      )
    )
    .get();

  if (existingRequest) {
    // If they already sent us a request, auto-accept it
    if (existingRequest.fromUserId === targetUserId) {
      // Accept their request
      await db
        .update(friendRequests)
        .set({ status: 'accepted' })
        .where(eq(friendRequests.id, existingRequest.id));

      // Create bilateral friendships
      await db.insert(friendships).values([
        { id: generateId(), userId: user.userId, friendId: targetUserId },
        { id: generateId(), userId: targetUserId, friendId: user.userId },
      ]);

      // Get target user info
      const targetUser = await db
        .select()
        .from(users)
        .where(eq(users.id, targetUserId))
        .get();

      return c.json({
        message: 'Friend request accepted! You are now friends.',
        friend: {
          id: targetUserId,
          username: targetUser?.username,
        },
      });
    }

    return c.json({ error: 'Friend request already pending' }, 400);
  }

  // Create new friend request
  await db.insert(friendRequests).values({
    id: generateId(),
    fromUserId: user.userId,
    toUserId: targetUserId,
  });

  // Get target user info
  const targetUser = await db
    .select()
    .from(users)
    .where(eq(users.id, targetUserId))
    .get();

  return c.json({
    message: 'Friend request sent',
    toUser: {
      id: targetUserId,
      username: targetUser?.username,
    },
  });
});

// Accept friend request
friends.post('/requests/:id/accept', async (c) => {
  const user = c.get('user');
  const requestId = c.req.param('id');

  const request = await db
    .select()
    .from(friendRequests)
    .where(
      and(
        eq(friendRequests.id, requestId),
        eq(friendRequests.toUserId, user.userId),
        eq(friendRequests.status, 'pending')
      )
    )
    .get();

  if (!request) {
    return c.json({ error: 'Friend request not found' }, 404);
  }

  // Update request status
  await db
    .update(friendRequests)
    .set({ status: 'accepted' })
    .where(eq(friendRequests.id, requestId));

  // Create bilateral friendships
  await db.insert(friendships).values([
    { id: generateId(), userId: user.userId, friendId: request.fromUserId },
    { id: generateId(), userId: request.fromUserId, friendId: user.userId },
  ]);

  // Get friend info
  const friend = await db
    .select()
    .from(users)
    .where(eq(users.id, request.fromUserId))
    .get();

  return c.json({
    message: 'Friend request accepted',
    friend: {
      id: request.fromUserId,
      username: friend?.username,
    },
  });
});

// Reject friend request
friends.post('/requests/:id/reject', async (c) => {
  const user = c.get('user');
  const requestId = c.req.param('id');

  const request = await db
    .select()
    .from(friendRequests)
    .where(
      and(
        eq(friendRequests.id, requestId),
        eq(friendRequests.toUserId, user.userId),
        eq(friendRequests.status, 'pending')
      )
    )
    .get();

  if (!request) {
    return c.json({ error: 'Friend request not found' }, 404);
  }

  // Update request status
  await db
    .update(friendRequests)
    .set({ status: 'rejected' })
    .where(eq(friendRequests.id, requestId));

  return c.json({ message: 'Friend request rejected' });
});

// Remove friend
friends.delete('/:friendId', async (c) => {
  const user = c.get('user');
  const friendId = c.req.param('friendId');

  // Check if friendship exists
  const friendship = await db
    .select()
    .from(friendships)
    .where(
      and(
        eq(friendships.userId, user.userId),
        eq(friendships.friendId, friendId)
      )
    )
    .get();

  if (!friendship) {
    return c.json({ error: 'Friendship not found' }, 404);
  }

  // Delete both directions of friendship
  await db
    .delete(friendships)
    .where(
      or(
        and(
          eq(friendships.userId, user.userId),
          eq(friendships.friendId, friendId)
        ),
        and(
          eq(friendships.userId, friendId),
          eq(friendships.friendId, user.userId)
        )
      )
    );

  return c.json({ message: 'Friend removed' });
});

// Get my friend code
friends.get('/code', async (c) => {
  const user = c.get('user');

  let codeRecord = await db
    .select()
    .from(friendCodes)
    .where(eq(friendCodes.userId, user.userId))
    .get();

  // Generate one if it doesn't exist
  if (!codeRecord) {
    const newCode = generateFriendCode();
    await db.insert(friendCodes).values({
      id: generateId(),
      userId: user.userId,
      code: newCode,
    });
    codeRecord = { id: '', userId: user.userId, code: newCode, createdAt: new Date() };
  }

  return c.json({ code: codeRecord.code });
});

// Regenerate friend code
friends.post('/code/regenerate', async (c) => {
  const user = c.get('user');

  // Delete existing code
  await db.delete(friendCodes).where(eq(friendCodes.userId, user.userId));

  // Generate new code
  const newCode = generateFriendCode();
  await db.insert(friendCodes).values({
    id: generateId(),
    userId: user.userId,
    code: newCode,
  });

  return c.json({ code: newCode });
});

export default friends;
