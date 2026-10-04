import type { Meaning } from "./learning";
export const POOL_BATCH_SIZE = 15;
export const POOL_LIMIT = 90;
export const POOL_REFILL_REMAINING = 3;
/** Publish only whole batches. Legacy meanings without enrichment remain usable. */
export function availableExampleCount(m: Meaning): number {
  if (!m.enrichment) return m.examples.length;
  const completed = (m.enrichment.round || 0) + (m.enrichment.groups.length === 3 ? 1 : 0);
  return Math.min(Math.floor(m.examples.length / POOL_BATCH_SIZE) * POOL_BATCH_SIZE, completed * POOL_BATCH_SIZE, POOL_LIMIT);
}
export function needsExampleExpansion(m: Meaning): boolean {
  if (!m.enrichment || m.enrichment.phase !== "ready") return false;
  const count = availableExampleCount(m);
  const used = new Set((m.usedExamples || []).filter(i => i >= 0 && i < count));
  return count >= POOL_BATCH_SIZE && count < POOL_LIMIT && count - used.size <= POOL_REFILL_REMAINING;
}
export function beginExampleExpansion(m: Meaning): Meaning {
  if (!needsExampleExpansion(m)) return m;
  return {...m, enrichment: {...m.enrichment!, round:(m.enrichment!.round || 0)+1, phase:"examples",groups:[],attempts:0,retryAt:0,error:undefined}};
}
export function nextUnusedExample(m: Meaning, fallback = 0): number {
  const count=availableExampleCount(m), used=new Set(m.usedExamples || []);
  for (let i=0;i<count;i++) if (!used.has(i)) return i;
  return count ? fallback % count : 0;
}
