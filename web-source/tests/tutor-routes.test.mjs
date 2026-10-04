import test from "node:test";
import assert from "node:assert/strict";
import { POST } from "../app/api/tutor/route.ts";
import {
  starterLookup,
  starterPractice,
  starterReading,
} from "../lib/tutor-local.ts";
import { env, setOwner, sqlite } from "./fixtures/gemini-runtime.mjs";
import { put as putShared, get as getShared, normalizeTopicKey } from "../lib/shared-corpus.ts";
import { TOPIC_PROMPT } from "../lib/tutor-prompts.ts";
import { starterProduction } from "../lib/production.ts";

const origin = "https://fluent.example";
const request = (body) =>
  new Request(origin + "/api/tutor", {
    method: "POST",
    headers: { "Content-Type": "application/json", origin },
    body: JSON.stringify(body),
  });

function geminiResponse(value) {
  return Response.json({
    candidates: [
      {
        finishReason: "STOP",
        content: { parts: [{ text: JSON.stringify(value) }] },
      },
    ],
  });
}

test("C: production validates input, constrains rules and reuses the shared cache", async () => {
  const original = globalThis.fetch;
  env.GEMINI_API_KEY = "production-test-key";
  setOwner("production-tests");
  let calls = 0;
  globalThis.fetch = async (_, options) => {
    calls++;
    const body = JSON.parse(options.body);
    assert.equal(body.generationConfig.maxOutputTokens,32768);
    assert.match(options.body,/past perfect continuous/);
    return geminiResponse(starterProduction("B2"));
  };
  try {
    for (const invalid of [{level:"Z1",count:4},{level:"B2",count:11},{level:"B2",count:3}])
      assert.equal((await POST(request({action:"production",...invalid}))).status,400);
    const input = {action:"production",level:"B2",count:4,topic:"Test produkcji"};
    const first = await POST(request(input));
    assert.equal(first.status,200);
    const data = await first.json();
    assert.equal(data.items.length,4);
    assert.equal(data.items[0].distractors.length,2);
    assert.equal(calls,1);
    const second = await POST(request(input));
    assert.equal((await second.json()).cached,true);
    assert.equal(calls,1);
  } finally { globalThis.fetch = original; }
});

function airportTopicList() {
  const item = (term, pl, level = "A1", spokenFrequency = "very_common") => ({
    term,
    pl,
    pos: "rzeczownik",
    level,
    spokenFrequency,
  });
  return {
    topic: "Lotnisko",
    categories: [
      {
        name: "Dokumenty i odprawa",
        items: [
          item("passport", "paszport"),
          item("boarding pass", "karta pokładowa"),
          item("check-in", "odprawa", "A2"),
          item("ticket", "bilet"),
        ],
      },
      {
        name: "Miejsca i strefy",
        items: [item("gate", "bramka"), item("terminal", "terminal")],
      },
      { name: "Bagaż", items: [item("luggage", "bagaż")] },
      { name: "Kontrola bezpieczeństwa", items: [item("security", "kontrola bezpieczeństwa")] },
      { name: "Personel i pasażerowie", items: [item("passenger", "pasażer")] },
    ],
  };
}

test("topic prefetch reads existing cache without Gemini, popularity hits or generation quota", async () => {
  const original = globalThis.fetch;
  setOwner("topic-prefetch-test");
  let calls=0;
  globalThis.fetch=async()=>{calls++;throw new Error("must not generate");};
  const topic="Lotnisko prefetch fixture";
  const key=await putShared({kind:"topic",canonical:topic,payload:airportTopicList(),model:"fixture",promptVer:TOPIC_PROMPT.version});
  const before=await getShared(key);
  try {
    const ready=await POST(request({action:"topicList",topic,cacheOnly:true}));
    assert.equal(ready.status,200);
    assert.deepEqual((await ready.json()).categories,airportTopicList().categories);
    const absent=await POST(request({action:"topicList",topic:"not a cached prefetch topic",cacheOnly:true}));
    assert.equal(absent.status,202);
    assert.deepEqual(await absent.json(),{pending:true});
    assert.equal(calls,0);
    assert.equal((await getShared(key)).hits,before.hits);
    assert.equal(sqlite.prepare("SELECT count FROM tutor_usage WHERE owner=?").get("topic-prefetch-test"),undefined);
  } finally {
    globalThis.fetch=original;
    sqlite.prepare("DELETE FROM shared_content WHERE cache_key=?").run(key);
  }
});

