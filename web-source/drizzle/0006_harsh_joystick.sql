CREATE TABLE `exercise_reports` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`payload` text NOT NULL,
	`status` text DEFAULT 'pending' NOT NULL,
	`created` integer NOT NULL,
	`updated` integer NOT NULL,
	`reason` text DEFAULT '' NOT NULL,
	`run_token` text,
	`retry_at` integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
CREATE INDEX `reports_owner_created` ON `exercise_reports` (`owner`,`created`);--> statement-breakpoint
CREATE INDEX `reports_status_retry` ON `exercise_reports` (`status`,`retry_at`);--> statement-breakpoint
CREATE TABLE `report_corrections` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`target_key` text NOT NULL,
	`payload` text NOT NULL,
	`updated` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `corrections_owner` ON `report_corrections` (`owner`);--> statement-breakpoint
CREATE TABLE `report_runs` (
	`id` text PRIMARY KEY NOT NULL,
	`token` text NOT NULL,
	`started` integer NOT NULL,
	`lease_until` integer NOT NULL,
	`next_run` integer NOT NULL
);
