CREATE TABLE `shared_aliases` (
	`alias` text PRIMARY KEY NOT NULL,
	`cache_key` text NOT NULL,
	`category` text,
	`source` text NOT NULL,
	`created` integer NOT NULL,
	`hits` integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
CREATE TABLE `shared_content` (
	`cache_key` text PRIMARY KEY NOT NULL,
	`kind` text NOT NULL,
	`canonical` text NOT NULL,
	`payload` text NOT NULL,
	`model` text NOT NULL,
	`prompt_ver` integer NOT NULL,
	`created` integer NOT NULL,
	`refreshed` integer NOT NULL,
	`hits` integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
CREATE INDEX `shared_content_kind_hits` ON `shared_content` (`kind`,`hits` DESC);--> statement-breakpoint
CREATE TABLE `shared_resolution_log` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`query` text NOT NULL,
	`normalized` text NOT NULL,
	`layer` text NOT NULL,
	`cache_key` text,
	`created` integer NOT NULL
);
