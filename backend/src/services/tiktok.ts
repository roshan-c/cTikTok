// eslint-disable-next-line @typescript-eslint/no-var-requires
const TiktokDL = require('@tobyg74/tiktok-api-dl') as {
  Downloader: (url: string, options?: { version?: string; proxy?: string }) => Promise<{
    status: string;
    message?: string;
    result?: {
      type?: 'video' | 'image' | 'music';
      videoHD?: string;
      video1?: string;
      video?: string;
      images?: string[];
      author?: { nickname?: string; username?: string };
      desc?: string;
      description?: string;
      music?: {
        playUrl?: string[];
      };
    };
  }>;
};
import { spawn } from 'child_process';
import { existsSync } from 'fs';
import { unlink, writeFile, mkdir, rm } from 'fs/promises';
import { join } from 'path';
import { config } from '../utils/config';
import { generateVideoId } from '../utils/id';

export type MediaType = 'video' | 'slideshow';

export interface DownloadResult {
  success: boolean;
  mediaType: MediaType;
  // For videos
  filePath?: string;
  // For slideshows
  imagePaths?: string[];
  audioPath?: string;
  // Common
  author?: string;
  description?: string;
  error?: string;
}

// Validate TikTok URL
export function isValidTikTokUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    return (
      parsed.hostname === 'tiktok.com' ||
      parsed.hostname === 'www.tiktok.com' ||
      parsed.hostname === 'vm.tiktok.com' ||
      parsed.hostname === 'm.tiktok.com'
    );
  } catch {
    return false;
  }
}

// Download a single file from URL
async function downloadFile(url: string, outputPath: string): Promise<boolean> {
  try {
    const response = await fetch(url);
    if (!response.ok) return false;
    
    const buffer = await response.arrayBuffer();
    await writeFile(outputPath, Buffer.from(buffer));
    return true;
  } catch {
    return false;
  }
}

// Download video using @tobyg74/tiktok-api-dl
async function downloadWithLibrary(url: string): Promise<DownloadResult> {
  try {
    // Use v1 as it returns complete data including music for slideshows
    const result = await TiktokDL.Downloader(url, { version: 'v1' });
    
    if (result.status !== 'success' || !result.result) {
      return { success: false, mediaType: 'video', error: result.message || 'Failed to fetch content info' };
    }

    const contentType = result.result.type;
    const author = (result.result as any).author;
    const authorName = author?.nickname || author?.username;
    const description = (result.result as any).desc || (result.result as any).description;

    // Handle slideshow (image type)
    if (contentType === 'image' && result.result.images && result.result.images.length > 0) {
      console.log(`[TikTok] Detected slideshow with ${result.result.images.length} images`);
      
      const slideshowId = generateVideoId();
      const slideshowDir = join(config.VIDEOS_PATH, `slideshow_${slideshowId}`);
      
      // Create directory for slideshow assets
      await mkdir(slideshowDir, { recursive: true });
      
      // Download all images
      const imagePaths: string[] = [];
      for (let i = 0; i < result.result.images.length; i++) {
        const imageUrl = result.result.images[i];
        const imagePath = join(slideshowDir, `image_${i}.jpg`);
        
        console.log(`[TikTok] Downloading image ${i + 1}/${result.result.images.length}`);
        const success = await downloadFile(imageUrl, imagePath);
        
        if (success) {
          imagePaths.push(imagePath);
        } else {
          console.log(`[TikTok] Failed to download image ${i + 1}`);
        }
      }
      
      if (imagePaths.length === 0) {
        return { success: false, mediaType: 'slideshow', error: 'Failed to download any images' };
      }
      
      // Download audio if available
      let audioPath: string | undefined;
      const musicUrl = result.result.music?.playUrl?.[0];
      if (musicUrl) {
        audioPath = join(slideshowDir, 'audio.mp3');
        console.log(`[TikTok] Downloading audio`);
        const audioSuccess = await downloadFile(musicUrl, audioPath);
        if (!audioSuccess) {
          console.log(`[TikTok] Failed to download audio, continuing without it`);
          audioPath = undefined;
        }
      }
      
      return {
        success: true,
        mediaType: 'slideshow',
        imagePaths,
        audioPath,
        author: authorName,
        description,
      };
    }

    // Handle video
    const videoUrl = (result.result as any).videoHD || 
                     (result.result as any).video1 || 
                     (result.result as any).video;
    
    if (!videoUrl) {
      return { success: false, mediaType: 'video', error: 'No video URL found in response' };
    }

    // Download the video file
    const response = await fetch(videoUrl);
    if (!response.ok) {
      return { success: false, mediaType: 'video', error: `Failed to download video: ${response.status}` };
    }

    const videoId = generateVideoId();
    const tempPath = join(config.VIDEOS_PATH, `temp_${videoId}.mp4`);
    
    const buffer = await response.arrayBuffer();
    await writeFile(tempPath, Buffer.from(buffer));

    return {
      success: true,
      mediaType: 'video',
      filePath: tempPath,
      author: authorName,
      description,
    };
  } catch (error) {
    return { 
      success: false, 
      mediaType: 'video',
      error: error instanceof Error ? error.message : 'Unknown error' 
    };
  }
}

// Fallback: Download using yt-dlp (videos only)
async function downloadWithYtDlp(url: string): Promise<DownloadResult> {
  return new Promise((resolve) => {
    const videoId = generateVideoId();
    const outputPath = join(config.VIDEOS_PATH, `temp_${videoId}.mp4`);
    
    const ytdlp = spawn('yt-dlp', [
      '-f', 'best[ext=mp4]/best',
      '-o', outputPath,
      '--no-playlist',
      '--no-warnings',
      url,
    ]);

    let stderr = '';
    
    ytdlp.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    ytdlp.on('close', (code) => {
      if (code === 0 && existsSync(outputPath)) {
        resolve({ success: true, mediaType: 'video', filePath: outputPath });
      } else {
        resolve({ success: false, mediaType: 'video', error: stderr || `yt-dlp exited with code ${code}` });
      }
    });

    ytdlp.on('error', (error) => {
      resolve({ success: false, mediaType: 'video', error: error.message });
    });
  });
}

// Main download function with fallback
export async function downloadTikTokVideo(url: string): Promise<DownloadResult> {
  console.log(`[TikTok] Downloading: ${url}`);
  
  // Try library first
  let result = await downloadWithLibrary(url);
  
  if (result.success) {
    console.log(`[TikTok] Downloaded successfully with library (type: ${result.mediaType})`);
    return result;
  }

  console.log(`[TikTok] Library failed: ${result.error}, trying yt-dlp...`);
  
  // Fallback to yt-dlp (only works for videos)
  result = await downloadWithYtDlp(url);
  
  if (result.success) {
    console.log(`[TikTok] Downloaded successfully with yt-dlp`);
  } else {
    console.log(`[TikTok] yt-dlp also failed: ${result.error}`);
  }
  
  return result;
}

// Cleanup temp file
export async function cleanupTempFile(filePath: string): Promise<void> {
  try {
    await unlink(filePath);
  } catch {
    // Ignore errors
  }
}

// Cleanup slideshow directory
export async function cleanupSlideshowDir(dirPath: string): Promise<void> {
  try {
    await rm(dirPath, { recursive: true, force: true });
  } catch {
    // Ignore errors
  }
}
