import { z } from 'zod';

const envSchema = z.object({
  PORT: z.string().default('3000').transform(Number),
  JWT_SECRET: z.string().min(32),
  VIDEO_EXPIRY_DAYS: z.string().default('7').transform(Number),
  DATABASE_PATH: z.string().default('./data/ctiktok.db'),
  VIDEOS_PATH: z.string().default('./videos'),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('Invalid environment variables:', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const config = parsed.data;
