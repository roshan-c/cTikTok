import { lt } from 'drizzle-orm';
import { unlink } from 'fs/promises';
import { db } from '../db';
import { videos } from '../db/schema';

export async function cleanupExpiredVideos(): Promise<number> {
  console.log('[Cleanup] Checking for expired videos...');
  
  const expired = await db
    .select()
    .from(videos)
    .where(lt(videos.expiresAt, new Date()));

  if (expired.length === 0) {
    console.log('[Cleanup] No expired videos found');
    return 0;
  }

  console.log(`[Cleanup] Found ${expired.length} expired videos`);

  for (const video of expired) {
    // Delete video file
    if (video.filePath) {
      try {
        await unlink(video.filePath);
        console.log(`[Cleanup] Deleted file: ${video.filePath}`);
      } catch {
        // File may not exist
      }
    }

    // Delete thumbnail
    if (video.thumbnailPath) {
      try {
        await unlink(video.thumbnailPath);
      } catch {
        // Thumbnail may not exist
      }
    }
  }

  // Delete from database
  const result = await db
    .delete(videos)
    .where(lt(videos.expiresAt, new Date()));

  console.log(`[Cleanup] Removed ${expired.length} expired videos from database`);
  return expired.length;
}

// Start cleanup interval (every hour)
export function startCleanupScheduler(): void {
  // Run immediately on start
  cleanupExpiredVideos().catch(console.error);
  
  // Then run every hour
  setInterval(() => {
    cleanupExpiredVideos().catch(console.error);
  }, 60 * 60 * 1000);
  
  console.log('[Cleanup] Scheduler started (runs every hour)');
}
