import { stat } from 'fs/promises';

export interface SlideshowProcessResult {
  success: boolean;
  imagePaths?: string[];
  audioPath?: string;
  thumbnailPath?: string;
  error?: string;
}

// Process slideshow - images are already downloaded, just need to set thumbnail
export async function processSlideshow(
  imagePaths: string[],
  audioPath: string | undefined,
  videoId: string
): Promise<SlideshowProcessResult> {
  try {
    console.log(`[Slideshow] Processing slideshow ${videoId} with ${imagePaths.length} images`);

    if (imagePaths.length === 0) {
      return { success: false, error: 'No images provided' };
    }

    // Use first image as thumbnail
    const thumbnailPath = imagePaths[0];

    console.log(`[Slideshow] Processing complete for ${videoId}`);

    return {
      success: true,
      imagePaths,
      audioPath,
      thumbnailPath,
    };
  } catch (error) {
    console.error(`[Slideshow] Error processing slideshow ${videoId}:`, error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

// Get total size of slideshow files
export async function getSlideshowSize(imagePaths: string[], audioPath?: string): Promise<number> {
  let totalSize = 0;
  
  for (const imagePath of imagePaths) {
    try {
      const stats = await stat(imagePath);
      totalSize += stats.size;
    } catch {
      // Ignore errors
    }
  }
  
  if (audioPath) {
    try {
      const stats = await stat(audioPath);
      totalSize += stats.size;
    } catch {
      // Ignore errors
    }
  }
  
  return totalSize;
}
