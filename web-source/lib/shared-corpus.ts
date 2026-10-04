import { database } from "@/db/store";

export type SharedKind = "topic" | "lookup" | "grammar" | "reading";
export type ResolutionSource = "exact" | "alias" | "fuzzy" | "model" | "miss";

export type SharedRecord<T = unknown> = {
  cacheKey: string;
  kind: SharedKind;
  canonical: string;
  payload: T;
  model: string;
  promptVer: number;
  created: number;
  refreshed: number;
  hits: number;
  stale: boolean;
};

export type TopicCandidate = {
  cacheKey: string;
  canonical: string;
  categories: string[];
  hits: number;
};

export interface TopicCandidateProvider {
  list(limit: number): Promise<TopicCandidate[]>;
}

export type CanonicalDecision = {
  relation: "same" | "narrower" | "new";
  canonical: string;
  category: string;
  confidence: "high" | "low";
};

export type Resolution<T = unknown> = {
  record?: SharedRecord<T>;
  source: ResolutionSource;
  focusCategory?: string;
  canonical?: string;
  promotion?: boolean;
};

const STALE_AFTER = 90 * 24 * 60 * 60 * 1000;
const MAX_SHARED_PAYLOAD_BYTES = 1_800_000;
const LEADING_POLISH_PREPOSITIONS = new Set([
  "na",
  "w",
  "we",
  "o",
  "do",
  "przy",
  "z",
  "ze",
]);
const FORBIDDEN_STATE_KEYS = new Set([
  "reviews",
  "settings",
  "session",
  "readingHistory",
  "practiceHistory",
  "demo",
  "revision",
]);

export function normalizeTopicKey(input: string) {
  const tokens = input
    .normalize("NFKC")
    .trim()
    .toLocaleLowerCase("pl-PL")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .replace(/\s+/g, " ")
    .trim()
    .split(" ")
    .filter(Boolean);
  while (tokens.length > 1 && LEADING_POLISH_PREPOSITIONS.has(tokens[0]))
    tokens.shift();
  // The productive -isko/-isku locative is safe here and makes the required
  // "na lotnisku" equivalence deterministic without stripping diacritics.
  for (let index = 0; index < tokens.length; index++)
    if (tokens[index].endsWith("isku"))
      tokens[index] = `${tokens[index].slice(0, -4)}isko`;
  return tokens.join(" ");
}

export function sharedCacheKey(
  kind: SharedKind,
  canonical: string,
  promptVer: number,
) {
  return `${kind}:${normalizeTopicKey(canonical)}:v${promptVer}`;
}

function assertReusableLanguageContent(payload: unknown) {
  if (!payload || typeof payload !== "object") return;
  if ("words" in payload)
    throw new Error("SHARED_CONTENT_CONTAINS_STATE");
  const visit = (value: unknown) => {
    if (!value || typeof value !== "object") return;
    for (const [key, child] of Object.entries(value)) {
      if (FORBIDDEN_STATE_KEYS.has(key))
        throw new Error("SHARED_CONTENT_CONTAINS_STATE");
      visit(child);
    }
  };
  visit(payload);
}

function rowToRecord<T>(row: Record<string, unknown>): SharedRecord<T> {
  const refreshed = Number(row.refreshed);
  return {
    cacheKey: String(row.cache_key),
    kind: String(row.kind) as SharedKind,
    canonical: String(row.canonical),
    payload: JSON.parse(String(row.payload)) as T,
    model: String(row.model),
    promptVer: Number(row.prompt_ver),
    created: Number(row.created),
    refreshed,
    hits: Number(row.hits),
    stale: Date.now() - refreshed > STALE_AFTER,
  };
}

export async function get<T>(cacheKey: string, countHit = false) {
  const row = await database()
    .prepare("SELECT * FROM shared_content WHERE cache_key=?")
    .bind(cacheKey)
    .first<Record<string, unknown>>();
  if (!row) return null;
  if (countHit)
    await database()
      .prepare("UPDATE shared_content SET hits=hits+1 WHERE cache_key=?")
      .bind(cacheKey)
      .run();
  const record = rowToRecord<T>(row);
  if (countHit) record.hits++;
  return record;
}

