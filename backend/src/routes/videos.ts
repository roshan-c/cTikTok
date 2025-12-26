import { Hono } from 'hono';
import { z } from 'zod';
import { createReadStream, existsSync } from 'fs';
import { stat } from 'fs/promises';
import { db } from '../db';
import { videos, users } from '../db/schema';
import { eq, desc, gt, and } from 'drizzle-orm';
import { generateVideoId } from '../utils/id';
import { authMiddleware } from '../middleware/auth';
import { config } from '../utils/config';
import { downloadTikTokVideo, isValidTikTokUrl, cleanupTempFile } from '../services/tiktok';
import { transcodeVideo } from '../services/transcoder';

const videosRoute = new Hono();

const submitSchema = z.object({
  url: z.string().url(),
});

// ============================================
// PUBLIC ROUTES (no auth required)
// ============================================

// Stream video (public - video IDs are unguessable)
videosRoute.get('/:id/stream', async (c) => {
  const videoId = c.req.param('id');

  const video = await db.query.videos.findFirst({
    where: eq(videos.id, videoId),
  });

  if (!video || video.status !== 'ready') {
    return c.json({ error: 'Video not found or not ready' }, 404);
  }

  if (!existsSync(video.filePath)) {
    return c.json({ error: 'Video file not found' }, 404);
  }

  const stats = await stat(video.filePath);
  const range = c.req.header('Range');

  // Handle range requests for seeking
  if (range) {
    const parts = range.replace(/bytes=/, '').split('-');
    const start = parseInt(parts[0], 10);
    const end = parts[1] ? parseInt(parts[1], 10) : stats.size - 1;
    const chunkSize = end - start + 1;

    const stream = createReadStream(video.filePath, { start, end });

    return new Response(stream as unknown as ReadableStream, {
      status: 206,
      headers: {
        'Content-Range': `bytes ${start}-${end}/${stats.size}`,
        'Accept-Ranges': 'bytes',
        'Content-Length': chunkSize.toString(),
        'Content-Type': 'video/mp4',
      },
    });
  }

  // Full file
  const stream = createReadStream(video.filePath);

  return new Response(stream as unknown as ReadableStream, {
    status: 200,
    headers: {
      'Content-Length': stats.size.toString(),
      'Content-Type': 'video/mp4',
      'Accept-Ranges': 'bytes',
    },
  });
});

// Get thumbnail (public)
videosRoute.get('/:id/thumbnail', async (c) => {
  const videoId = c.req.param('id');

  const video = await db.query.videos.findFirst({
    where: eq(videos.id, videoId),
  });

  if (!video || !video.thumbnailPath || !existsSync(video.thumbnailPath)) {
    return c.json({ error: 'Thumbnail not found' }, 404);
  }

  const stream = createReadStream(video.thumbnailPath);

  return new Response(stream as unknown as ReadableStream, {
    status: 200,
    headers: {
      'Content-Type': 'image/jpeg',
      'Cache-Control': 'public, max-age=86400',
    },
  });
});

// ============================================
// PROTECTED ROUTES (auth required)
// ============================================

// Apply auth middleware to all routes below this point
videosRoute.use('*', authMiddleware);

// Submit a new video
videosRoute.post('/', async (c) => {
  const user = c.get('user');
  const body = await c.req.json();
  const parsed = submitSchema.safeParse(body);

  if (!parsed.success) {
    return c.json({ error: 'Invalid input', details: parsed.error.flatten() }, 400);
  }

  const { url } = parsed.data;

  if (!isValidTikTokUrl(url)) {
    return c.json({ error: 'Invalid TikTok URL' }, 400);
  }

  // Create video record with processing status
  const videoId = generateVideoId();
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + config.VIDEO_EXPIRY_DAYS);

  await db.insert(videos).values({
    id: videoId,
    senderId: user.userId,
    originalUrl: url,
    filePath: '', // Will be updated after processing
    status: 'processing',
    expiresAt,
  });

  // Process video in background
  processVideo(videoId, url).catch(console.error);

  return c.json({
    message: 'Video submitted for processing',
    video: { id: videoId, status: 'processing' },
  }, 202);
});

