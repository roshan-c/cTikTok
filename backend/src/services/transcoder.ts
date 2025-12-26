import { spawn } from 'child_process';
import { stat, unlink } from 'fs/promises';
import { join } from 'path';
import { config } from '../utils/config';

export interface TranscodeResult {
  success: boolean;
  outputPath?: string;
  thumbnailPath?: string;
  durationSeconds?: number;
  fileSizeBytes?: number;
  error?: string;
}

// Get video duration using ffprobe
async function getVideoDuration(inputPath: string): Promise<number | undefined> {
  return new Promise((resolve) => {
    const ffprobe = spawn('ffprobe', [
      '-v', 'quiet',
      '-show_entries', 'format=duration',
      '-of', 'csv=p=0',
      inputPath,
    ]);

    let output = '';
    ffprobe.stdout.on('data', (data) => {
      output += data.toString();
    });

    ffprobe.on('close', () => {
      const duration = parseFloat(output.trim());
      resolve(isNaN(duration) ? undefined : Math.round(duration));
    });

    ffprobe.on('error', () => resolve(undefined));
  });
}

// Generate thumbnail from video
async function generateThumbnail(inputPath: string, outputPath: string): Promise<boolean> {
  return new Promise((resolve) => {
    const ffmpeg = spawn('ffmpeg', [
      '-y',
      '-i', inputPath,
      '-ss', '00:00:01',
      '-vframes', '1',
      '-vf', 'scale=480:-1',
      '-q:v', '5',
      outputPath,
    ]);

    ffmpeg.on('close', (code) => resolve(code === 0));
    ffmpeg.on('error', () => resolve(false));
  });
}

// Transcode video for optimal mobile playback
export async function transcodeVideo(inputPath: string, videoId: string): Promise<TranscodeResult> {
  const outputPath = join(config.VIDEOS_PATH, `${videoId}.mp4`);
  const thumbnailPath = join(config.VIDEOS_PATH, `${videoId}_thumb.jpg`);

  return new Promise((resolve) => {
    console.log(`[Transcode] Starting: ${inputPath} -> ${outputPath}`);

    const ffmpeg = spawn('ffmpeg', [
      '-y',                            // Overwrite output
      '-i', inputPath,                 // Input file
      '-c:v', 'libx264',               // H.264 codec
      '-preset', 'medium',             // Balance speed/quality
      '-crf', '23',                    // Quality (18-28, lower = better)
      '-vf', "scale='min(720,iw)':-2", // Cap width at 720p, maintain aspect
      '-c:a', 'aac',                   // AAC audio
      '-b:a', '128k',                  // Audio bitrate
      '-movflags', '+faststart',       // Enable streaming
      '-pix_fmt', 'yuv420p',           // Compatibility
      '-max_muxing_queue_size', '1024',
      outputPath,
    ]);

    let stderr = '';
    ffmpeg.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    ffmpeg.on('close', async (code) => {
      if (code !== 0) {
        console.log(`[Transcode] Failed with code ${code}: ${stderr}`);
        resolve({ success: false, error: `FFmpeg failed with code ${code}` });
        return;
      }

      console.log(`[Transcode] Complete: ${outputPath}`);

      // Get file stats
      let fileSizeBytes: number | undefined;
      try {
        const stats = await stat(outputPath);
        fileSizeBytes = stats.size;
      } catch {
        // Ignore
      }

      // Get duration
      const durationSeconds = await getVideoDuration(outputPath);

      // Generate thumbnail
      const thumbSuccess = await generateThumbnail(outputPath, thumbnailPath);
      console.log(`[Transcode] Thumbnail: ${thumbSuccess ? 'generated' : 'failed'}`);

      // Clean up input file
      try {
        await unlink(inputPath);
        console.log(`[Transcode] Cleaned up temp file`);
      } catch {
        // Ignore
      }

      resolve({
        success: true,
        outputPath,
        thumbnailPath: thumbSuccess ? thumbnailPath : undefined,
        durationSeconds,
        fileSizeBytes,
      });
    });

    ffmpeg.on('error', (error) => {
      console.log(`[Transcode] Error: ${error.message}`);
      resolve({ success: false, error: error.message });
    });
  });
}
