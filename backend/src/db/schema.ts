import { sqliteTable, text, integer } from 'drizzle-orm/sqlite-core';

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
});

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

// Type exports
export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
export type Video = typeof videos.$inferSelect;
export type NewVideo = typeof videos.$inferInsert;
export type DeviceToken = typeof deviceTokens.$inferSelect;
export type NewDeviceToken = typeof deviceTokens.$inferInsert;
