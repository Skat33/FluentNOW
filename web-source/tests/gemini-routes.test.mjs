import test from "node:test";
import assert from "node:assert/strict";
import { GET, POST, PATCH, DELETE } from "../app/api/gemini/route.ts";
import {
  PUT as statePut,
  DELETE as stateDelete,
} from "../app/api/state/route.ts";
import {
  GET as speechGet,
  POST as speechPost,
} from "../app/api/speech/route.ts";
import { speechCacheHash,MAX_SPEECH_TEXT_LENGTH } from "../lib/speech-cache.ts";
import { independentSpeech, safeDictionaryAudio } from "../lib/speech-providers.ts";
import {
  accountGenerate,
  disconnect,
  saveConnection,
} from "../lib/gemini-account.ts";
import { GeminiProviderError } from "../lib/gemini.ts";
import { env, setOwner, sqlite } from "./fixtures/gemini-runtime.mjs";
const origin = "https://fluent.example";

test("dictionary audio works without Gemini, respects the accent and never fetches untrusted URLs", async () => {
  const oldFetch=globalThis.fetch, oldKey=env.GEMINI_API_KEY;
  delete env.GEMINI_API_KEY;
  setOwner("dictionary-listener");
  const calls=[];
  globalThis.fetch=async (url,options)=>{
    calls.push(String(url));
    assert.equal(options?.headers?.["x-goog-api-key"],undefined);
    if (String(url).includes("/api/v2/entries/")) return Response.json([{phonetics:[
      {audio:"https://api.dictionaryapi.dev/media/pronunciations/en/passport-uk.mp3"},
      {audio:"https://api.dictionaryapi.dev/media/pronunciations/en/passport-us.mp3",sourceUrl:"https://commons.wikimedia.org/wiki/File:En-us-passport.ogg"},
    ]}]);
    assert.match(String(url), /passport-us\.mp3$/);
    return new Response(new Uint8Array([73,68,51,0]),{headers:{"Content-Type":"audio/mpeg"}});
  };
  try {
    const model="auto-us-v1",text="passport",h=await speechCacheHash(text,"word",model);
    const response=await speechGet(new Request(`${origin}/api/speech?${new URLSearchParams({model,t:text,h,mode:"word"})}`));
    assert.equal(response.status,200);
    assert.equal(response.headers.get("X-Speech-Provider"),"dictionary");
    assert.match(decodeURIComponent(response.headers.get("X-Speech-Credit")),/commons.wikimedia.org/);
    assert.equal(calls.length,2);
    assert.equal(safeDictionaryAudio("http://127.0.0.1/audio-us.mp3","en-US"),null);
    assert.equal(safeDictionaryAudio("https://api.dictionaryapi.dev.evil.test/media/word-us.mp3","en-US"),null);
    assert.equal(safeDictionaryAudio("https://api.dictionaryapi.dev/media/word-uk.mp3","en-US"),null);
  } finally {globalThis.fetch=oldFetch;env.GEMINI_API_KEY=oldKey;}
});

