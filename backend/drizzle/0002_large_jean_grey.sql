ALTER TABLE `videos` ADD `media_type` text DEFAULT 'video' NOT NULL;--> statement-breakpoint
ALTER TABLE `videos` ADD `images` text;--> statement-breakpoint
ALTER TABLE `videos` ADD `audio_path` text;