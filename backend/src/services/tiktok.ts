// eslint-disable-next-line @typescript-eslint/no-var-requires
const TiktokDL = require('@tobyg74/tiktok-api-dl') as {
  Downloader: (url: string, options?: { version?: string; proxy?: string }) => Promise<{
    status: string;
    message?: string;
    result?: {
      videoHD?: string;
      video1?: string;
      video?: string;
      author?: { nickname?: string; username?: string };
      desc?: string;
      description?: string;
    };
  }>;
};
import { spawn } from 'child_process';
import { existsSync } from 'fs';
import { unlink, writeFile } from 'fs/promises';
import { join } from 'path';
import { config } from '../utils/config';
import { generateVideoId } from '../utils/id';

export interface DownloadResult {
  success: boolean;
  filePath?: string;
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

// Download video using @tobyg74/tiktok-api-dl
async function downloadWithLibrary(url: string): Promise<DownloadResult> {
  try {
    const result = await TiktokDL.Downloader(url, { version: 'v3' });
    
    if (result.status !== 'success' || !result.result) {
      return { success: false, error: result.message || 'Failed to fetch video info' };
    }

    // v3 uses videoHD or video1
    const videoUrl = (result.result as any).videoHD || 
                     (result.result as any).video1 || 
                     (result.result as any).video;
    
    if (!videoUrl) {
      return { success: false, error: 'No video URL found in response' };
    }

    // Download the video file
    const response = await fetch(videoUrl);
    if (!response.ok) {
      return { success: false, error: `Failed to download video: ${response.status}` };
    }

    const videoId = generateVideoId();
    const tempPath = join(config.VIDEOS_PATH, `temp_${videoId}.mp4`);
    
    const buffer = await response.arrayBuffer();
    await writeFile(tempPath, Buffer.from(buffer));

    const author = (result.result as any).author;
    return {
      success: true,
      filePath: tempPath,
      author: author?.nickname || author?.username,
      description: (result.result as any).desc || (result.result as any).description,
    };
  } catch (error) {
    return { 
      success: false, 
      error: error instanceof Error ? error.message : 'Unknown error' 
    };
  }
}

// Fallback: Download using yt-dlp
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
        resolve({ success: true, filePath: outputPath });
      } else {
        resolve({ success: false, error: stderr || `yt-dlp exited with code ${code}` });
      }
    });

    ytdlp.on('error', (error) => {
      resolve({ success: false, error: error.message });
    });
  });
}

// Main download function with fallback
export async function downloadTikTokVideo(url: string): Promise<DownloadResult> {
  console.log(`[TikTok] Downloading: ${url}`);
  
  // Try library first
  let result = await downloadWithLibrary(url);
  
  if (result.success) {
    console.log(`[TikTok] Downloaded successfully with library`);
    return result;
  }

  console.log(`[TikTok] Library failed: ${result.error}, trying yt-dlp...`);
  
  // Fallback to yt-dlp
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