test("Azure sentence narrator uses a server key, escapes SSML and does not call Gemini", async () => {
  const oldFetch=globalThis.fetch;
  env.AZURE_SPEECH_KEY="test-azure-secret";env.AZURE_SPEECH_REGION="eastus";
  globalThis.fetch=async (url,options)=>{
    assert.equal(url,"https://eastus.tts.speech.microsoft.com/cognitiveservices/v1");
    assert.equal(options.headers["Ocp-Apim-Subscription-Key"],"test-azure-secret");
    assert.match(options.body,/en-US-JennyNeural/);
    assert.match(options.body,/&lt;voice&gt; &amp;/);
    return new Response(new Uint8Array([73,68,51,0]),{headers:{"Content-Type":"audio/mpeg"}});
  };
  try {assert.equal((await independentSpeech("Read <voice> & only text.","sentence")).headers.get("X-Speech-Provider"),"azure");}
  finally {globalThis.fetch=oldFetch;delete env.AZURE_SPEECH_KEY;delete env.AZURE_SPEECH_REGION;}
});
const req = (method, body, sendOrigin = true) =>
  new Request(origin + "/api/gemini", {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(sendOrigin ? { origin } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
test("Real SQLite-backed connection saves only encrypted key, survives reload, isolates owners and deletes safely", async () => {
  const old = fetch;
  const models = [];
  setOwner("account-A");
  globalThis.fetch = async (url, options) => {
    assert.equal(
      options.headers["x-goog-api-key"],
      "fixture-key-for-account-A",
    );
    if (String(url).includes("/models?"))
      return Response.json({
        models: [
          {
            name: "models/gemini-3.8-flash",
            supportedGenerationMethods: ["generateContent"],
          },
          {
            name: "models/gemini-2.5-flash",
            supportedGenerationMethods: ["generateContent"],
          },
        ],
      });
    models.push(String(url));
    if (String(url).includes("3.8"))
      return Response.json(
        { error: { status: "NOT_FOUND", message: "Model unavailable" } },
        { status: 404 },
      );
    return Response.json({
      candidates: [
        { finishReason: "STOP", content: { parts: [{ text: '{"ok":true}' }] } },
      ],
    });
  };
  try {
    const response = await POST(
      req("POST", { key: "fixture-key-for-account-A" }),
    );
    assert.equal(response.status, 200);
    const connected = await response.json();
    assert.equal(connected.model, "gemini-2.5-flash");
    assert.equal(connected.speechModel, null);
    assert.equal(models.length, 2);
    const row = sqlite
      .prepare("SELECT * FROM gemini_connections WHERE owner=?")
      .get("account-A");
    assert.ok(!JSON.stringify(row).includes("fixture-key-for-account-A"));
    const status = await (await GET()).json();
    assert.equal(status.connected, true);
    assert.deepEqual(status.limit, { limit: 200, used: 0, remaining: 200 });
    const refreshed = await (await PATCH(req("PATCH"))).json();
    assert.equal(refreshed.model, "gemini-3.8-flash");
    assert.deepEqual(refreshed.limit, { limit: 200, used: 0, remaining: 200 });
    assert.equal(
      sqlite
        .prepare("SELECT count FROM tutor_usage WHERE owner=?")
        .get("account-A"),
      undefined,
    );
    setOwner("account-B");
    assert.equal((await (await GET()).json()).connected, false);
    await DELETE(req("DELETE"));
    assert.ok(
      sqlite
        .prepare("SELECT owner FROM gemini_connections WHERE owner=?")
        .get("account-A"),
    );
    setOwner("account-A");
    await stateDelete(req("DELETE"));
    assert.equal((await (await GET()).json()).connected, false);
  } finally {
    globalThis.fetch = old;
  }
});
test("All mutating routes reject missing origins with JSON, and connection requires identity", async () => {
  setOwner("account-A");
  for (const handler of [
    POST,
    PATCH,
    DELETE,
    statePut,
    stateDelete,
    speechPost,
  ]) {
    const r = await handler(req("POST", {}, false));
    assert.equal(r.status, 403);
    assert.ok((await r.json()).error);
  }
  setOwner(null);
  assert.equal(
    (await POST(req("POST", { key: "fixture-key-for-account-A" }))).status,
    401,
  );
});
test("a server-side Gemini key is the safe default and an account key remains an override", async () => {
  env.GEMINI_API_KEY = "shared-test-key";
  try {
    setOwner(null);
    const guestStatus = await (await GET()).json();
    assert.equal(guestStatus.connected, true);
    assert.equal(guestStatus.source, "shared");
    assert.deepEqual(guestStatus.limit, {
      limit: 200,
      used: 0,
      remaining: 200,
    });
    setOwner("shared-account");
    const status = await (await GET()).json();
    assert.equal(status.connected, true);
    assert.equal(status.source, "shared");
    assert.ok(status.model);
    assert.ok(status.speechModel);
    const afterDelete = await (await DELETE(req("DELETE"))).json();
    assert.equal(afterDelete.connected, true);
    assert.equal(afterDelete.source, "shared");
  } finally {
    delete env.GEMINI_API_KEY;
  }
});

test("an unavailable account model falls back to the shared app key", async () => {
  const oldFetch = globalThis.fetch;
  const owner = "account-shared-fallback";
  const accountKey = "account-key-with-missing-models";
  env.GEMINI_API_KEY = "shared-key-with-working-model";
  await saveConnection(owner, accountKey, "gemini-3.8-flash", null);
  const calls = [];
  globalThis.fetch = async (_url, options) => {
    assert.equal(options.headers["x-goog-api-key"], accountKey);
    return Response.json({ models: [] });
  };
  try {
    const result = await accountGenerate(owner, "text", async (key, model) => {
      calls.push({ key, model });
      if (key === accountKey)
        throw new GeminiProviderError(404, "NOT_FOUND", "missing model");
      return { key, model };
    });
    assert.equal(result.key, env.GEMINI_API_KEY);
    assert.equal(result.model, "gemini-3.8-flash");
    assert.ok(calls.some((call) => call.key === accountKey));
    assert.ok(calls.some((call) => call.key === env.GEMINI_API_KEY));
  } finally {
    globalThis.fetch = oldFetch;
    await disconnect(owner);
    delete env.GEMINI_API_KEY;
  }
});

test("shared Gemini automatically discovers and remembers a compatible Flash model after 404s", async () => {
  const oldFetch = globalThis.fetch;
  const key = "shared-key-for-live-model-discovery";
  env.GEMINI_API_KEY = key;
  setOwner(null);
  let catalogCalls = 0;
  const attempts = [];
  globalThis.fetch = async (url, options) => {
    assert.equal(options.headers["x-goog-api-key"], key);
    assert.match(String(url), /\/v1beta\/models\?/);
    catalogCalls++;
    return Response.json({
      models: [
        {
          name: "models/gemini-3.9-flash",
          supportedGenerationMethods: ["generateContent"],
        },
        {
          name: "models/gemini-3.9-flash-image",
          supportedGenerationMethods: ["generateContent"],
        },
      ],
    });
  };
  const generate = (candidateKey, model) => {
    attempts.push({ candidateKey, model });
    if (model !== "gemini-3.9-flash")
      throw new GeminiProviderError(404, "NOT_FOUND", "retired model");
    return Promise.resolve(model);
  };
  try {
    assert.equal(
      await accountGenerate(null, "text", generate),
      "gemini-3.9-flash",
    );
    const beforeSecondCall = attempts.length;
    assert.equal(
      await accountGenerate(null, "text", generate),
      "gemini-3.9-flash",
    );
    assert.equal(catalogCalls, 1);
    assert.deepEqual(attempts.slice(beforeSecondCall).map((item) => item.model), [
      "gemini-3.9-flash",
    ]);
    assert.ok(attempts.every((item) => item.candidateKey === key));
  } finally {
    globalThis.fetch = oldFetch;
    delete env.GEMINI_API_KEY;
  }
});

test("speech GET verifies its hash, uses a separate quota and reuses the public edge cache", async () => {
  const oldFetch = globalThis.fetch;
  const oldCaches = globalThis.caches;
  const cache = new Map();
  let generated = 0;
  env.GEMINI_API_KEY = "shared-speech-test-key";
  setOwner("speech-account");
  globalThis.caches = {
    async open(name) {
      assert.equal(name, "fluent-speech-v3");
      return this.default;
    },
    default: {
      async match(request) {
        assert.match(request.url, /\/_fluent\/speech-cache\/[a-f0-9]{32}$/);
        assert.equal(request.headers.get("authorization"), null);
        return cache.get(request.url)?.clone();
      },
      async put(request, response) {
        assert.match(request.url, /\/_fluent\/speech-cache\/[a-f0-9]{32}$/);
        assert.equal(request.headers.get("authorization"), null);
        cache.set(request.url, response.clone());
      },
    },
  };
  globalThis.fetch = async (url, options) => {
    generated++;
    assert.match(String(url), /\/v1beta\/interactions\?api_version=v1beta$/);
    assert.equal(options.headers["Api-Revision"], "2026-05-20");
    const body = JSON.parse(options.body);
    assert.equal(body.model, "gemini-3.1-flash-tts-preview");
    assert.deepEqual(body.response_format, { type: "audio" });
    assert.equal(body.store, false);
    assert.deepEqual(body.generation_config.speech_config, [
      { voice: "Kore" },
    ]);
    return Response.json({
      interaction: {
        output_audio: {
          data: Buffer.from(new Uint8Array(64)).toString("base64"),
          mime_type: "audio/pcm;rate=24000",
        },
      },
    });
  };
  try {
    const model = "gemini-3.1-flash-tts-preview";
    const text = "boarding pass";
    const hash = await speechCacheHash(text, "word", model);
    const url = `${origin}/api/speech?h=${hash}&t=${encodeURIComponent(text)}&mode=word&model=${model}`;
    const first = await speechGet(
      new Request(url, { headers: { Authorization: "Bearer private-site" } }),
    );
    assert.equal(first.status, 200);
    assert.match(first.headers.get("cache-control"), /immutable/);
    await new Promise((resolve) => setTimeout(resolve, 0));
    const second = await speechGet(new Request(url));
    assert.equal(second.status, 200);
    assert.equal(generated, 1);
    assert.equal(
      sqlite
        .prepare("SELECT count FROM tutor_usage WHERE owner=?")
        .get("speech:speech-account").count,
      1,
    );
    const invalid = await speechGet(
      new Request(url.replace(hash, "0".repeat(32))),
    );
    assert.equal(invalid.status, 400);
    const tooLong = "a".repeat(MAX_SPEECH_TEXT_LENGTH+1);
    const tooLongHash = await speechCacheHash(tooLong, "sentence", model);
    const oversized = await speechGet(
      new Request(
        `${origin}/api/speech?h=${tooLongHash}&t=${tooLong}&mode=sentence&model=${model}`,
      ),
    );
    assert.equal(oversized.status, 413);
  } finally {
    globalThis.fetch = oldFetch;
    globalThis.caches = oldCaches;
    delete env.GEMINI_API_KEY;
  }
});

test("speech silently falls back to the legacy TTS model when Gemini 3.1 Interactions is unavailable", async () => {
  const oldFetch = globalThis.fetch;
  const oldCaches = globalThis.caches;
  const calls = [];
  env.GEMINI_API_KEY = "shared-speech-fallback-key";
  setOwner("speech-fallback-account");
  globalThis.caches = undefined;
  globalThis.fetch = async (url, options) => {
    calls.push(String(url));
    assert.equal(options.headers["x-goog-api-key"], env.GEMINI_API_KEY);
    if (String(url).includes("/interactions?"))
      return Response.json(
        { error: { status: "INVALID_ARGUMENT", message: "Unsupported request" } },
        { status: 400 },
      );
    assert.match(
      String(url),
      /\/models\/gemini-2\.5-flash-preview-tts:generateContent$/,
    );
    const body = JSON.parse(options.body);
    assert.deepEqual(body.generationConfig.responseModalities, ["AUDIO"]);
    return Response.json({
      candidates: [
        {
          finishReason: "STOP",
          content: {
            parts: [
              {
                inlineData: {
                  data: Buffer.from(new Uint8Array(64)).toString("base64"),
                  mimeType: "audio/pcm;rate=24000",
                },
              },
            ],
          },
        },
      ],
    });
  };
  try {
    const model = "gemini-3.1-flash-tts-preview";
    const text = "terminal announcement";
    const hash = await speechCacheHash(text, "sentence", model);
    const response = await speechGet(
      new Request(
        `${origin}/api/speech?h=${hash}&t=${encodeURIComponent(text)}&mode=sentence&model=${model}`,
      ),
    );
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("content-type"), "audio/wav");
    assert.equal(calls.length, 2);
  } finally {
    globalThis.fetch = oldFetch;
    globalThis.caches = oldCaches;
    delete env.GEMINI_API_KEY;
  }
});


test("exercise narrator uses SSML silence, separate cache keys and cached clips during provider outages", async () => {
 const oldFetch=globalThis.fetch,oldCaches=globalThis.caches;
 env.AZURE_SPEECH_KEY="test-azure-secret";env.AZURE_SPEECH_REGION="eastus";
 setOwner("exercise-listener");let calls=0;const cache=new Map();
 globalThis.caches={open:async()=>({match:async key=>cache.get(key.url)?.clone(),put:async(key,value)=>{cache.set(key.url,value.clone());}})};
 globalThis.fetch=async(url,options)=>{
  calls++;assert.match(String(url),/tts.speech.microsoft.com/);
  assert.match(options.body,/<break time="900ms"\/>/);
  assert.doesNotMatch(options.body,/\[\[gap\]\]|would travel|podróżować/);
  return new Response(new Uint8Array([73,68,51,0]),{headers:{"Content-Type":"audio/mpeg"}});
 };
 try {
  const model="auto-us-v2",mode="exercise",t="I [[gap]] more.",h=await speechCacheHash(t,mode,model);
  assert.notEqual(h,await speechCacheHash("I would travel more.",mode,model));
  const request=()=>new Request(`${origin}/api/speech?${new URLSearchParams({model,mode,t,h})}`);
  assert.equal((await speechGet(request())).status,200);
  delete env.AZURE_SPEECH_KEY;
  assert.equal((await speechGet(request())).status,200);assert.equal(calls,1);
  globalThis.fetch=async()=>{throw Error("Exercise must not call Gemini");};
  const completed="I would travel more.",hash=await speechCacheHash(completed,mode,model);
  const missing=await speechGet(new Request(`${origin}/api/speech?${new URLSearchParams({model,mode,t:completed,h:hash})}`));
  assert.equal(missing.status,503);assert.equal((await missing.json()).code,"EXERCISE_SPEECH");
 } finally {globalThis.fetch=oldFetch;globalThis.caches=oldCaches;delete env.AZURE_SPEECH_KEY;delete env.AZURE_SPEECH_REGION;}
});


test("Azure retries a transient voice failure and coalesces simultaneous requests", async()=>{
 const oldFetch=globalThis.fetch;env.AZURE_SPEECH_KEY="  test-key  ";env.AZURE_SPEECH_REGION=" EastUS ";
 let calls=0;
 globalThis.fetch=async(url,options)=>{
  calls++;assert.match(String(url),/eastus.tts.speech.microsoft.com/);
  assert.equal(options.headers["Ocp-Apim-Subscription-Key"],"test-key");
  if(calls===1){assert.match(options.body,/JennyNeural/);return new Response("busy",{status:429});}
  assert.match(options.body,/AriaNeural/);
  return new Response(new Uint8Array([73,68,51,0]),{headers:{"Content-Type":"audio/mpeg"}});
 };
 try {
  const [a,b]=await Promise.all([independentSpeech("A retry test.","exercise"),independentSpeech("A retry test.","exercise")]);
  assert.equal(calls,2);assert.equal(a.status,200);assert.equal(b.status,200);
  assert.equal((await a.arrayBuffer()).byteLength,4);assert.equal((await b.arrayBuffer()).byteLength,4);
 } finally {globalThis.fetch=oldFetch;delete env.AZURE_SPEECH_KEY;delete env.AZURE_SPEECH_REGION;}
});
test("Azure authentication errors expose a safe code and failed audio does not use daily quota", async()=>{
 const oldFetch=globalThis.fetch,oldCaches=globalThis.caches;
 env.AZURE_SPEECH_KEY="must-not-be-returned";env.AZURE_SPEECH_REGION="eastus";setOwner("speech-auth-diagnostic");globalThis.caches=undefined;
 let calls=0;globalThis.fetch=async()=>{calls++;return new Response("must-not-be-returned",{status:401});};
 try {
  const t="An auth test.",mode="exercise",model="auto-us-v2",h=await speechCacheHash(t,mode,model);
  const response=await speechGet(new Request(`${origin}/api/speech?${new URLSearchParams({t,mode,model,h})}`));
  const body=await response.json();assert.equal(response.status,503);assert.equal(body.providerCode,"AZURE_HTTP_401");assert.equal(body.providerStatus,401);
  assert.ok(!JSON.stringify(body).includes("must-not-be-returned"));assert.equal(calls,1);
  assert.equal(sqlite.prepare("SELECT count FROM tutor_usage WHERE owner=?").get("speech:speech-auth-diagnostic").count,0);
 } finally {globalThis.fetch=oldFetch;globalThis.caches=oldCaches;delete env.AZURE_SPEECH_KEY;delete env.AZURE_SPEECH_REGION;}
});

test('v41: durable speech file bypasses Azure and quota after memory and edge caches are gone',async()=>{
 const oldFetch=globalThis.fetch,oldAudio=env.AUDIO,oldCaches=globalThis.caches;
 const objects=new Map();
 env.AUDIO={
  async put(key,bytes,options){objects.set(key,{bytes:new Uint8Array(bytes),options});},
  async get(key){const o=objects.get(key);if(!o)return null;return {body:new Response(o.bytes).body,size:o.bytes.length,customMetadata:o.options.customMetadata,writeHttpMetadata(h){h.set('Content-Type',o.options.httpMetadata.contentType);h.set('Cache-Control',o.options.httpMetadata.cacheControl);}};}
 };
 globalThis.caches=undefined;
 env.AZURE_SPEECH_KEY='test-key';env.AZURE_SPEECH_REGION='germanywestcentral';setOwner('durable-listener');
 let calls=0;
 globalThis.fetch=async()=>{calls++;return new Response(new Uint8Array([73,68,51,7,8]),{headers:{'Content-Type':'audio/mpeg'}});};
 const text='A unique durable sentence with [[gap]] in it.',model='auto-us-v2',mode='exercise',h=await speechCacheHash(text,mode,model);
 const request=()=>new Request(`${origin}/api/speech?${new URLSearchParams({t:text,model,mode,h})}`);
 try {
  const first=await speechGet(request());assert.equal(first.status,200);
  const bytes=new Uint8Array(await first.arrayBuffer());
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(objects.size,1);assert.equal(calls,1);
  const quotaBefore=sqlite.prepare("SELECT count FROM tutor_usage WHERE owner='speech:durable-listener'").get();
  globalThis.fetch=async()=>{throw new Error('Provider must not be called');};
  const second=await speechGet(request());
  assert.equal(second.status,200);assert.equal(second.headers.get('X-Speech-Cache'),'file');
  assert.deepEqual(new Uint8Array(await second.arrayBuffer()),bytes);
  assert.deepEqual(sqlite.prepare("SELECT count FROM tutor_usage WHERE owner='speech:durable-listener'").get(),quotaBefore);
 }finally{globalThis.fetch=oldFetch;globalThis.caches=oldCaches;env.AUDIO=oldAudio;delete env.AZURE_SPEECH_KEY;delete env.AZURE_SPEECH_REGION;}
});