export async function put(input: {
  kind: SharedKind;
  canonical: string;
  payload: unknown;
  model: string;
  promptVer: number;
  cacheKey?: string;
}) {
  assertReusableLanguageContent(input.payload);
  const payload = JSON.stringify(input.payload);
  if (new TextEncoder().encode(payload).byteLength > MAX_SHARED_PAYLOAD_BYTES)
    throw new Error("SHARED_CONTENT_TOO_LARGE");
  const now = Date.now();
  const cacheKey =
    input.cacheKey ||
    sharedCacheKey(input.kind, input.canonical, input.promptVer);
  await database()
    .prepare(
      "INSERT INTO shared_content (cache_key,kind,canonical,payload,model,prompt_ver,created,refreshed,hits) VALUES (?,?,?,?,?,?,?,?,0) ON CONFLICT(cache_key) DO UPDATE SET canonical=excluded.canonical,payload=excluded.payload,model=excluded.model,prompt_ver=excluded.prompt_ver,refreshed=excluded.refreshed",
    )
    .bind(
      cacheKey,
      input.kind,
      input.canonical,
      payload,
      input.model,
      input.promptVer,
      now,
      now,
    )
    .run();
  await purgeOrphanAliases();
  return cacheKey;
}

export async function alias(
  query: string,
  cacheKey: string,
  source: Exclude<ResolutionSource, "exact" | "alias" | "miss"> | "exact",
  category?: string,
) {
  const normalized = normalizeTopicKey(query);
  if (!normalized) return;
  await database()
    .prepare(
      "INSERT INTO shared_aliases (alias,cache_key,category,source,created,hits) VALUES (?,?,?,?,?,0) ON CONFLICT(alias) DO UPDATE SET cache_key=excluded.cache_key,category=excluded.category,source=excluded.source,created=excluded.created,hits=0",
    )
    .bind(normalized, cacheKey, category || null, source, Date.now())
    .run();
}

export async function removeAlias(query: string) {
  await database()
    .prepare("DELETE FROM shared_aliases WHERE alias=?")
    .bind(normalizeTopicKey(query))
    .run();
}

export async function purgeOrphanAliases() {
  await database()
    .prepare(
      "DELETE FROM shared_aliases WHERE cache_key NOT IN (SELECT cache_key FROM shared_content)",
    )
    .run();
}

async function logResolution(
  query: string,
  layer: ResolutionSource,
  cacheKey?: string,
) {
  await database()
    .prepare(
      "INSERT INTO shared_resolution_log (query,normalized,layer,cache_key,created) VALUES (?,?,?,?,?)",
    )
    .bind(query.slice(0, 500), normalizeTopicKey(query), layer, cacheKey || null, Date.now())
    .run();
}

export class SqlTopicCandidateProvider implements TopicCandidateProvider {
  async list(limit: number) {
    const result = await database()
      .prepare(
        "SELECT cache_key,canonical,payload,hits FROM shared_content WHERE kind='topic' ORDER BY hits DESC,refreshed DESC LIMIT ?",
      )
      .bind(Math.min(200, limit))
      .all<Record<string, unknown>>();
    return result.results.map((row) => {
      let categories: string[] = [];
      try {
        const payload = JSON.parse(String(row.payload));
        categories = Array.isArray(payload.categories)
          ? payload.categories
              .map((item: unknown) =>
                item && typeof item === "object" && "name" in item
                  ? String(item.name)
                  : "",
              )
              .filter(Boolean)
          : [];
      } catch {
        // Invalid legacy rows are ignored by the semantic resolver.
      }
      return {
        cacheKey: String(row.cache_key),
        canonical: String(row.canonical),
        categories,
        hits: Number(row.hits),
      };
    });
  }
}

function tokenCoverage(left: string, right: string) {
  const a = new Set(left.split(" ").filter(Boolean));
  const b = new Set(right.split(" ").filter(Boolean));
  const common = [...a].filter((token) => b.has(token)).length;
  return {
    left: a.size ? common / a.size : 0,
    right: b.size ? common / b.size : 0,
    allCandidateTokens: b.size > 0 && common === b.size,
  };
}

function trigrams(value: string) {
  const padded = `  ${value}  `;
  const grams = new Set<string>();
  for (let index = 0; index <= padded.length - 3; index++)
    grams.add(padded.slice(index, index + 3));
  return grams;
}

function trigramSimilarity(left: string, right: string) {
  const a = trigrams(left), b = trigrams(right);
  const common = [...a].filter((gram) => b.has(gram)).length;
  return (2 * common) / (a.size + b.size || 1);
}

function damerauSimilarity(left: string, right: string) {
  const rows = left.length + 1, columns = right.length + 1;
  const matrix = Array.from({ length: rows }, () => Array(columns).fill(0));
  for (let i = 0; i < rows; i++) matrix[i][0] = i;
  for (let j = 0; j < columns; j++) matrix[0][j] = j;
  for (let i = 1; i < rows; i++)
    for (let j = 1; j < columns; j++) {
      const cost = left[i - 1] === right[j - 1] ? 0 : 1;
      matrix[i][j] = Math.min(
        matrix[i - 1][j] + 1,
        matrix[i][j - 1] + 1,
        matrix[i - 1][j - 1] + cost,
      );
      if (
        i > 1 &&
        j > 1 &&
        left[i - 1] === right[j - 2] &&
        left[i - 2] === right[j - 1]
      )
        matrix[i][j] = Math.min(matrix[i][j], matrix[i - 2][j - 2] + cost);
    }
  return 1 - matrix[left.length][right.length] / Math.max(left.length, right.length, 1);
}