test("topicList returns categorized essentials, uses the large budget, and reuses the global cache", async () => {
  const oldFetch = globalThis.fetch;
  setOwner("topic-list-account");
  env.GEMINI_API_KEY = "shared-test-key";
  let calls = 0;
  globalThis.fetch = async (_url, options) => {
    calls++;
    assert.equal(options.headers["x-goog-api-key"], "shared-test-key");
    const body = JSON.parse(options.body);
    const input = JSON.parse(body.contents[0].parts[0].text);
    assert.deepEqual(input, { topic: "lotnisko test pełny" });
    assert.equal(body.generationConfig.maxOutputTokens, 32768);
    return geminiResponse(airportTopicList());
  };
  try {
    const first = await POST(
      request({ action: "topicList", topic: "lotnisko test pełny" }),
    );
    assert.equal(first.status, 200);
    const firstData = await first.json();
    const terms = firstData.categories.flatMap((category) =>
      category.items.map((item) => item.term),
    );
    for (const essential of [
      "passport",
      "boarding pass",
      "check-in",
      "gate",
      "ticket",
      "terminal",
      "luggage",
      "security",
    ])
      assert.ok(terms.includes(essential), `missing ${essential}`);
    assert.equal(firstData.cached, false);
    assert.equal(calls, 1, "topicList must not run a second CEFR audit");

    const second = await POST(
      request({ action: "topicList", topic: "  LOTNISKO TEST PEŁNY  " }),
    );
    assert.equal(second.status, 200);
    assert.equal((await second.json()).cached, true);
    assert.equal(calls, 1, "cached topic must not call Gemini");
    assert.equal(
      sqlite
        .prepare("SELECT count FROM tutor_usage WHERE owner=?")
        .get("topic-list-account").count,
      1,
      "cache hit must not consume quota",
    );
  } finally {
    globalThis.fetch = oldFetch;
    delete env.GEMINI_API_KEY;
  }
});

test("a narrower topic uses the parent category, its own resolver budget and a reusable alias", async () => {
  const oldFetch = globalThis.fetch;
  setOwner("topic-resolver-account");
  env.GEMINI_API_KEY = "shared-test-key";
  const payload = {
    topic: "Lotnisko test resolver",
    categories: [
      { name: "Dokumenty i odprawa", items: [] },
      { name: "Bagaż", items: [] },
    ],
  };
  await putShared({
    kind: "topic",
    canonical: payload.topic,
    payload,
    model: "fixture",
    promptVer: TOPIC_PROMPT.version,
  });
  let calls = 0;
  globalThis.fetch = async () => {
    calls++;
    return geminiResponse({
      relation: "narrower",
      canonical: payload.topic,
      category: "Dokumenty i odprawa",
      confidence: "high",
    });
  };
  const query = "lotnisko test resolver check-in";
  try {
    const first = await POST(request({ action: "topicList", topic: query }));
    assert.equal(first.status, 200);
    const firstData = await first.json();
    assert.equal(firstData.topic, payload.topic);
    assert.equal(
      firstData.focusCategory,
      "Dokumenty i odprawa",
      JSON.stringify(firstData),
    );
    assert.equal(firstData.matchSource, "model");
    assert.equal(firstData.cached, true);

    const second = await POST(request({ action: "topicList", topic: query }));
    assert.equal(second.status, 200);
    const secondData = await second.json();
    assert.equal(secondData.focusCategory, "Dokumenty i odprawa");
    assert.equal(secondData.matchSource, "alias");
    assert.equal(calls, 1);
    assert.equal(
      sqlite
        .prepare("SELECT count FROM tutor_usage WHERE owner=?")
        .get("resolve:topic-resolver-account").count,
      1,
    );
    assert.equal(
      sqlite
        .prepare("SELECT count FROM tutor_usage WHERE owner=?")
        .get("topic-resolver-account"),
      undefined,
    );

    const forgotten = await POST(
      request({ action: "forgetTopicAlias", topic: query }),
    );
    assert.equal(forgotten.status, 200);
    assert.equal(
      sqlite
        .prepare("SELECT alias FROM shared_aliases WHERE alias=?")
        .get(normalizeTopicKey(query)),
      undefined,
    );
  } finally {
    globalThis.fetch = oldFetch;
    delete env.GEMINI_API_KEY;
  }
});

