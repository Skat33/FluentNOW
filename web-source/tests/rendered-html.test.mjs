import assert from "node:assert/strict";
import test from "node:test";
import { createServer } from "vite";
import { fileURLToPath } from "node:url";

test("renders the production Fluent shell with accessible navigation", async (context) => {
  const root = fileURLToPath(new URL("..", import.meta.url));
  const vite = await createServer({
    appType: "custom",
    configFile: false,
    root,
    resolve: {
      alias: {
        "cloudflare:workers": `${root}/tests/fixtures/gemini-runtime.mjs`,
      },
    },
    server: { middlewareMode: true },
  });
  context.after(async () => vite.close());
  const { default: worker } = await vite.ssrLoadModule("/dist/server/index.js");

  const response = await worker.fetch(
    new Request("http://localhost/", {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );

  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);
  const html = await response.text();
  assert.match(html, /<title>Fluent — angielski w Twoim rytmie<\/title>/);
  assert.match(html, /id="main"/);
  assert.match(html, /aria-label="Szukaj słowa, tłumaczenia lub tagu"/);
  assert.match(html, /aria-label="Nawigacja mobilna"/);
  assert.match(html, /aria-current="page"/);
});