const CATEGORY_MATCH_STOPWORDS = new Set([
  ...LEADING_POLISH_PREPOSITIONS,
  "i",
  "a",
  "oraz",
  "and",
  "the",
  "in",
  "at",
  "on",
]);

function topicPayloadCategories(payload: unknown) {
  if (!payload || typeof payload !== "object" || !("categories" in payload))
    return [];
  const categories = (payload as { categories?: unknown }).categories;
  if (!Array.isArray(categories)) return [];
  return categories.flatMap((category) => {
    if (!category || typeof category !== "object" || !("name" in category))
      return [];
    const value = category as { name?: unknown; items?: unknown };
    if (typeof value.name !== "string" || !value.name.trim()) return [];
    const items = Array.isArray(value.items) ? value.items : [];
    const itemText = items
      .flatMap((item) => {
        if (!item || typeof item !== "object") return [];
        const record = item as { term?: unknown; pl?: unknown };
        return [record.term, record.pl].filter(
          (entry): entry is string => typeof entry === "string",
        );
      })
      .join(" ");
    return [{ name: value.name, itemText }];
  });
}

function tokenAffinity(queryToken: string, candidateToken: string, inName: boolean) {
  if (queryToken === candidateToken) return inName ? 6 : 3;
  if (queryToken.length < 4 || candidateToken.length < 4) return 0;
  const similarity = damerauSimilarity(queryToken, candidateToken);
  const threshold = inName ? 0.65 : 0.78;
  return similarity >= threshold ? similarity * (inName ? 6 : 3) : 0;
}

export function inferFocusCategory(
  query: string,
  canonical: string,
  payload: unknown,
) {
  const canonicalTokens = new Set(normalizeTopicKey(canonical).split(" "));
  const extraTokens = normalizeTopicKey(query)
    .split(" ")
    .filter(
      (token) =>
        token &&
        !canonicalTokens.has(token) &&
        !CATEGORY_MATCH_STOPWORDS.has(token),
    );
  if (!extraTokens.length) return undefined;

  const ranked = topicPayloadCategories(payload)
    .map((category) => {
      const nameTokens = normalizeTopicKey(category.name).split(" ");
      const itemTokens = normalizeTopicKey(category.itemText).split(" ");
      const tokenScores = extraTokens.map((token) =>
        Math.max(
          ...nameTokens.map((candidate) => tokenAffinity(token, candidate, true)),
          ...itemTokens.map((candidate) => tokenAffinity(token, candidate, false)),
          0,
        ),
      );
      return {
        name: category.name,
        score: tokenScores.reduce((sum, score) => sum + score, 0),
        matched: tokenScores.filter((score) => score > 0).length,
      };
    })
    .filter((category) => category.matched === extraTokens.length)
    .sort((left, right) => right.score - left.score);
  if (!ranked.length || ranked[0].score < 3) return undefined;
  if (ranked[1] && ranked[0].score - ranked[1].score < 0.75) return undefined;
  return ranked[0].name;
}

export function fuzzyRelation(query: string, candidate: string) {
  const normalizedQuery = normalizeTopicKey(query);
  const normalizedCandidate = normalizeTopicKey(candidate);
  const coverage = tokenCoverage(normalizedQuery, normalizedCandidate);
  const similarity = Math.max(
    trigramSimilarity(normalizedQuery, normalizedCandidate),
    damerauSimilarity(normalizedQuery, normalizedCandidate),
  );
  if (coverage.left >= 0.85 && coverage.right >= 0.85)
    return "same" as const;
  if (
    coverage.allCandidateTokens &&
    normalizedQuery.split(" ").length > normalizedCandidate.split(" ").length
  )
    return "narrower" as const;
  if (similarity >= 0.8) return "same" as const;
  return "none" as const;
}