test("lookup independently rates each sense instead of assigning one random word level", async () => {
  const oldFetch = globalThis.fetch;
  setOwner(null);
  env.GEMINI_API_KEY = "shared-test-key";
  let calls = 0;
  globalThis.fetch = async () => {
    calls++;
    if (calls === 1) return geminiResponse(starterLookup("bank"));
    return geminiResponse({
      assessments: [
        {
          itemIndex: 0,
          meaningIndex: 0,
          level: "A1",
          confidence: "high",
          spokenFrequency: "very_common",
          reason: "Podstawowe, bardzo częste znaczenie związane z pieniędzmi.",
        },
        {
          itemIndex: 0,
          meaningIndex: 1,
          level: "B2",
          confidence: "medium",
          spokenFrequency: "less_common",
          reason: "Rzadsze znaczenie zależne od kontekstu geograficznego.",
        },
      ],
    });
  };
  try {
    const response = await POST(
      request({ action: "lookup", term: "bank", collections: [] }),
    );
    assert.equal(response.status, 200);
    const data = await response.json();
    assert.deepEqual(
      data.meanings.map((meaning) => meaning.level),
      ["A1", "B2"],
    );
    assert.deepEqual(
      data.meanings.map((meaning) => meaning.levelConfidence),
      ["high", "medium"],
    );
    assert.deepEqual(
      data.meanings.map((meaning) => meaning.spokenFrequency),
      ["very_common", "less_common"],
    );
    assert.equal(calls, 2);
  } finally {
    globalThis.fetch = oldFetch;
    delete env.GEMINI_API_KEY;
  }
});

test("temporary Gemini overload refunds quota so silent retries do not consume the limit", async () => {
  const oldFetch = globalThis.fetch;
  setOwner("retry-account");
  env.GEMINI_API_KEY = "shared-test-key";
  let calls = 0;
  globalThis.fetch = async () => {
    calls++;
    return Response.json(
      {
        error: {
          status: "UNAVAILABLE",
          message: "The model is temporarily overloaded.",
        },
      },
      { status: 503 },
    );
  };
  try {
    const response = await POST(
      request({ action: "lookup", term: "bank overload fixture", collections: [] }),
    );
    assert.equal(response.status, 503);
    assert.equal(calls, 3);
    assert.equal(
      sqlite
        .prepare("SELECT count FROM tutor_usage WHERE owner=?")
        .get("retry-account").count,
      0,
    );
  } finally {
    globalThis.fetch = oldFetch;
    delete env.GEMINI_API_KEY;
  }
});

test("topicHydrate returns one audited meaning per unchanged term in batches of at most ten", async () => {
  const oldFetch = globalThis.fetch;
  setOwner("topic-hydrate-account");
  env.GEMINI_API_KEY = "shared-test-key";
  const boardingPass = structuredClone(starterLookup("boarding pass"));
  const reservation = structuredClone(starterLookup("reservation"));
  boardingPass.meanings = boardingPass.meanings.slice(0, 1);
  reservation.meanings = reservation.meanings.slice(0, 1);
  let calls = 0;
  globalThis.fetch = async (_url, options) => {
    calls++;
    const body = JSON.parse(options.body);
    const input = JSON.parse(body.contents[0].parts[0].text);
    if (calls === 1) {
      assert.equal(input.topic, "Lotnisko");
      assert.equal(input.scene, "pasażer na lotnisku przed lotem");
      assert.deepEqual(input.terms, [
        { term: "boarding pass", pl: "karta pokładowa" },
        { term: "reservation", pl: "rezerwacja" },
      ]);
      assert.equal(body.generationConfig.maxOutputTokens, 16384);
      return geminiResponse({ items: [boardingPass, reservation] });
    }
    assert.equal(input.senses.length, 2);
    return geminiResponse({
      assessments: [
        {
          itemIndex: 0,
          meaningIndex: 0,
          level: "A2",
          confidence: "high",
          spokenFrequency: "very_common",
          reason: "Podstawowe słownictwo podróżne.",
        },
        {
          itemIndex: 1,
          meaningIndex: 0,
          level: "A2",
          confidence: "high",
          spokenFrequency: "common",
          reason: "Częste słownictwo podróżne.",
        },
      ],
    });
  };
  try {
    const response = await POST(
      request({
        action: "topicHydrate",
        topic: "Lotnisko",
        scene: "pasażer na lotnisku przed lotem",
        terms: [
          { term: "boarding pass", pl: "karta pokładowa" },
          { term: "reservation", pl: "rezerwacja" },
        ],
      }),
    );
    assert.equal(response.status, 200);
    const data = await response.json();
    assert.deepEqual(
      data.items.map((item) => item.term),
      ["boarding pass", "reservation"],
    );
    assert.ok(data.items.every((item) => item.meanings.length === 1));
    assert.ok(data.items.every((item) => item.source === "ai"));
    assert.ok(
      data.items.every(
        (item) =>
          item.meanings[0].topic === "Lotnisko" &&
          item.meanings[0].scene === "pasażer na lotnisku przed lotem",
      ),
    );
    assert.equal(calls, 2);

    const invalid = await POST(
      request({
        action: "topicHydrate",
        topic: "Lotnisko",
        scene: "pasażer na lotnisku przed lotem",
        terms: Array.from({ length: 11 }, (_, index) => ({
          term: `term ${index}`,
          pl: `słowo ${index}`,
        })),
      }),
    );
    assert.equal(invalid.status, 400);
    assert.equal(calls, 2);
  } finally {
    globalThis.fetch = oldFetch;
    delete env.GEMINI_API_KEY;
  }
});

