# Fluent

Polish-first English vocabulary learning application with a meaning-based spaced repetition model.

## Product
See `public/plan-produktu.md` for the scope, screen map, data model, algorithm, component system, roadmap, and limitations.

## Runtime
Vinext + React + TypeScript, Cloudflare Worker, D1. Hosted authentication uses platform-owned ChatGPT sign-in. All API records are owner-scoped. Each learning aggregate has an optimistic revision guard. No audio recordings are stored. Gemini credentials are encrypted in an owner-scoped server table.

## Main code
- app/fluent.tsx — interactive product screens
- lib/learning.ts — vocabulary types, demo content, scheduling and review transitions
- lib/state-schema.ts — shared validation for storage and imports
- app/api/state/route.ts — authenticated, owner-scoped persistence
- db/schema.ts and drizzle/ — physical schema and migrations

## Verification
Run `npm test` for scheduling, meaning isolation, session queues and import validation. TypeScript is checked with `node node_modules/typescript/bin/tsc --noEmit`.

Full offline learning, push reminders and microphone evaluation are future features. Word enrichment, contextual answer evaluation, new graded reading passages and natural speech use Gemini through authenticated server routes; connect with a Google AI Studio key in Settings. Missing configuration is explicit in the UI and never silently presented as AI output. The installed PWA shows a clear fallback when the network is unavailable.


## Language assistant update (September 2026)
- Quick add with per-sense selection, bilingual examples and automatic thematic collections.
- Contextual grading: lexical variants accepted, dictation remains exact, uncertain assessments do not auto-fail.
- Complete Polish translations and highlighted expression spans, including inflected gap forms.
- Reading comprehension sessions with separate persisted results and approximate CEFR derived from practiced senses.
- More advanced related vocabulary with explicit differences in meaning and register.
- General American speech preference, voice discovery after voiceschanged, explicit English-only system fallback, and server-generated speech when configured.

## Gemini connection
Open Settings → Połączenie z Gemini, paste your Google AI Studio API key and choose Połącz. The app performs a small real structured-output request before showing Connected. Text uses `gemini-3.8-flash` (the latest stable Flash in Google's catalog checked 2026-09-09); speech uses `gemini-3.1-flash-tts-preview` with Kore and General American instructions. Flash text models do not generate audio themselves.

Keys are submitted once in a JSON POST body, verified with Google's paginated models endpoint and a real structured-output request, then encrypted in `gemini_connections`. AES-256-GCM uses a per-account HKDF-derived key and owner-bound authenticated data. The server master `GEMINI_KEY_ENCRYPTION_SECRET` is a 32-byte base64 secret in runtime configuration, never source code. Keep it backed up securely; do not rotate it without re-encrypting existing records. A missing/changed secret produces a readable connection error. No keys are returned by GET, included in learning exports, or stored in browser storage. Disconnect and data deletion remove the server record.

Models are filtered by generateContent support. Text falls back through 3.8, 3.7, 3.6, 3.5 and 2.5 Flash only on 404; speech through 3.1 Flash TTS and 2.5 Flash TTS. The active model is persisted and shown in Settings (refresh status after a runtime fallback). A successful model listing does not prove billing or generation access: the connection test verifies text generation; speech is verified on playback. Older 2.5 models omit thinkingLevel. Current REST docs include store, responseJsonSchema and uppercase LOW; those valid fields are preserved.

Google errors retain HTTP and provider status in production responses and redacted provider messages in development. Server diagnostics read response text, redact the API key and cap at 8 KB. All mutating routes require exact Origin matching and return JSON errors. Daily Fluent quota is 200 operations per account, separately identified from Google's quota.

Automated tests use mocked Google responses and real SQLite migrations to check persistence, owner isolation, deletion, model fallback, diagnostics, malformed replies and encryption. No live key is available to this workspace; Google model listing and generation must be verified through Settings → Połącz i zapisz. Do not treat tests as a live-provider success claim.

## Run the source
Requires Node.js 22.13+ and npm. Run `npm ci`, `npm test`, and `npm run build`. For local development use `npm run dev`. Production requires the `GEMINI_KEY_ENCRYPTION_SECRET` runtime secret and uses Cloudflare Workers with the `DB` D1 binding and the migrations in `drizzle/`. ChatGPT authentication is supplied by Sites; outside Sites, replace the trusted identity integration before exposing authenticated API routes. A standalone local preview can show the demo without a signed-in account. Do not trust a user-supplied identity header on an unprotected external deployment.

The source ZIP includes source, lockfile, database migrations and build scripts. It excludes dependencies, build output, Git history and credentials.

Official references:
- https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash
- https://ai.google.dev/api/generate-content
- https://ai.google.dev/gemini-api/docs/speech-generation
