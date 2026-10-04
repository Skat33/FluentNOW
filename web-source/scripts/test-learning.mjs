import { build } from "esbuild";
import { spawnSync } from "node:child_process";
await build({
  entryPoints: [
    "tests/reports.test.mjs",
    "tests/learning.test.mjs",
    "tests/tutor.test.mjs",
    "tests/gemini.test.mjs",
    "tests/gemini-routes.test.mjs",
    "tests/tutor-routes.test.mjs",
    "tests/shared-corpus.test.mjs",
  ],
  bundle: true,
  alias: {
    "cloudflare:workers": "./tests/fixtures/gemini-runtime.mjs",
    "next/headers": "./tests/fixtures/gemini-runtime.mjs",
    "next/server": "./tests/fixtures/gemini-runtime.mjs",
  },
  platform: "node",
  format: "esm",
  outdir: ".sites-runtime/checks",
  outExtension: { ".js": ".mjs" },
});
const r = spawnSync(
  process.execPath,
  [
    "--test",
    ".sites-runtime/checks/reports.test.mjs",
    ".sites-runtime/checks/learning.test.mjs",
    ".sites-runtime/checks/tutor.test.mjs",
    ".sites-runtime/checks/gemini.test.mjs",
    ".sites-runtime/checks/gemini-routes.test.mjs",
    ".sites-runtime/checks/tutor-routes.test.mjs",
    ".sites-runtime/checks/shared-corpus.test.mjs",
    "tests/ui-components.test.mjs",
    "tests/rendered-html.test.mjs",
    "tests/speech-worker.test.mjs",
  ],
  { stdio: "inherit" },
);
process.exit(r.status ?? 1);