test("recontextualize validates input and returns exactly two scene-bound pairs", async () => {
  const oldFetch = globalThis.fetch;
  setOwner("recontextualize-account");
  env.GEMINI_API_KEY = "shared-test-key";
  let calls = 0;
  globalThis.fetch = async (_url, options) => {
    calls++;
    const body = JSON.parse(options.body);
    const input = JSON.parse(body.contents[0].parts[0].text);
    assert.equal(input.meaningId, "meaning-1");
    assert.equal(input.term, "gate");
    assert.equal(input.translation, "bramka");
    assert.equal(input.scene, "pasażer czeka przy bramce przed odlotem");
    return geminiResponse({
      examples: [
        {
          en: "The passenger waits at gate twelve before boarding.",
          pl: "Pasażer czeka przy bramce numer dwanaście przed wejściem na pokład.",
          focusEn: "gate",
          focusPl: "bramce",
        },
        {
          en: "An agent checks his boarding pass at the gate.",
          pl: "Pracownik sprawdza jego kartę pokładową przy bramce.",
          focusEn: "gate",
          focusPl: "bramce",
        },
      ],
    });
  };
  try {
    const response = await POST(
      request({
        action: "recontextualize",
        meaningId: "meaning-1",
        term: "gate",
        translation: "bramka",
        scene: "pasażer czeka przy bramce przed odlotem",
      }),
    );
    assert.equal(response.status, 200);
    assert.equal((await response.json()).examples.length, 2);

    const invalid = await POST(
      request({
        action: "recontextualize",
        meaningId: "meaning-1",
        term: "gate",
        translation: "bramka",
        scene: "",
      }),
    );
    assert.equal(invalid.status, 400);
    assert.equal(calls, 1);
  } finally {
    globalThis.fetch = oldFetch;
    delete env.GEMINI_API_KEY;
  }
});

test("reading sends the topic and scene that constrain the whole passage", async () => {
  const oldFetch = globalThis.fetch;
  setOwner("reading-context-account");
  env.GEMINI_API_KEY = "shared-test-key";
  const starter = starterReading("B1", []);
  globalThis.fetch = async (_url, options) => {
    const body = JSON.parse(options.body);
    const input = JSON.parse(body.contents[0].parts[0].text);
    assert.equal(input.topic, "Lotnisko");
    assert.equal(input.scene, "pasażer na lotnisku przed lotem");
    const reading = structuredClone(starter);
    delete reading.id;
    delete reading.source;
    return geminiResponse(reading);
  };
  try {
    const response = await POST(
      request({
        action: "reading",
        level: "B1",
        topic: "Lotnisko",
        scene: "pasażer na lotnisku przed lotem",
        words: [
          {
            en: "boarding pass",
            meaningId: "meaning-boarding-pass",
            translation: "karta pokładowa",
            level: "A2",
          },
        ],
        previousTitles: [],
      }),
    );
    assert.equal(response.status, 200);
    assert.equal((await response.json()).source, "ai");
  } finally {
    globalThis.fetch = oldFetch;
    delete env.GEMINI_API_KEY;
  }
});

