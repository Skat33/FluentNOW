CREATE TABLE `topic_cache` (
	`topic_key` text PRIMARY KEY NOT NULL,
	`payload` text NOT NULL,
	`created` integer NOT NULL
);