export async function resolve<T>(input: {
  query: string;
  kind: SharedKind;
  promptVer: number;
  forceFresh?: boolean;
  provider?: TopicCandidateProvider;
  semantic?: (
    query: string,
    candidates: TopicCandidate[],
  ) => Promise<CanonicalDecision>;
}): Promise<Resolution<T>> {
  const normalized = normalizeTopicKey(input.query);
  if (normalized.length < 3) throw new Error("TOPIC_TOO_SHORT");
  if (input.forceFresh) {
    await logResolution(input.query, "miss");
    return { source: "miss", canonical: normalized };
  }
  const exactKey = sharedCacheKey(input.kind, normalized, input.promptVer);
  const exact = await get<T>(exactKey, true);
  if (exact) {
    await logResolution(input.query, "exact", exactKey);
    return { record: exact, source: "exact", canonical: exact.canonical };
  }
  const aliasRow = await database()
    .prepare("SELECT * FROM shared_aliases WHERE alias=?")
    .bind(normalized)
    .first<Record<string, unknown>>();
  if (aliasRow) {
    const record = await get<T>(String(aliasRow.cache_key), true);
    if (record && record.kind === input.kind && record.promptVer === input.promptVer) {
      const hits = Number(aliasRow.hits) + 1;
      let category = aliasRow.category ? String(aliasRow.category) : undefined;
      if (
        !category &&
        input.kind === "topic" &&
        fuzzyRelation(normalized, record.canonical) === "narrower"
      ) {
        category = inferFocusCategory(input.query, record.canonical, record.payload);
        if (category)
          await database()
            .prepare("UPDATE shared_aliases SET category=? WHERE alias=?")
            .bind(category, normalized)
            .run();
      }
      if (category && hits >= 20) {
        await removeAlias(input.query);
        await logResolution(input.query, "miss");
        return { source: "miss", canonical: normalized, promotion: true };
      }
      await database()
        .prepare("UPDATE shared_aliases SET hits=hits+1 WHERE alias=?")
        .bind(normalized)
        .run();
      await logResolution(input.query, "alias", record.cacheKey);
      return {
        record,
        source: "alias",
        canonical: record.canonical,
        focusCategory: category,
      };
    }
    await removeAlias(input.query);
  }

  if (input.kind !== "topic") {
    await logResolution(input.query, "miss");
    return { source: "miss", canonical: normalized };
  }

  const provider = input.provider || new SqlTopicCandidateProvider();
  const candidates = await provider.list(200);
  const narrower: TopicCandidate[] = [];
  for (const candidate of candidates) {
    const relation = fuzzyRelation(normalized, candidate.canonical);
    if (relation === "same") {
      const record = await get<T>(candidate.cacheKey, true);
      if (!record) continue;
      await alias(input.query, candidate.cacheKey, "fuzzy");
      await logResolution(input.query, "fuzzy", candidate.cacheKey);
      return {
        record,
        source: "fuzzy",
        canonical: record.canonical,
      };
    }
    if (relation === "narrower") {
      const preview = await get<T>(candidate.cacheKey);
      const focusCategory = preview
        ? inferFocusCategory(input.query, candidate.canonical, preview.payload)
        : undefined;
      if (focusCategory) {
        const record = await get<T>(candidate.cacheKey, true);
        if (!record) continue;
        await alias(input.query, candidate.cacheKey, "fuzzy", focusCategory);
        await logResolution(input.query, "fuzzy", candidate.cacheKey);
        return {
          record,
          source: "fuzzy",
          canonical: record.canonical,
          focusCategory,
        };
      }
      narrower.push(candidate);
    }
  }

  if (input.semantic && candidates.length) {
    const decision = await input.semantic(input.query, [
      ...narrower,
      ...candidates.filter((candidate) => !narrower.includes(candidate)),
    ].slice(0, 200));
    if (decision.confidence === "high" && decision.relation !== "new") {
      const candidate = candidates.find(
        (item) =>
          normalizeTopicKey(item.canonical) === normalizeTopicKey(decision.canonical),
      );
      if (candidate) {
        const record = await get<T>(candidate.cacheKey, true);
        if (record) {
          const focusCategory =
            decision.relation === "narrower" &&
            candidate.categories.includes(decision.category)
              ? decision.category
              : undefined;
          await alias(input.query, candidate.cacheKey, "model", focusCategory);
          await logResolution(input.query, "model", candidate.cacheKey);
          return {
            record,
            source: "model",
            canonical: record.canonical,
            focusCategory,
          };
        }
      }
    }
    if (decision.confidence === "high" && decision.relation === "new") {
      await logResolution(input.query, "miss");
      return { source: "miss", canonical: decision.canonical };
    }
  }
  await logResolution(input.query, "miss");
  return { source: "miss", canonical: normalized };
}

export async function popularTopics(limit = 8) {
  const result = await database()
    .prepare(
      "SELECT canonical,hits FROM shared_content WHERE kind='topic' ORDER BY hits DESC,refreshed DESC LIMIT ?",
    )
    .bind(Math.min(25, Math.max(1, limit)))
    .all<{ canonical: string; hits: number }>();
  return result.results;
}