test("practice route validates grammar, idiom and mixed sets", async () => {
  const oldFetch = globalThis.fetch;
  setOwner("practice-account");
  env.GEMINI_API_KEY = "shared-test-key";
  globalThis.fetch = async (_url, options) => {
    const body = JSON.parse(options.body);
    const input = JSON.parse(body.contents[0].parts[0].text);
    assert.equal(input.topic, "Lotnisko");
    assert.equal(input.scene, "pasażer na lotnisku przed lotem");
    const set = structuredClone(starterPractice("mixed", "B1"));
    delete set.id;
    delete set.source;
    return geminiResponse(set);
  };
  try {
    const response = await POST(
      request({
        action: "practice",
        kind: "mixed",
        level: "B1",
        topic: "Lotnisko",
        scene: "pasażer na lotnisku przed lotem",
        vocabulary: [{ en: "lend", translation: "pożyczyć komuś" }],
      }),
    );
    assert.equal(response.status, 200);
    const data = await response.json();
    assert.equal(data.kind, "mixed");
    assert.equal(data.items.length, 6);
    assert.equal(data.source, "ai");
  } finally {
    globalThis.fetch = oldFetch;
    delete env.GEMINI_API_KEY;
  }
});

test("meaningExamples validates input and returns five scene-bound examples per kind with a reusable cache",async()=>{
 const original=globalThis.fetch;
 setOwner("examples-v34");env.GEMINI_API_KEY="examples-test-key";
 let calls=0;
 globalThis.fetch=async(url,options)=>{
  calls++;
  const body=JSON.parse(options.body),p=JSON.parse(body.contents[0].parts[0].text);
  assert.equal(body.generationConfig.maxOutputTokens,4096);
  assert.equal(p.scene,"At an airport check-in desk");
  const sentences={affirmative:i=>`The agent checks passport number ${i} at the desk.`,negative:i=>`The agent does not check passport number ${i} at the desk.`,question:i=>`Does the agent check passport number ${i} at the desk?`};
  return geminiResponse({examples:Array.from({length:5},(_,i)=>({en:sentences[p.kind](i),pl:`Paszport ${i} przy stanowisku odprawy.`,focusEn:"passport",focusPl:"Paszport"}))});
 };
 try {
  const input={action:"meaningExamples",term:"passport",translation:"paszport",topic:"Lotnisko v34",scene:"At an airport check-in desk",level:"A1",kind:"affirmative",avoid:[]};
  for(const change of [{kind:"bad"},{level:"Z1"},{term:""},{avoid:Array(91).fill("example")}]) assert.equal((await POST(request({...input,...change}))).status,400);
  for(const kind of ["affirmative","negative","question"]) {
   const response=await POST(request({...input,kind}));assert.equal(response.status,200);assert.equal((await response.json()).examples.length,5);
   assert.equal((await POST(request({...input,kind}))).status,200);
  }
  assert.equal(calls,3,"no CEFR audit or model call on an example cache hit");
 } finally {globalThis.fetch=original;delete env.GEMINI_API_KEY;}
});

test("meaningExamples rejects duplicates, bad highlights and a wrong sentence kind",async()=>{
 const original=globalThis.fetch;setOwner("examples-v34-invalid");env.GEMINI_API_KEY="examples-test-key";
 const input={action:"meaningExamples",term:"gate",translation:"bramka",scene:"At the gate",level:"A1",kind:"question"};
 globalThis.fetch=async()=>geminiResponse({examples:Array.from({length:5},(_,i)=>({en:`Gate number ${i} is open.`,pl:`Bramka numer ${i} jest otwarta.`,focusEn:"Gate",focusPl:"Bramka"}))});
 try {assert.equal((await POST(request(input))).status,502);} finally{globalThis.fetch=original;delete env.GEMINI_API_KEY;}
});

