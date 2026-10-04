CREATE TABLE `tutor_usage` (
	`owner` text PRIMARY KEY NOT NULL,
	`day` text NOT NULL,
	`count` integer DEFAULT 0 NOT NULL
);
