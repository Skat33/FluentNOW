import { database } from "@/db/store";
export const DAILY_TUTOR_LIMIT = 200;
export const DAILY_SPEECH_LIMIT = 400;
export const DAILY_RESOLUTION_LIMIT = 80;
const CEFR_LEVELS = ["A1", "A2", "B1", "B2", "C1", "C2"];

export function nearbyLevel(expected: string, actual: string) {
  const expectedIndex = CEFR_LEVELS.indexOf(expected),
    actualIndex = CEFR_LEVELS.indexOf(actual);
  return (
    expectedIndex >= 0 &&
    actualIndex >= 0 &&
    Math.abs(expectedIndex - actualIndex) <= 1
  );
}

export async function quotaOwner(
  authenticatedId: string | null,
  request?: Request,
) {
  if (authenticatedId) return authenticatedId;
  const fingerprint = [
    request?.headers.get("cf-connecting-ip") ||
      request?.headers.get("x-forwarded-for")?.split(",")[0] ||
      "private-site",
    request?.headers.get("user-agent") || "browser",
  ]
    .join("|")
    .slice(0, 1000);
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(fingerprint),
  );
  return (
    "guest:" +
    [...new Uint8Array(digest)]
      .slice(0, 16)
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("")
  );
}

async function consumeQuota(owner: string, limit: number, errorCode: string) {
  const day = new Date().toISOString().slice(0, 10);
  const result = await database()
    .prepare(
      "INSERT INTO tutor_usage (owner,day,count) VALUES (?,?,1) ON CONFLICT(owner) DO UPDATE SET day=excluded.day,count=CASE WHEN tutor_usage.day=excluded.day THEN tutor_usage.count+1 ELSE 1 END WHERE tutor_usage.day<>excluded.day OR tutor_usage.count<?",
    )
    .bind(owner, day, limit)
    .run();
  if (!result.meta.changes) throw new Error(errorCode);
}

export async function quota(owner: string) {
  return consumeQuota(owner, DAILY_TUTOR_LIMIT, "APP_LIMIT");
}

export async function speechQuota(owner: string) {
  return consumeQuota(`speech:${owner}`, DAILY_SPEECH_LIMIT, "SPEECH_LIMIT");
}

export async function resolutionQuota(owner: string) {
  return consumeQuota(`resolve:${owner}`, DAILY_RESOLUTION_LIMIT, "RESOLVE_LIMIT");
}

export async function refundQuota(owner: string) {
  const day = new Date().toISOString().slice(0, 10);
  await database()
    .prepare(
      "UPDATE tutor_usage SET count=CASE WHEN count>0 THEN count-1 ELSE 0 END WHERE owner=? AND day=?",
    )
    .bind(owner, day)
    .run();
}

export async function quotaStatus(owner: string) {
  const day = new Date().toISOString().slice(0, 10);
  const row = await database()
    .prepare("SELECT day,count FROM tutor_usage WHERE owner=?")
    .bind(owner)
    .first<{ day: string; count: number }>();
  const used = row?.day === day ? row.count : 0;
  return {
    limit: DAILY_TUTOR_LIMIT,
    used,
    remaining: Math.max(0, DAILY_TUTOR_LIMIT - used),
  };
}
