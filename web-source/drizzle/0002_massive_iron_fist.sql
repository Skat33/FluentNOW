CREATE TABLE `gemini_connections` (
	`owner` text PRIMARY KEY NOT NULL,
	`encrypted_key` text NOT NULL,
	`model` text NOT NULL,
	`speech_model` text
);
