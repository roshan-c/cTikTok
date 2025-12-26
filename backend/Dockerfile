FROM oven/bun:1-alpine

# Install FFmpeg and yt-dlp
RUN apk add --no-cache ffmpeg python3 py3-pip curl \
    && pip3 install --break-system-packages yt-dlp

WORKDIR /app

# Copy package files
COPY package.json bun.lock* ./

# Install dependencies
RUN bun install --frozen-lockfile || bun install

# Copy source
COPY . .

# Create directories
RUN mkdir -p data videos

# Expose port
EXPOSE 3000

# Run migrations and start server
CMD ["sh", "-c", "bun run db:migrate && bun run start"]
