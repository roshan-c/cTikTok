import { sqliteTable, text, integer, index } from 'drizzle-orm/sqlite-core';

// Users table
export const users = sqliteTable('users', {
  id: text('id').primaryKey(),
  username: text('username').unique().notNull(),
  passwordHash: text('password_hash').notNull(),
  createdAt: integer('created_at', { mode: 'timestamp' })
    .notNull()
    .$defaultFn(() => new Date()),
});

// Videos table (also used for slideshows)
export const videos = sqliteTable('videos', {
  id: text('id').primaryKey(),
  senderId: text('sender_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  originalUrl: text('original_url').notNull(),
  mediaType: text('media_type', { enum: ['video', 'slideshow'] })
    .notNull()
    .default('video'),
  filePath: text('file_path').notNull(), // For videos: the mp4 file. For slideshows: empty or first image
  thumbnailPath: text('thumbnail_path'),
  images: text('images'), // JSON array of image paths (for slideshows)
  audioPath: text('audio_path'), // Audio file path (for slideshows)
  durationSeconds: integer('duration_seconds'),
  fileSizeBytes: integer('file_size_bytes'),
  tiktokAuthor: text('tiktok_author'),
  tiktokDescription: text('tiktok_description'),
  message: text('message'), // Short message from sender (max 30 chars)
  status: text('status', { enum: ['processing', 'ready', 'failed'] })
    .notNull()
    .default('processing'),
  errorMessage: text('error_message'),
  createdAt: integer('created_at', { mode: 'timestamp' })
    .notNull()
    .$defaultFn(() => new Date()),
  expiresAt: integer('expires_at', { mode: 'timestamp' }).notNull(),
}, (table) => ({
  senderIdx: index('videos_sender_idx').on(table.senderId),
  statusIdx: index('videos_status_idx').on(table.status),
  createdAtIdx: index('videos_created_at_idx').on(table.createdAt),
  expiresAtIdx: index('videos_expires_at_idx').on(table.expiresAt),
}));

// Device tokens for future push notifications
export const deviceTokens = sqliteTable('device_tokens', {
  id: text('id').primaryKey(),
  userId: text('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  token: text('token').notNull(),
  platform: text('platform').default('ios'),
  createdAt: integer('created_at', { mode: 'timestamp' })
    .notNull()
    .$defaultFn(() => new Date()),
});

// Friend codes for adding friends
export const friendCodes = sqliteTable('friend_codes', {
  id: text('id').primaryKey(),
  userId: text('user_id')
    .notNull()
    .unique()
    .references(() => users.id, { onDelete: 'cascade' }),
  code: text('code').notNull().unique(),
  createdAt: integer('created_at', { mode: 'timestamp' })
    .notNull()
    .$defaultFn(() => new Date()),
});

// Friend requests (pending, accepted, rejected)
export const friendRequests = sqliteTable('friend_requests', {
  id: text('id').primaryKey(),
  fromUserId: text('from_user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  toUserId: text('to_user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  status: text('status', { enum: ['pending', 'accepted', 'rejected'] })
    .notNull()
    .default('pending'),
  createdAt: integer('created_at', { mode: 'timestamp' })
    .notNull()
    .$defaultFn(() => new Date()),
}, (table) => ({
  toUserStatusIdx: index('friend_requests_to_user_status_idx').on(table.toUserId, table.status),
}));

// Friendships (bilateral - stored both ways for easy querying)
export const friendships = sqliteTable('friendships', {
  id: text('id').primaryKey(),
  userId: text('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  friendId: text('friend_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  createdAt: integer('created_at', { mode: 'timestamp' })
    .notNull()
    .$defaultFn(() => new Date()),
}, (table) => ({
  userIdx: index('friendships_user_idx').on(table.userId),
  friendIdx: index('friendships_friend_idx').on(table.friendId),
}));

// Favorites (per-user video favorites)
export const favorites = sqliteTable('favorites', {
  id: text('id').primaryKey(),
  userId: text('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  videoId: text('video_id')
    .notNull()
    .references(() => videos.id, { onDelete: 'cascade' }),
  createdAt: integer('created_at', { mode: 'timestamp' })
    .notNull()
    .$defaultFn(() => new Date()),
}, (table) => ({
  userIdx: index('favorites_user_idx').on(table.userId),
  videoIdx: index('favorites_video_idx').on(table.videoId),
}));

// Type exports
export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
export type Video = typeof videos.$inferSelect;
export type NewVideo = typeof videos.$inferInsert;
export type DeviceToken = typeof deviceTokens.$inferSelect;
export type NewDeviceToken = typeof deviceTokens.$inferInsert;
export type FriendCode = typeof friendCodes.$inferSelect;
export type NewFriendCode = typeof friendCodes.$inferInsert;
export type FriendRequest = typeof friendRequests.$inferSelect;
export type NewFriendRequest = typeof friendRequests.$inferInsert;
export type Friendship = typeof friendships.$inferSelect;
export type NewFriendship = typeof friendships.$inferInsert;
export type Favorite = typeof favorites.$inferSelect;
export type NewFavorite = typeof favorites.$inferInsert;
