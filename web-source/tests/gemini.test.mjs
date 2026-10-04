import test from "node:test";
import assert from "node:assert/strict";
import {
  geminiGenerate,
  geminiCall,
  geminiError,
  validKey,
  providerError,
  throwProviderError,
  GeminiProviderError,
  listGeminiModels,
  compatibleGeminiModels,
  withModelFallback,
  pcmWave,
  GEMINI_MODEL,
} from "../lib/gemini.ts";
import {
  readApiJson,
  retryableGeminiResponse,
  postTutorJson,
} from "../lib/gemini-client.ts";
import { sealKey, openKey } from "../lib/key-vault.ts";
import { checkOrigin } from "../lib/request-origin.ts";

test("Gemini sends credentials only in headers and preserves the validated JSON contract", async () => {
  const original = globalThis.fetch;
  let sent;
  globalThis.fetch = async (url, options) => {
    sent = { url, options };
    return Response.json({
      candidates: [
        {
          finishReason: "STOP",
          content: {
            parts: [
              { thought: true, text: "private reasoning" },
              { text: '{"ok":true}' },
            ],
          },
        },
      ],
    });
  };
  try {
    assert.deepEqual(
      await geminiGenerate("test-credential", "Check", {}, { type: "object" }),
      { ok: true },
    );
    assert.ok(sent.url.endsWith(GEMINI_MODEL + ":generateContent"));
    assert.equal(sent.options.headers["x-goog-api-key"], "test-credential");
    assert.ok(!sent.url.includes("test-credential"));
    assert.ok(!sent.options.body.includes("test-credential"));
    assert.equal(
      JSON.parse(sent.options.body).generationConfig.thinkingConfig
        .thinkingLevel,
      "LOW",
    );
    assert.equal(JSON.parse(sent.options.body).store, false);
  } finally {
    globalThis.fetch = original;
  }
});
test("Missing keys, provider errors, blocked and truncated outputs do not become successful answers", async () => {
  const original = globalThis.fetch;
  let calls = 0;
  globalThis.fetch = async () => {
    calls++;
    return new Response(null, { status: 403 });
  };
  try {
    await assert.rejects(
      () => geminiCall("", GEMINI_MODEL, {}),
      /NOT_CONFIGURED/,
    );
    assert.equal(calls, 0);
    await assert.rejects(() => geminiGenerate("test", "", {}, {}), /KEY/);
    for (const reason of ["MAX_TOKENS", "SAFETY", undefined]) {
      globalThis.fetch = async () =>
        Response.json({
          candidates: [
            {
              finishReason: reason,
              content: { parts: [{ text: '{"ok":true}' }] },
            },
          ],
        });
      await assert.rejects(
        () => geminiGenerate("test", "", {}, {}),
        /INCOMPLETE/,
      );
    }
    const error = geminiError(new Error("provider echoed SECRET"));
    assert.ok(!(await error.text()).includes("SECRET"));
  } finally {
    globalThis.fetch = original;
  }
});
test("Empty/non-JSON errors are readable and origin is strict", async () => {
  await assert.rejects(
    () => readApiJson(new Response(null, { status: 403 })),
    /źródło/,
  );
  await assert.rejects(
    () => readApiJson(new Response("Bad gateway", { status: 502 })),
    /HTTP 502/,
  );
  assert.equal(validKey("invalid key"), false);
  assert.equal(
    checkOrigin(
      new Request("https://example.com", {
        headers: { origin: "https://example.com" },
      }),
    ),
    null,
  );
  for (const origin of [undefined, "null", "https://evil.example"]) {
    const r = checkOrigin(
      new Request("https://example.com", { headers: origin ? { origin } : {} }),
    );
    assert.equal(r.status, 403);
    assert.ok((await r.json()).error);
  }
});
test("Client silently retries only transient Gemini overload responses", async () => {
  assert.equal(
    await retryableGeminiResponse(
      Response.json({ code: "PROVIDER" }, { status: 503 }),
    ),
    true,
  );
  assert.equal(
    await retryableGeminiResponse(
      Response.json({ code: "LIMIT" }, { status: 429 }),
    ),
    false,
  );
  assert.equal(
    await retryableGeminiResponse(
      Response.json({ code: "APP_LIMIT" }, { status: 429 }),
    ),
    false,
  );
  assert.equal(
    await retryableGeminiResponse(
      Response.json({ code: "REQUEST" }, { status: 400 }),
    ),
    false,
  );
});
test("Tutor retry ends after three overload responses and never retries quota", async () => {
  const original = globalThis.fetch;
  let calls = 0;
  try {
    globalThis.fetch = async () => {
      calls++;
      return Response.json({code: "PROVIDER", error: "overload"}, {status: 503});
    };
    await assert.rejects(() => postTutorJson({action: "topicHydrate"}), /overload/);
    assert.equal(calls, 3);
    calls = 0;
    globalThis.fetch = async () => {
      calls++;
      return Response.json({code: "LIMIT", error: "limit"}, {status: 429});
    };
    await assert.rejects(() => postTutorJson({action: "topicHydrate"}), /limit/);
    assert.equal(calls, 1);
  } finally { globalThis.fetch = original; }
});
test("Errors distinguish invalid request, credentials and limits without leaking keys", async () => {
  assert.equal(providerError(400), "REQUEST");
  assert.equal(providerError(401), "KEY");
  assert.equal(providerError(403), "KEY");
  assert.equal(providerError(429), "LIMIT");
  const old = console.error;
  const logs = [];
  console.error = (...args) => logs.push(args);
  try {
    let error;
    try {
      await throwProviderError(
        Response.json(
          {
            error: {
              status: "INVALID_ARGUMENT",
              message: "Bad request secret-for-test",
            },
          },
          { status: 400 },
        ),
        "secret-for-test",
      );
    } catch (e) {
      error = e;
    }
    assert.ok(error instanceof GeminiProviderError);
    const body = await geminiError(error).json();
    assert.equal(body.code, "REQUEST");
    assert.equal(body.diagnostic.providerStatus, "INVALID_ARGUMENT");
    assert.ok(!JSON.stringify(body).includes("secret-for-test"));
    assert.ok(!JSON.stringify(logs).includes("secret-for-test"));
  } finally {
    console.error = old;
  }
});
test("Model discovery follows pagination and filters unsupported generation methods", async () => {
  const old = fetch;
  let count = 0;
  globalThis.fetch = async (url) => {
    count++;
    if (count === 1)
      return Response.json({
        models: [
          {
            name: "models/gemini-3.8-flash",
            supportedGenerationMethods: ["generateContent"],
          },
        ],
        nextPageToken: "next",
      });
    assert.equal(new URL(url).searchParams.get("pageToken"), "next");
    return Response.json({
      models: [
        {
          name: "models/embedding",
          supportedGenerationMethods: ["embedContent"],
        },
        {
          name: "models/gemini-2.5-flash",
          supportedGenerationMethods: ["generateContent"],
        },
      ],
    });
  };
  try {
    assert.deepEqual(
      [...(await listGeminiModels("test"))],
      ["gemini-3.8-flash", "gemini-2.5-flash"],
    );
  } finally {
    globalThis.fetch = old;
  }
});
test("Live model discovery ranks compatible Flash models and excludes specialized variants", () => {
  const available = [
    "gemini-2.5-flash",
    "gemini-3.9-flash-preview",
    "gemini-3.9-flash",
    "gemini-4.0-flash-lite",
    "gemini-4.0-flash-image",
    "gemini-3.1-flash-tts-preview",
    "text-embedding-004",
  ];
  assert.deepEqual(compatibleGeminiModels(available, "text"), [
    "gemini-4.0-flash-lite",
    "gemini-3.9-flash",
    "gemini-3.9-flash-preview",
    "gemini-2.5-flash",
  ]);
  assert.deepEqual(compatibleGeminiModels(available, "speech"), [
    "gemini-3.1-flash-tts-preview",
  ]);
});
test("Unavailable and overloaded models trigger bounded fallback; invalid requests do not", async () => {
  const attempts = [];
  const result = await withModelFallback(["new", "older"], async (model) => {
    attempts.push(model);
    if (model === "new") throw new GeminiProviderError(404, "NOT_FOUND", "");
    return "ok";
  });
  assert.equal(result.model, "older");
  assert.deepEqual(attempts, ["new", "older"]);
  for (const status of [408, 500, 502, 503, 504]) {
    const transientAttempts = [];
    const transientResult = await withModelFallback(
      ["new", "older"],
      async (model) => {
        transientAttempts.push(model);
        if (model === "new")
          throw new GeminiProviderError(status, "UNAVAILABLE", "");
        return "ok";
      },
    );
    assert.equal(transientResult.model, "older");
    assert.deepEqual(transientAttempts, ["new", "older"]);
  }
  for (const status of [400, 401, 403, 422, 429]) {
    let calls = 0;
    await assert.rejects(() =>
      withModelFallback(["new", "older"], async () => {
        calls++;
        throw new GeminiProviderError(status, "ERROR", "");
      }),
    );
    assert.equal(calls, 1);
  }
  let boundedCalls = 0;
  await assert.rejects(
    () =>
      withModelFallback(["one", "two", "three", "four"], async () => {
        boundedCalls++;
        throw new GeminiProviderError(503, "UNAVAILABLE", "busy");
      }),
    /PROVIDER/,
  );
  assert.equal(boundedCalls, 3);
  const old = fetch;
  globalThis.fetch = async (_, opts) => {
    assert.equal(
      JSON.parse(opts.body).generationConfig.thinkingConfig,
      undefined,
    );
    return Response.json({
      candidates: [
        { finishReason: "STOP", content: { parts: [{ text: "{}" }] } },
      ],
    });
  };
  try {
    await geminiGenerate("test", "", {}, {}, "gemini-2.5-flash");
  } finally {
    globalThis.fetch = old;
  }
});
test("Provider overload is returned as a retryable 503 with safe diagnostics", async () => {
  const response = geminiError(
    new GeminiProviderError(
      503,
      "UNAVAILABLE",
      "high demand secret-for-test",
    ),
  );
  assert.equal(response.status, 503);
  assert.equal(response.headers.get("Retry-After"), "15");
  const body = await response.json();
  assert.equal(body.code, "PROVIDER");
  assert.equal(body.diagnostic.httpStatus, 503);
  assert.equal(body.diagnostic.providerStatus, "UNAVAILABLE");
  assert.ok(body.error.includes("przeciążone"));
  assert.ok(!JSON.stringify(body).includes("secret-for-test"));
});
test("Model catalog failures stay readable without exposing raw Google 404 diagnostics", async () => {
  const response = geminiError(
    new GeminiProviderError(404, "NOT_FOUND", "model does not exist"),
  );
  await assert.rejects(
    () => readApiJson(response),
    (error) => {
      assert.match(error.message, /sprawdziła dostępne modele/i);
      assert.doesNotMatch(error.message, /404|NOT_FOUND|model does not exist/);
      return true;
    },
  );
});
test("Saved credentials survive reload, are owner-bound and authenticated against tampering", async () => {
  const secret = btoa(
    String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))),
  );
  const raw = "test-key-never-plaintext";
  const sealed = await sealKey(raw, "account-A", secret);
  assert.ok(!sealed.includes(raw));
  assert.equal(
    await openKey(JSON.parse(JSON.stringify(sealed)), "account-A", secret),
    raw,
  );
  await assert.rejects(() => openKey(sealed, "account-B", secret), /VAULT/);
  const parts = sealed.split(".");
  parts[2] = (parts[2][0] === "A" ? "B" : "A") + parts[2].slice(1);
  await assert.rejects(
    () => openKey(parts.join("."), "account-A", secret),
    /VAULT/,
  );
  assert.notEqual(await sealKey(raw, "account-A", secret), sealed);
});
test("Gemini PCM becomes a playable mono WAV and invalid audio is rejected", () => {
  const audio = pcmWave(
    btoa("\x00\x00\xff\x7f"),
    "audio/L16;codec=pcm;rate=24000",
  );
  const v = new DataView(audio.buffer);
  assert.equal(new TextDecoder().decode(audio.slice(0, 4)), "RIFF");
  assert.equal(v.getUint32(24, true), 24000);
  assert.equal(v.getUint16(22, true), 1);
  assert.equal(v.getUint32(40, true), 4);
  assert.deepEqual([...audio.slice(44)], [0, 0, 255, 127]);
  assert.throws(() => pcmWave("AA==", "audio/L16;rate=24000"), /AUDIO/);
  assert.throws(() => pcmWave("AAAA", "text/plain"), /AUDIO/);
  assert.throws(
    () => pcmWave("AAAA", "audio/L16;rate=24000;channels=2"),
    /AUDIO/,
  );
  assert.throws(() => pcmWave("AAAA", "audio/L16;rate=24000;bits=24"), /AUDIO/);
});