import { preparePoolBatch, poolIdentity } from "../lib/example-pool-store.ts";
test("v35 durable pool reuses 90 sentences across accounts, validates bounds and never expires",async()=>{
 const original=globalThis.fetch;env.GEMINI_API_KEY="pool-test-key";setOwner("pool-owner-A");
 let calls=0;
 globalThis.fetch=async(_,options)=>{
  calls++;const p=JSON.parse(JSON.parse(options.body).contents[0].parts[0].text);
  assert.equal(p.avoid.length,(p.round*3+["affirmative","negative","question"].indexOf(p.kind))*5);
  return geminiResponse({examples:Array.from({length:5},(_,i)=>({en:p.kind==="question" ? `Is ticket ${p.round}-${i} valid?` : p.kind==="negative" ? `Ticket ${p.round}-${i} is not valid.` : `Ticket ${p.round}-${i} is valid.`,pl:`Bilet ${p.round}-${i} ma opis ${p.kind}.`,focusEn:p.kind==="question" ? "ticket" : "Ticket",focusPl:"Bilet"}))});
 };
 const input={action:"meaningExamples",term:"ticket",translation:"bilet v35",level:"A1"};
 try {
  for (const round of [-1,6,1.5]) assert.equal((await POST(request({...input,kind:"affirmative",round}))).status,400);
  for(let round=0;round<6;round++) for(const kind of ["affirmative","negative","question"]) {
   const r=await POST(request({...input,round,kind}));assert.equal(r.status,200);assert.equal((await r.json()).examples.length,5);
  }
  assert.equal(calls,18);
  sqlite.exec("UPDATE example_pools SET updated=1");
  setOwner("pool-owner-B");delete env.GEMINI_API_KEY;
  for(let round=0;round<6;round++) for(const kind of ["affirmative","negative","question"]) {
   const r=await POST(request({...input,round,kind}));assert.equal(r.status,200);assert.equal((await r.json()).cached,true);
  }
  assert.equal(calls,18,"no AI even with an unavailable provider after completing the pool");
  assert.equal(sqlite.prepare("SELECT count FROM tutor_usage WHERE owner=?").get("pool-owner-B"),undefined);
 } finally {globalThis.fetch=original;delete env.GEMINI_API_KEY;}
});

test("v35 pool lease coalesces concurrent generation; errors unlock and custom scenes stay private",async()=>{
 const p={term:"claim",translation:"odebrać",level:"B1",topic:"test lease"};
 let release;const gate=new Promise(r=>release=r);let entered;const started=new Promise(r=>entered=r);
 const batch={examples:Array.from({length:5},(_,i)=>({en:`I claim bag ${i}.`,pl:`Odbieram bagaż ${i}.`,focusEn:"claim",focusPl:"Odbieram"}))};
 let calls=0;
 const first=preparePoolBatch(p,"A",0,"affirmative",async()=>{calls++;entered();await gate;return batch;});
 await started;
 const second=await preparePoolBatch(p,"B",0,"affirmative",async()=>{calls++;return batch;});
 assert.deepEqual(second,{pending:true});release();await first;
 assert.equal(calls,1);
 await assert.rejects(()=>preparePoolBatch(p,"A",0,"negative",async()=>batch),/INCOMPLETE/);
 const identity=await poolIdentity(p,"A");
 assert.equal(sqlite.prepare("SELECT lease_until FROM example_pools WHERE pool_key=?").get(identity.key).lease_until,0);
 const privateScene={...p,scene:"My confidential work conversation"};
 assert.notEqual((await poolIdentity(privateScene,"A")).key,(await poolIdentity(privateScene,"B")).key);
 assert.notEqual((await poolIdentity(p,"A")).key,(await poolIdentity({...p,translation:"twierdzić"},"A")).key);
 assert.equal((await poolIdentity({...p,level:"B2"},"B")).key,identity.key,"small CEFR changes must not regenerate the same meaning pool");
});


test("v39 personalized reading cache is durable, owner-scoped and avoids repeated generation",async()=>{
 const oldFetch=globalThis.fetch;env.GEMINI_API_KEY="reading-cache-test";setOwner("reading-cache-a");let calls=0;
 globalThis.fetch=async()=>{calls++;const r=starterReading("B2");delete r.id;delete r.source;return geminiResponse(r);};
 const body={action:"reading",level:"B2",words:[],previousTitles:[],variant:77};
 try {
  const first=await (await POST(request(body))).json();assert.equal(first.cached,false);
  const again=await (await POST(request(body))).json();assert.equal(again.cached,true);assert.equal(again.id,first.id);assert.equal(calls,1);
  setOwner("reading-cache-b");const other=await (await POST(request(body))).json();assert.equal(other.cached,false);assert.notEqual(other.id,first.id);assert.equal(calls,2);
 }finally{globalThis.fetch=oldFetch;delete env.GEMINI_API_KEY;}
});
