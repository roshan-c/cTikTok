import { Hono } from 'hono';
import { z } from 'zod';
import { createReadStream, existsSync } from 'fs';
import { stat } from 'fs/promises';
import { db } from '../db';
import { videos, users, friendships } from '../db/schema';
import { eq, desc, gt, and, inArray } from 'drizzle-orm';
import { generateVideoId } from '../utils/id';
import { authMiddleware } from '../middleware/auth';
import { config } from '../utils/config';
import { downloadTikTokVideo, isValidTikTokUrl, cleanupTempFile } from '../services/tiktok';
import { transcodeVideo } from '../services/transcoder';
import { processSlideshow, getSlideshowSize } from '../services/slideshow';

const videosRoute = new Hono();

const submitSchema = z.object({
  url: z.string().url(),
  message: z.string().max(30).optional(),
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

  if (!video || video.status !== 'ready' || video.mediaType !== 'video') {
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

// Get slideshow image (public)
videosRoute.get('/:id/image/:index', async (c) => {
  const videoId = c.req.param('id');
  const indexStr = c.req.param('index');
  const index = parseInt(indexStr, 10);

  const video = await db.query.videos.findFirst({
    where: eq(videos.id, videoId),
  });

  if (!video || video.status !== 'ready' || video.mediaType !== 'slideshow') {
    return c.json({ error: 'Slideshow not found or not ready' }, 404);
  }

  if (!video.images) {
    return c.json({ error: 'No images found' }, 404);
  }

  const imagePaths: string[] = JSON.parse(video.images);
  
  if (index < 0 || index >= imagePaths.length) {
    return c.json({ error: 'Image index out of range' }, 404);
  }

  const imagePath = imagePaths[index];
  
  if (!existsSync(imagePath)) {
    return c.json({ error: 'Image file not found' }, 404);
  }

  const stream = createReadStream(imagePath);

  return new Response(stream as unknown as ReadableStream, {
    status: 200,
    headers: {
      'Content-Type': 'image/jpeg',
      'Cache-Control': 'public, max-age=86400',
    },
  });
});

// Get slideshow audio (public)
videosRoute.get('/:id/audio', async (c) => {
  const videoId = c.req.param('id');

  const video = await db.query.videos.findFirst({
    where: eq(videos.id, videoId),
  });

  if (!video || video.status !== 'ready' || video.mediaType !== 'slideshow') {
    return c.json({ error: 'Slideshow not found or not ready' }, 404);
  }

  if (!video.audioPath || !existsSync(video.audioPath)) {
    return c.json({ error: 'Audio not found' }, 404);
  }

  const stats = await stat(video.audioPath);
  const stream = createReadStream(video.audioPath);

  return new Response(stream as unknown as ReadableStream, {
    status: 200,
    headers: {
      'Content-Type': 'audio/mpeg',
      'Content-Length': stats.size.toString(),
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

  const { url, message } = parsed.data;

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
    message: message || null,
    status: 'processing',
    expiresAt,
  });

  // Process video in background
  processContent(videoId, url).catch(console.error);

  return c.json({
    message: 'Video submitted for processing',
    video: { id: videoId, status: 'processing' },
  }, 202);
});

// Background content processing (video or slideshow)
async function processContent(videoId: string, url: string): Promise<void> {
  console.log(`[Process] Starting content ${videoId}`);

  try {
    // Download
    const downloadResult = await downloadTikTokVideo(url);

    if (!downloadResult.success) {
      await db
        .update(videos)
        .set({
          status: 'failed',
          errorMessage: downloadResult.error || 'Download failed',
        })
        .where(eq(videos.id, videoId));
      return;
    }

    // Handle slideshow
    if (downloadResult.mediaType === 'slideshow') {
      if (!downloadResult.imagePaths || downloadResult.imagePaths.length === 0) {
        await db
          .update(videos)
          .set({
            status: 'failed',
            errorMessage: 'No images downloaded',
          })
          .where(eq(videos.id, videoId));
        return;
      }

      const slideshowResult = await processSlideshow(
        downloadResult.imagePaths,
        downloadResult.audioPath,
        videoId
      );

      if (!slideshowResult.success) {
        await db
          .update(videos)
          .set({
            status: 'failed',
            errorMessage: slideshowResult.error || 'Slideshow processing failed',
          })
          .where(eq(videos.id, videoId));
        return;
      }

      // Get total file size
      const fileSizeBytes = await getSlideshowSize(
        downloadResult.imagePaths,
        downloadResult.audioPath
      );

      // Update record for slideshow
      await db
        .update(videos)
        .set({
          status: 'ready',
          mediaType: 'slideshow',
          filePath: downloadResult.imagePaths[0], // First image as reference
          thumbnailPath: slideshowResult.thumbnailPath,
          images: JSON.stringify(downloadResult.imagePaths),
          audioPath: downloadResult.audioPath || null,
          fileSizeBytes,
          tiktokAuthor: downloadResult.author,
          tiktokDescription: downloadResult.description,
        })
        .where(eq(videos.id, videoId));

      console.log(`[Process] Slideshow ${videoId} ready with ${downloadResult.imagePaths.length} images`);
      return;
    }

    // Handle video
    if (!downloadResult.filePath) {
      await db
        .update(videos)
        .set({
          status: 'failed',
          errorMessage: 'No video file downloaded',
        })
        .where(eq(videos.id, videoId));
      return;
    }

    // Transcode video
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
        mediaType: 'video',
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
    console.error(`[Process] Error processing content ${videoId}:`, error);
    await db
      .update(videos)
      .set({
        status: 'failed',
        errorMessage: error instanceof Error ? error.message : 'Unknown error',
      })
      .where(eq(videos.id, videoId));
  }
}

// Get videos (last 24 hours by default, only from friends)
videosRoute.get('/', async (c) => {
  const user = c.get('user');
  const hoursParam = c.req.query('hours');
  const hours = hoursParam ? parseInt(hoursParam) : 24;
  
  const since = new Date();
  since.setHours(since.getHours() - hours);

  // Get list of friend IDs
  const userFriendships = await db
    .select({ friendId: friendships.friendId })
    .from(friendships)
    .where(eq(friendships.userId, user.userId));
  
  const friendIds = userFriendships.map(f => f.friendId);
  
  // Include self and friends
  const allowedSenderIds = [user.userId, ...friendIds];

  // If no friends, only show own videos
  const videoList = await db
    .select({
      id: videos.id,
      senderId: videos.senderId,
      senderUsername: users.username,
      mediaType: videos.mediaType,
      status: videos.status,
      images: videos.images,
      durationSeconds: videos.durationSeconds,
      fileSizeBytes: videos.fileSizeBytes,
      tiktokAuthor: videos.tiktokAuthor,
      tiktokDescription: videos.tiktokDescription,
      message: videos.message,
      createdAt: videos.createdAt,
      expiresAt: videos.expiresAt,
    })
    .from(videos)
    .leftJoin(users, eq(videos.senderId, users.id))
    .where(and(
      eq(videos.status, 'ready'),
      gt(videos.createdAt, since),
      inArray(videos.senderId, allowedSenderIds)
    ))
    .orderBy(desc(videos.createdAt));

  return c.json({
    videos: videoList.map(v => {
      const base = {
        id: v.id,
        senderId: v.senderId,
        senderUsername: v.senderUsername,
        mediaType: v.mediaType,
        status: v.status,
        durationSeconds: v.durationSeconds,
        fileSizeBytes: v.fileSizeBytes,
        tiktokAuthor: v.tiktokAuthor,
        tiktokDescription: v.tiktokDescription,
        message: v.message,
        createdAt: v.createdAt,
        expiresAt: v.expiresAt,
        thumbnailUrl: `/api/videos/${v.id}/thumbnail`,
      };

      if (v.mediaType === 'slideshow' && v.images) {
        const imagePaths: string[] = JSON.parse(v.images);
        return {
          ...base,
          imageCount: imagePaths.length,
          imageUrls: imagePaths.map((_, i) => `/api/videos/${v.id}/image/${i}`),
          audioUrl: `/api/videos/${v.id}/audio`,
        };
      }

      return {
        ...base,
        streamUrl: `/api/videos/${v.id}/stream`,
      };
    }),
  });
});

// Check for new videos since timestamp (only from friends)
videosRoute.get('/check', async (c) => {
  const user = c.get('user');
  const sinceParam = c.req.query('since');
  
  if (!sinceParam) {
    return c.json({ error: 'Missing "since" query parameter' }, 400);
  }

  const since = new Date(sinceParam);
  if (isNaN(since.getTime())) {
    return c.json({ error: 'Invalid timestamp' }, 400);
  }

  // Get list of friend IDs
  const userFriendships = await db
    .select({ friendId: friendships.friendId })
    .from(friendships)
    .where(eq(friendships.userId, user.userId));
  
  const friendIds = userFriendships.map(f => f.friendId);
  const allowedSenderIds = [user.userId, ...friendIds];

  const newVideos = await db
    .select({ id: videos.id })
    .from(videos)
    .where(and(
      eq(videos.status, 'ready'),
      gt(videos.createdAt, since),
      inArray(videos.senderId, allowedSenderIds)
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

  const base = {
    id: video.id,
    senderId: video.senderId,
    senderUsername: sender?.username,
    mediaType: video.mediaType,
    status: video.status,
    durationSeconds: video.durationSeconds,
    fileSizeBytes: video.fileSizeBytes,
    tiktokAuthor: video.tiktokAuthor,
    tiktokDescription: video.tiktokDescription,
    message: video.message,
    createdAt: video.createdAt,
    expiresAt: video.expiresAt,
    thumbnailUrl: `/api/videos/${video.id}/thumbnail`,
  };

  if (video.mediaType === 'slideshow' && video.images) {
    const imagePaths: string[] = JSON.parse(video.images);
    return c.json({
      ...base,
      imageCount: imagePaths.length,
      imageUrls: imagePaths.map((_, i) => `/api/videos/${video.id}/image/${i}`),
      audioUrl: `/api/videos/${video.id}/audio`,
    });
  }

  return c.json({
    ...base,
    streamUrl: `/api/videos/${video.id}/stream`,
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

  const { unlink, rm } = await import('fs/promises');
  const { dirname } = await import('path');

  // Delete files based on media type
  if (video.mediaType === 'slideshow') {
    // Delete slideshow directory
    if (video.images) {
      const imagePaths: string[] = JSON.parse(video.images);
      if (imagePaths.length > 0) {
        const slideshowDir = dirname(imagePaths[0]);
        await rm(slideshowDir, { recursive: true, force: true }).catch(() => {});
      }
    }
  } else {
    // Delete video file
    if (video.filePath && existsSync(video.filePath)) {
      await unlink(video.filePath).catch(() => {});
    }
    if (video.thumbnailPath && existsSync(video.thumbnailPath)) {
      await unlink(video.thumbnailPath).catch(() => {});
    }
  }

  // Delete from database
  await db.delete(videos).where(eq(videos.id, videoId));

  return c.json({ message: 'Video deleted' });
});

export default videosRoute;
