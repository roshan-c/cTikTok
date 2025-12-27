import { Hono } from 'hono';
import { createReadStream } from 'fs';
import { readFile, stat, access } from 'fs/promises';
import { join } from 'path';

const altstoreRoute = new Hono();

const ALTSTORE_PATH = './altstore';

// Helper function to check if file exists (async)
async function fileExists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

// Serve source.json
altstoreRoute.get('/source.json', async (c) => {
  const filePath = join(ALTSTORE_PATH, 'source.json');
  
  if (!await fileExists(filePath)) {
    return c.json({ error: 'Source not found' }, 404);
  }

  const content = await readFile(filePath, 'utf-8');
  const source = JSON.parse(content);
  
  // Update the size dynamically if IPA exists
  const ipaPath = join(ALTSTORE_PATH, 'cTikTok.ipa');
  if (await fileExists(ipaPath)) {
    const stats = await stat(ipaPath);
    source.apps[0].size = stats.size;
  }

  return c.json(source);
});

// Serve IPA file
altstoreRoute.get('/cTikTok.ipa', async (c) => {
  const filePath = join(ALTSTORE_PATH, 'cTikTok.ipa');
  
  if (!await fileExists(filePath)) {
    return c.json({ error: 'IPA not found' }, 404);
  }

  const stats = await stat(filePath);
  const stream = createReadStream(filePath);

  return new Response(stream as unknown as ReadableStream, {
    status: 200,
    headers: {
      'Content-Type': 'application/octet-stream',
      'Content-Disposition': 'attachment; filename="cTikTok.ipa"',
      'Content-Length': stats.size.toString(),
    },
  });
});

// Serve icon
altstoreRoute.get('/icon.png', async (c) => {
  const filePath = join(ALTSTORE_PATH, 'icon.png');
  
  if (!await fileExists(filePath)) {
    return c.json({ error: 'Icon not found' }, 404);
  }

  const stream = createReadStream(filePath);

  return new Response(stream as unknown as ReadableStream, {
    status: 200,
    headers: {
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=86400',
    },
  });
});

export default altstoreRoute;
