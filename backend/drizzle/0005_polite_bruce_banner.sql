CREATE INDEX `favorites_user_idx` ON `favorites` (`user_id`);--> statement-breakpoint
CREATE INDEX `favorites_video_idx` ON `favorites` (`video_id`);--> statement-breakpoint
CREATE INDEX `friend_requests_to_user_status_idx` ON `friend_requests` (`to_user_id`,`status`);--> statement-breakpoint
CREATE INDEX `friendships_user_idx` ON `friendships` (`user_id`);--> statement-breakpoint
CREATE INDEX `friendships_friend_idx` ON `friendships` (`friend_id`);--> statement-breakpoint
CREATE INDEX `videos_sender_idx` ON `videos` (`sender_id`);--> statement-breakpoint
CREATE INDEX `videos_status_idx` ON `videos` (`status`);--> statement-breakpoint
CREATE INDEX `videos_created_at_idx` ON `videos` (`created_at`);--> statement-breakpoint
CREATE INDEX `videos_expires_at_idx` ON `videos` (`expires_at`);