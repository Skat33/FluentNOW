import test from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";
import {
  alias,
  fuzzyRelation,
  inferFocusCategory,
  normalizeTopicKey,
  purgeOrphanAliases,
  put,
  resolve,
} from "../lib/shared-corpus.ts";
import { sqlite } from "./fixtures/gemini-runtime.mjs";

test("C1 normalizes Polish topic spelling without removing diacritics", () => {
  assert.equal(normalizeTopicKey("Lotnisko"), "lotnisko");
  assert.equal(normalizeTopicKey("na lotnisku"), "lotnisko");
  assert.equal(normalizeTopicKey("  lotnisko  "), "lotnisko");
  assert.notEqual(normalizeTopicKey("łódź"), normalizeTopicKey("lodz"));
});

test("C2 accepts the airport typo but does not confuse aviation with an airport", () => {
  assert.equal(fuzzyRelation("lotnsiko", "lotnisko"), "same");
  assert.equal(fuzzyRelation("lotnictwo", "lotnisko"), "none");
});

test("a narrower airport query selects only its locally matching category", async () => {
  const payload = {
    topic: "Lotnisko lokalne",
    categories: [
      {
        name: "Niezbędne dokumenty i bilety",
        items: [{ term: "passport", pl: "paszport" }],
      },
      {
        name: "Procedury i czynności",
        items: [{ term: "check-in", pl: "odprawa" }],
      },
      {
        name: "Miejsca i wygoda w samolocie",
        items: [{ term: "seat", pl: "fotel w samolocie" }],
      },
    ],
  };
  assert.equal(
    inferFocusCategory("lotnisko samolot", "Lotnisko", payload),
    "Miejsca i wygoda w samolocie",
  );
  const cacheKey = await put({
    kind: "topic",
    canonical: payload.topic,
    payload,
    model: "fixture",
    promptVer: 78,
  });
  const result = await resolve({
    query: "lotnisko lokalne check-in",
    kind: "topic",
    promptVer: 78,
    provider: {
      async list() {
        return [{
          cacheKey,
          canonical: payload.topic,
          categories: payload.categories.map((item) => item.name),
          hits: 0,
        }];
      },
    },
    semantic: async () => {
      throw new Error("semantic resolver must not be needed");
    },
  });
  assert.equal(result.source, "fuzzy");
  assert.equal(result.focusCategory, "Procedury i czynności");
});

test("an old narrower alias without a category repairs itself from cached items", async () => {
  const payload = {
    topic: "Lotnisko alias repair",
    categories: [
      { name: "Dokumenty", items: [{ term: "passport", pl: "paszport" }] },
      { name: "Procedury", items: [{ term: "check-in", pl: "odprawa" }] },
    ],
  };
  const cacheKey = await put({
    kind: "topic",
    canonical: payload.topic,
    payload,
    model: "fixture",
    promptVer: 79,
  });
  const query = "lotnisko alias repair check-in";
  await alias(query, cacheKey, "model");
  const result = await resolve({
    query,
    kind: "topic",
    promptVer: 79,
    provider: { async list() { return []; } },
  });
  assert.equal(result.source, "alias");
  assert.equal(result.focusCategory, "Procedury");
  assert.equal(
    sqlite.prepare("SELECT category FROM shared_aliases WHERE alias=?").get(
      normalizeTopicKey(query),
    ).category,
    "Procedury",
  );
});

test("C4 resolves a narrower topic and returns its focus category", async () => {
  const payload = {
    topic: "Lotnisko",
    categories: [
      { name: "Dokumenty i odprawa", items: [] },
      { name: "Bagaż", items: [] },
    ],
  };
  const cacheKey = await put({
    kind: "topic",
    canonical: payload.topic,
    payload,
    model: "fixture",
    promptVer: 77,
  });
  const provider = {
    async list() {
      return [
        {
          cacheKey,
          canonical: payload.topic,
          categories: payload.categories.map((item) => item.name),
          hits: 0,
        },
      ];
    },
  };
  const result = await resolve({
    query: "lotnisko check-in",
    kind: "topic",
    promptVer: 77,
    provider,
    semantic: async () => ({
      relation: "narrower",
      canonical: payload.topic,
      category: "Dokumenty i odprawa",
      confidence: "high",
    }),
  });
  assert.equal(result.record?.cacheKey, cacheKey);
  assert.equal(result.focusCategory, "Dokumenty i odprawa");
  assert.equal(result.source, "model");
});

test("prompt version changes invalidate aliases and orphan cleanup removes dead targets", async () => {
  const cacheKey = await put({
    kind: "topic",
    canonical: "Wersjonowany temat",
    payload: { topic: "Wersjonowany temat", categories: [] },
    model: "fixture",
    promptVer: 1,
  });
  await alias("wersjonowany alias", cacheKey, "model");
  const result = await resolve({
    query: "wersjonowany alias",
    kind: "topic",
    promptVer: 2,
    provider: { async list() { return []; } },
  });
  assert.equal(result.source, "miss");
  assert.equal(
    sqlite.prepare("SELECT alias FROM shared_aliases WHERE alias=?").get("wersjonowany alias"),
    undefined,
  );
  await alias("martwy alias", cacheKey, "model");
  sqlite.prepare("DELETE FROM shared_content WHERE cache_key=?").run(cacheKey);
  await purgeOrphanAliases();
  assert.equal(
    sqlite.prepare("SELECT alias FROM shared_aliases WHERE alias=?").get("martwy alias"),
    undefined,
  );
});

test("shared content rejects a learner State payload", async () => {
  await assert.rejects(
    put({
      kind: "topic",
      canonical: "Nie wolno",
      payload: { words: [], reviews: [], settings: {} },
      model: "fixture",
      promptVer: 1,
    }),
    /SHARED_CONTENT_CONTAINS_STATE/,
  );
});

test("the shared-content migration upgrades an existing database without losing rows", () => {
  const copy = new DatabaseSync(":memory:");
  for (let index = 0; index < 4; index++)
    copy.exec(readFileSync(`drizzle/000${index}_${[
      "first_medusa",
      "same_living_mummy",
      "massive_iron_fist",
      "dusty_ma_gnuci",
    ][index]}.sql`, "utf8"));
  copy
    .prepare("INSERT INTO learners (owner,content,revision,updated_at) VALUES (?,?,?,?)")
    .run("existing", "{}", 3, 1);
  copy.exec(readFileSync("drizzle/0004_strange_sue_storm.sql", "utf8"));
  assert.equal(
    copy.prepare("SELECT revision FROM learners WHERE owner='existing'").get().revision,
    3,
  );
  assert.ok(
    copy
      .prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='shared_content'")
      .get(),
  );
  copy.close();
});
