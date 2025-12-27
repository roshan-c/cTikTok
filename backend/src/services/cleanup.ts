import { lt, notInArray, and } from 'drizzle-orm';
import { unlink } from 'fs/promises';
import { db } from '../db';
import { videos, favorites } from '../db/schema';

export async function cleanupExpiredVideos(): Promise<number> {
  console.log('[Cleanup] Checking for expired videos...');
  
  // Get all video IDs that have at least one favorite (these should be kept)
  const favoritedVideoIds = await db
    .selectDistinct({ videoId: favorites.videoId })
    .from(favorites);
  
  const favoritedIds = favoritedVideoIds.map(f => f.videoId);
  
  // Find expired videos that are NOT favorited by anyone
  const expiredCondition = favoritedIds.length > 0
    ? and(lt(videos.expiresAt, new Date()), notInArray(videos.id, favoritedIds))
    : lt(videos.expiresAt, new Date());
  
  const expired = await db
    .select()
    .from(videos)
    .where(expiredCondition);

  if (expired.length === 0) {
    console.log('[Cleanup] No expired videos found');
    return 0;
  }

  console.log(`[Cleanup] Found ${expired.length} expired videos (excluding favorited)`);

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

  // Delete from database (same condition as above)
  await db
    .delete(videos)
    .where(expiredCondition);

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
