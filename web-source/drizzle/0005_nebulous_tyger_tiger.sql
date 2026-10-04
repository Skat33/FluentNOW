CREATE TABLE `example_pools` (
	`pool_key` text PRIMARY KEY NOT NULL,
	`scope` text NOT NULL,
	`descriptor` text NOT NULL,
	`payload` text DEFAULT '{}' NOT NULL,
	`lease_token` text,
	`lease_until` integer DEFAULT 0 NOT NULL,
	`updated` integer NOT NULL
);
