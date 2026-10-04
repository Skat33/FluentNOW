import type { Lookup, TopicListItem } from "./tutor-types";

/** Keep completed batches when a request fails or the user returns to selection. */
export async function prepareTopicItems({
  topic, items, cache, signal, request, onProgress,
}: {
  topic: string;
  items: TopicListItem[];
  cache: Map<string, Lookup>;
  signal: AbortSignal;
  request: (batch: TopicListItem[]) => Promise<{ items: Lookup[] }>;
  onProgress: (done: number) => void;
}) {
  const key = (item: TopicListItem) => JSON.stringify([topic, item.term, item.pl]);
  const missing = items.filter((item) => !cache.has(key(item)));
  let done = items.length - missing.length;
  signal.throwIfAborted();
  onProgress(done);
  for (let index = 0; index < missing.length; index += 5) {
    signal.throwIfAborted();
    const batch = missing.slice(index, index + 5);
    const result = await request(batch);
    signal.throwIfAborted();
    if (result.items.length !== batch.length || result.items.some((item, i) => item.term !== batch[i].term))
      throw new Error("Niekompletna partia słów. Ponów przygotowanie pozostałych.");
    result.items.forEach((item, i) => cache.set(key(batch[i]), item));
    done += batch.length;
    onProgress(done);
  }
  return items.map((item) => cache.get(key(item))!);
}