// Background video processing
async function processVideo(videoId: string, url: string): Promise<void> {
  console.log(`[Process] Starting video ${videoId}`);

  try {
    // Download
    const downloadResult = await downloadTikTokVideo(url);

    if (!downloadResult.success || !downloadResult.filePath) {
      await db
        .update(videos)
        .set({
          status: 'failed',
          errorMessage: downloadResult.error || 'Download failed',
        })
        .where(eq(videos.id, videoId));
      return;
    }

    // Transcode
    const transcodeResult = await transcodeVideo(downloadResult.filePath, videoId);

    if (!transcodeResult.success || !transcodeResult.outputPath) {
      await cleanupTempFile(downloadResult.filePath);
      await db
        .update(videos)
        .set({
          status: 'failed',
          errorMessage: transcodeResult.error || 'Transcoding failed',
        })
        .where(eq(videos.id, videoId));
      return;
    }

    // Update video record
    await db
      .update(videos)
      .set({
        status: 'ready',
        filePath: transcodeResult.outputPath,
        thumbnailPath: transcodeResult.thumbnailPath,
        durationSeconds: transcodeResult.durationSeconds,
        fileSizeBytes: transcodeResult.fileSizeBytes,
        tiktokAuthor: downloadResult.author,
        tiktokDescription: downloadResult.description,
      })
      .where(eq(videos.id, videoId));

    console.log(`[Process] Video ${videoId} ready`);
  } catch (error) {
    console.error(`[Process] Error processing video ${videoId}:`, error);
    await db
      .update(videos)
      .set({
        status: 'failed',
        errorMessage: error instanceof Error ? error.message : 'Unknown error',
      })
      .where(eq(videos.id, videoId));
  }
}

// Get videos (last 24 hours by default, or all ready videos)
videosRoute.get('/', async (c) => {
  const hoursParam = c.req.query('hours');
  const hours = hoursParam ? parseInt(hoursParam) : 24;
  
  const since = new Date();
  since.setHours(since.getHours() - hours);

  const videoList = await db
    .select({
      id: videos.id,
      senderId: videos.senderId,
      senderUsername: users.username,
      status: videos.status,
      durationSeconds: videos.durationSeconds,
      fileSizeBytes: videos.fileSizeBytes,
      tiktokAuthor: videos.tiktokAuthor,
      tiktokDescription: videos.tiktokDescription,
      createdAt: videos.createdAt,
      expiresAt: videos.expiresAt,
    })
    .from(videos)
    .leftJoin(users, eq(videos.senderId, users.id))
    .where(and(
      eq(videos.status, 'ready'),
      gt(videos.createdAt, since)
    ))
    .orderBy(desc(videos.createdAt));

  return c.json({
    videos: videoList.map(v => ({
      ...v,
      streamUrl: `/api/videos/${v.id}/stream`,
      thumbnailUrl: `/api/videos/${v.id}/thumbnail`,
    })),
  });
});

// Check for new videos since timestamp
videosRoute.get('/check', async (c) => {
  const sinceParam = c.req.query('since');
  
  if (!sinceParam) {
    return c.json({ error: 'Missing "since" query parameter' }, 400);
  }

  const since = new Date(sinceParam);
  if (isNaN(since.getTime())) {
    return c.json({ error: 'Invalid timestamp' }, 400);
  }

  const newVideos = await db
    .select({ id: videos.id })
    .from(videos)
    .where(and(
      eq(videos.status, 'ready'),
      gt(videos.createdAt, since)
    ));

  return c.json({
    count: newVideos.length,
    hasNew: newVideos.length > 0,
  });
});

// Get single video info
videosRoute.get('/:id', async (c) => {
  const videoId = c.req.param('id');

  const video = await db.query.videos.findFirst({
    where: eq(videos.id, videoId),
  });

  if (!video) {
    return c.json({ error: 'Video not found' }, 404);
  }

  const sender = await db.query.users.findFirst({
    where: eq(users.id, video.senderId),
  });

  return c.json({
    id: video.id,
    senderId: video.senderId,
    senderUsername: sender?.username,
    status: video.status,
    durationSeconds: video.durationSeconds,
    fileSizeBytes: video.fileSizeBytes,
    tiktokAuthor: video.tiktokAuthor,
    tiktokDescription: video.tiktokDescription,
    createdAt: video.createdAt,
    expiresAt: video.expiresAt,
    streamUrl: `/api/videos/${video.id}/stream`,
    thumbnailUrl: `/api/videos/${video.id}/thumbnail`,
  });
});

// Delete video (sender only)
videosRoute.delete('/:id', async (c) => {
  const user = c.get('user');
  const videoId = c.req.param('id');

  const video = await db.query.videos.findFirst({
    where: eq(videos.id, videoId),
  });

  if (!video) {
    return c.json({ error: 'Video not found' }, 404);
  }

  if (video.senderId !== user.userId) {
    return c.json({ error: 'Not authorized to delete this video' }, 403);
  }

  // Delete files
  if (video.filePath && existsSync(video.filePath)) {
    const { unlink } = await import('fs/promises');
    await unlink(video.filePath).catch(() => {});
  }
  if (video.thumbnailPath && existsSync(video.thumbnailPath)) {
    const { unlink } = await import('fs/promises');
    await unlink(video.thumbnailPath).catch(() => {});
  }

  // Delete from database
  await db.delete(videos).where(eq(videos.id, videoId));

  return c.json({ message: 'Video deleted' });
});

export default videosRoute;
