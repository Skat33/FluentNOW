import type { State } from "./learning";

const DATABASE = "fluent-offline";
const STORE = "pending";
const KEY = "latest-state";

export function compactReviews(state: State, now = Date.now()): State {
  const next = structuredClone(state);
  const cutoff = now - 90 * 86400000;
  const summaries = new Map(
    (next.reviewSummaries || []).map((item) => [item.day, { ...item }]),
  );
  const recent = [];
  for (const review of next.reviews) {
    if (review.at >= cutoff) {
      recent.push(review);
      continue;
    }
    if (review.demo) continue;
    const day = new Date(review.at).toISOString().slice(0, 10);
    const summary = summaries.get(day) || { day, count: 0, correct: 0 };
    summary.count++;
    summary.correct += review.correct && !review.hint ? 1 : 0;
    summaries.set(day, summary);
  }
  next.reviews = recent;
  next.reviewSummaries = [...summaries.values()].sort((a, b) =>
    a.day.localeCompare(b.day),
  );
  return next;
}

export function mergeStates(local: State, remote: State): State {
  const a=local.combined,b=remote.combined;
  // A clock tie must not replace already checked answers with an older snapshot.
  const combined=a?.id===b?.id && a && b
    ? (a.index!==b.index ? a.index>b.index?a:b
      : a.answers.filter(Boolean).length!==b.answers.filter(Boolean).length
        ? a.answers.filter(Boolean).length>b.answers.filter(Boolean).length?a:b
        : a.updatedAt>=b.updatedAt?a:b)
    : (a?.updatedAt || 0)>=(b?.updatedAt || 0)?a || b || null:b || null;
  const productionHistory = new Map((remote.productionHistory || []).map((item) => [item.id, item]));
  for (const item of local.productionHistory || []) productionHistory.set(item.id, item);
  const words = new Map(remote.words.map((word) => [word.id, word]));
  for (const word of local.words) {
    const saved = words.get(word.id);
    if (!saved) { words.set(word.id,word); continue; }
    const winner=(word.updatedAt || word.created)>=(saved.updatedAt || saved.created) ? word : saved;
    const other=winner===word ? saved : word;
    words.set(word.id,{...winner,meanings:winner.meanings.map(m=>{
      const previous=other.meanings.find(x=>x.id===m.id);
      if (!previous || winner.en!==other.en || m.translation!==previous.translation || m.topic!==previous.topic || m.scene!==previous.scene) return m;
      const larger=m.examples.length>=previous.examples.length ? m : previous;
      const smaller=larger===m ? previous : m;
      if (!smaller.examples.every((text,i)=>larger.examples[i]===text)) return m;
      const used=[...new Set([...(m.usedExamples || []),...(previous.usedExamples || [])])].filter(i=>i<larger.examples.length);
      // A newer review must not discard a bank batch saved on another device.
      const bank=m.enrichment && previous.enrichment ? {
        examples:larger.examples,exampleTranslations:larger.exampleTranslations,
        exampleFocusEn:larger.exampleFocusEn,exampleFocusPl:larger.exampleFocusPl,
        enrichment:larger.enrichment,
      } : {};
      return {...m,...bank,...(used.length ? {usedExamples:used} : {})};
    })});
  }
  const reviews = new Map(remote.reviews.map((review) => [review.id, review]));
  for (const review of local.reviews) reviews.set(review.id, review);
  const readingHistory = new Map(
    (remote.readingHistory || []).map((item) => [item.id, item]),
  );
  for (const item of local.readingHistory || [])
    readingHistory.set(item.id, item);
  const practiceHistory = new Map(
    (remote.practiceHistory || []).map((item) => [item.id, item]),
  );
  for (const item of local.practiceHistory || [])
    practiceHistory.set(item.id, item);
  const summaries = new Map(
    (remote.reviewSummaries || []).map((item) => [item.day, item]),
  );
  for (const item of local.reviewSummaries || []) {
    const saved = summaries.get(item.day);
    summaries.set(item.day, {
      day: item.day,
      count: Math.max(item.count, saved?.count || 0),
      correct: Math.max(item.correct, saved?.correct || 0),
    });
  }
  return {
    ...remote,
    ...local,
    words: [...words.values()],
    grammarSeen: Object.fromEntries([...new Set([...Object.keys(remote.grammarSeen || {}),...Object.keys(local.grammarSeen || {})])].map(id=>[id,Math.max(remote.grammarSeen?.[id] || 0,local.grammarSeen?.[id] || 0)])),
    collections: [...new Set([...remote.collections, ...local.collections])],
    reviews: [...reviews.values()].sort((a, b) => a.at - b.at),
    reviewSummaries: [...summaries.values()].sort((a, b) =>
      a.day.localeCompare(b.day),
    ),
    readingHistory: [...readingHistory.values()].sort((a, b) => a.at - b.at),
    combined,
    practice: local.practice || remote.practice || null,
    practiceHistory: [...practiceHistory.values()].sort((a, b) => a.at - b.at),
    production: local.production || remote.production || null,
    productionHistory: [...productionHistory.values()].sort((a, b) => a.at - b.at),
  };
}

function openDatabase(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DATABASE, 1);
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains(STORE))
        request.result.createObjectStore(STORE);
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function transact<T>(
  mode: IDBTransactionMode,
  action: (store: IDBObjectStore) => IDBRequest<T>,
): Promise<T | undefined> {
  if (typeof indexedDB === "undefined") return undefined;
  const database = await openDatabase();
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(STORE, mode);
    const request = action(transaction.objectStore(STORE));
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
    transaction.oncomplete = () => database.close();
  });
}

export async function queueState(state: State) {
  await transact("readwrite", (store) => store.put(state, KEY));
}

export async function queuedState() {
  return transact<State>("readonly", (store) => store.get(KEY));
}

export async function clearQueuedState() {
  await transact("readwrite", (store) => store.delete(KEY));
}
