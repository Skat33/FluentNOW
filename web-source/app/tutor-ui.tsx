"use client";
import {ExerciseKind} from "./exercise-kind";
import {practiceTarget,readingTarget} from "@/lib/report-corrections";
import {withoutDialectLabel} from "@/lib/answer-variants";
import { HintDisclosure } from "./hint-disclosure";
import { checkPracticeInput } from "@/lib/practice-input";
import { ReadingVocabulary } from "./reading-vocabulary";
import { ReportExercise } from "./exercise-reports";
import { ExerciseAudio, type ExerciseVoice } from "./exercise-audio";
import { exerciseAudioText } from "@/lib/exercise-audio";
import { markGrammarSeen, grammarSelectionSeen } from "@/lib/grammar-bank";
import { AnswerExplanation } from "./answer-explanation";
import { readPrepared, rememberPrepared } from "@/lib/prepared-content";
import { readingSchema, topicListSchema } from "@/lib/tutor-schema";
import { postTutorJson } from "@/lib/gemini-client";
import { prepareTopicItems } from "@/lib/topic-import";
import { useEffect, useRef, useState } from "react";
import {
  Sparkles,
  Search,
  Plus,
  Volume2,
  LoaderCircle,
  ArrowRight,
  BookOpen,
  CheckCircle2,
  Lightbulb,
  RotateCcw,
  Pause,
  Compass,
  ChevronLeft,
  ChevronRight,
  ChevronDown,
} from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Checkbox } from "@/components/ui/checkbox";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Pagination,
  PaginationContent,
  PaginationItem,
} from "@/components/ui/pagination";
import { toast } from "sonner";
import {
  examplePair,
  starterLookup,
  mergeSuggestions,
  estimatedLevel,
  starterReading,
  recommendations,
  recommendationLookup,
  selectReadingMeanings,
  starterPractice,
  resolveExistingCollection,
} from "@/lib/tutor-local";
import { applyReadingResults, mastery, MASTERED_THRESHOLD } from "@/lib/learning";
import type { State, Word, Meaning } from "@/lib/learning";
import type {
  Lookup,
  ExamplePair,
  Reading,
  Recommendation,
  TopicSuggestion,
  TopicListItem,
  TopicHydration,
  PracticeKind,
  PracticeSet,
} from "@/lib/tutor-types";

function topicDeviceKey(topic: string) { return {action:"topicList",topic:topic.trim().toLocaleLowerCase().replace(/\s+/g," ")}; }
function validatePreparedTopic(data: unknown): TopicSuggestion {
  const parsed=topicListSchema.parse(data);
  const meta=data as Partial<TopicSuggestion>;
  return {...parsed,cached:true,matchSource:meta.matchSource,focusCategory:typeof meta.focusCategory==="string"?meta.focusCategory:undefined,matchedQuery:meta.matchedQuery};
}

export async function tutorRequest<T>(
  data: unknown,
  signal?: AbortSignal,
): Promise<T> {
  return postTutorJson<T>(data, signal);
}
export function Highlight({ text, focus }: { text: string; focus: string }) {
  const start = text.toLocaleLowerCase().indexOf(focus.toLocaleLowerCase());
  if (!focus || start < 0) return <>{text}</>;
  return (
    <>
      {text.slice(0, start)}
      <strong>{text.slice(start, start + focus.length)}</strong>
      {text.slice(start + focus.length)}
    </>
  );
}
const spokenPopularityLabel = {
  very_common: "bardzo popularne w codziennej mowie",
  common: "popularne w codziennej mowie",
  less_common: "mniej popularne w codziennej mowie",
  rare: "rzadkie w codziennej mowie",
};
export function SentenceTranslation({
  pair,
  pending = false,
}: {
  pair: ExamplePair | null;
  pending?: boolean;
}) {
  return (
    <div className="sentence-translation" lang="pl">
      {pair ? (
        <Highlight text={pair.pl} focus={pair.focusPl} />
      ) : (
        <span className="muted small">
          {pending
            ? "Przygotowuję tłumaczenie całego zdania…"
            : "Brak tłumaczenia tego przykładu. Uzupełnij je w edycji słowa lub połącz asystenta AI."}
        </span>
      )}
    </div>
  );
}

export function topicSelectionKey(term: string) {
  return term.trim().toLocaleLowerCase();
}

export function dialectDescription(code: string) {
  if (code === "AmE") return "angielski amerykański";
  if (code === "BrE") return "angielski brytyjski";
  return null;
}

function DialectAwareText({text}:{text:string}) { return <>{withoutDialectLabel(text)}</>; }

export function topicPageLayout(width: number) {
  if (width < 640) return { columns: 1, pageSize: 6 };
  if (width < 1024) return { columns: 2, pageSize: 12 };
  return { columns: 3, pageSize: 18 };
}

export function topicPageAfterResize(
  page: number,
  previousPageSize: number,
  nextPageSize: number,
) {
  return Math.floor((page * previousPageSize) / nextPageSize);
}

export function orderTopicCategories<T extends { name: string }>(
  categories: T[],
  focus?: string,
) {
  if (!focus) return [...categories];
  return [...categories].sort((left, right) => {
    if (left.name === focus) return -1;
    if (right.name === focus) return 1;
    return 0;
  });
}

export function initialTopicSelections(
  result: TopicSuggestion,
  existingTerms: Set<string>,
) {
  // Selection is always explicit, including cached topics and focused categories.
  return [] as string[];
}

export function practiceAudioAllowed(answered: boolean) {
  return answered;
}

export function dominantTopicContext<
  T extends { topic?: string; scene?: string },
>(items: T[]) {
  const counts = new Map<
    string,
    { topic: string; scene: string; count: number }
  >();
  for (const item of items) {
    const topic = item.topic?.trim();
    const scene = item.scene?.trim();
    if (!topic || !scene) continue;
    const key = `${topic.toLocaleLowerCase()}\u0000${scene.toLocaleLowerCase()}`;
    const current = counts.get(key);
    counts.set(key, {
      topic,
      scene,
      count: (current?.count || 0) + 1,
    });
  }
  return [...counts.values()].sort((a, b) => b.count - a.count)[0] || null;
}

function useTopicPageSize() {
  const [pageSize, setPageSize] = useState(6);
  useEffect(() => {
    const compact = window.matchMedia("(max-width: 639px)"),
      medium = window.matchMedia("(min-width: 640px) and (max-width: 1023px)"),
      update = () =>
        setPageSize(compact.matches ? 6 : medium.matches ? 12 : 18);
    update();
    compact.addEventListener("change", update);
    medium.addEventListener("change", update);
    return () => {
      compact.removeEventListener("change", update);
      medium.removeEventListener("change", update);
    };
  }, []);
  return pageSize;
}

function TopicCategorySection({
  category,
  categoryIndex,
  pageSize,
  selected,
  setSelected,
  existingTerms,
  speak,
  initialCollapsed = false,
}: {
  category: { name: string; items: TopicListItem[] };
  categoryIndex: number;
  pageSize: number;
  selected: string[];
  setSelected: (update: (current: string[]) => string[]) => void;
  existingTerms: Set<string>;
  speak: (value: string) => void;
  initialCollapsed?: boolean;
}) {
  const [page, setPage] = useState(0);
  const [collapsed, setCollapsed] = useState(initialCollapsed);
  const previousPageSize = useRef(pageSize);
  const resultsRef = useRef<HTMLElement>(null);
  const focusAfterPageChange = useRef(false);
  const pageCount = Math.max(1, Math.ceil(category.items.length / pageSize));
  useEffect(() => {
    setPage((current) =>
      Math.min(
        pageCount - 1,
        topicPageAfterResize(
          current,
          previousPageSize.current,
          pageSize,
        ),
      ),
    );
    previousPageSize.current = pageSize;
  }, [pageSize, pageCount]);
  useEffect(() => {
    if (!focusAfterPageChange.current) return;
    focusAfterPageChange.current = false;
    requestAnimationFrame(() =>
      resultsRef.current
        ?.querySelector<HTMLElement>("[data-topic-card]")
        ?.focus(),
    );
  }, [page]);
  const visible = category.items.slice(
    page * pageSize,
    page * pageSize + pageSize,
  );
  const selectableKeys = category.items
    .map((item) => topicSelectionKey(item.term))
    .filter((key) => !existingTerms.has(key));
  function go(next: number) {
    const bounded = Math.max(0, Math.min(pageCount - 1, next));
    if (bounded === page) return;
    focusAfterPageChange.current = true;
    setPage(bounded);
  }
  return (
    <section
      className="topic-category"
      ref={resultsRef}
      onKeyDown={(event) => {
        if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
        event.preventDefault();
        go(page + (event.key === "ArrowRight" ? 1 : -1));
      }}
    >
      <div className="row between wrap topic-category-heading">
        <button
          className="topic-category-toggle"
          aria-expanded={!collapsed}
          onClick={() => setCollapsed((value) => !value)}
        >
          <ChevronDown className={collapsed ? "collapsed" : ""} size={17} />
          <h3>
            {category.name} <span>({category.items.length})</span>
          </h3>
        </button>
        {!collapsed && (
          <button
            className="text-link"
            disabled={!selectableKeys.length}
            onClick={() =>
              setSelected((current) => [
                ...new Set([...current, ...selectableKeys]),
              ])
            }
          >
            Zaznacz całą kategorię
          </button>
        )}
      </div>
      {!collapsed && <div className="topic-options">
        {visible.map((item, itemIndex) => {
          const key = topicSelectionKey(item.term);
          const checked = selected.includes(key);
          const owned = existingTerms.has(key);
          const controlId = `topic-${categoryIndex}-${page * pageSize + itemIndex}`;
          return (
            <div
              className={
                "topic-option " + (owned ? "owned" : checked ? "selected" : "")
              }
              key={key}
              data-topic-card
              tabIndex={-1}
            >
              <Checkbox
                id={controlId}
                checked={owned || checked}
                disabled={owned}
                onCheckedChange={(value) =>
                  setSelected((current) =>
                    value
                      ? [...new Set([...current, key])]
                      : current.filter((item) => item !== key),
                  )
                }
              />
              <label htmlFor={controlId}>
                <span className="row between wrap">
                  <b>{item.term}</b>
                  <span className="badge gray">
                    {item.level} · {item.pos}
                  </span>
                </span>
                <span>
                  <DialectAwareText text={item.pl} />
                </span>
                <small className="muted">
                  {spokenPopularityLabel[item.spokenFrequency]}
                </small>
                <small className="muted">↳ {category.name}</small>
                {owned && (
                  <small className="topic-owned-label">
                    masz już w słowniku
                  </small>
                )}
              </label>
              <button
                className="icon-btn"
                aria-label={`Posłuchaj: ${item.term}`}
                onClick={() => speak(item.term)}
              >
                <Volume2 size={16} />
              </button>
            </div>
          );
        })}
      </div>}
      {!collapsed && pageCount > 1 && (
        <Pagination aria-label={`Strony kategorii ${category.name}`}>
          <PaginationContent>
            <PaginationItem>
              <button
                className="btn secondary topic-page-button"
                disabled={page === 0}
                onClick={() => go(page - 1)}
              >
                <ChevronLeft size={16} /> Wstecz
              </button>
            </PaginationItem>
            <PaginationItem>
              <span className="topic-page-count" aria-live="polite">
                Strona {page + 1} z {pageCount}
              </span>
            </PaginationItem>
            <PaginationItem>
              <button
                className="btn secondary topic-page-button"
                disabled={page + 1 >= pageCount}
                onClick={() => go(page + 1)}
              >
                Dalej <ChevronRight size={16} />
              </button>
            </PaginationItem>
          </PaginationContent>
        </Pagination>
      )}
    </section>
  );
}
export function QuickAdd({
  open,
  onOpenChange,
  state,
  onSave,
  ai,
  speak,
  onManual,
  initial = "",
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  state: State;
  onSave: (s: State) => boolean;
  ai: boolean;
  speak: (s: string) => void;
  onManual: (term: string) => void;
  initial?: string;
}) {
  const [addMode, setAddMode] = useState<"word" | "topic">("word"),
    [term, setTerm] = useState(initial),
    [result, setResult] = useState<Lookup | null>(null),
    [selected, setSelected] = useState<number[]>([]),
    [topicResult, setTopicResult] = useState<TopicSuggestion | null>(null),
    [topicSelected, setTopicSelected] = useState<string[]>([]),
    [popular, setPopular] = useState<{ canonical: string; hits: number }[]>([]),
    [hydrateProgress, setHydrateProgress] = useState<{
      done: number;
      total: number;
      phase: "details" | "ready" | "error";
    } | null>(null),
    [automaticCollection, setAutomaticCollection] = useState(true),
    [manualCollections, setManualCollections] = useState<Record<string, string>>({}),
    [hydratingItems, setHydratingItems] = useState<TopicListItem[]>([]),
    [elapsed, setElapsed] = useState(0),
    [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  const seq = useRef(0);
  const topicAbort = useRef<AbortController | null>(null);
  const automaticCollectionRef = useRef(true);
  const manualCollectionsRef = useRef<Record<string, string>>({});
  const prepared = useRef(new Map<string, Lookup>());
  const completedItems = useRef<Lookup[]>([]);
  const latestState = useRef(state);
  latestState.current = state;
  const addButton = useRef<HTMLButtonElement | null>(null);
  const hydrationPanel = useRef<HTMLElement | null>(null);
  const cache = useRef(new Map<string, Lookup>());
  const topicPageSize = useTopicPageSize();
  const isHydrating = hydrateProgress !== null;
  useEffect(() => {
    if (!isHydrating || !busy) return;
    setElapsed(0);
    const started = Date.now();
    const timer = setInterval(() => setElapsed(Math.floor((Date.now() - started) / 1000)), 1000);
    return () => clearInterval(timer);
  }, [isHydrating, busy]);
  useEffect(() => {
    if (isHydrating) {
      hydrationPanel.current?.focus({ preventScroll: true });
      hydrationPanel.current?.scrollIntoView({ block: "nearest" });
    }
  }, [isHydrating]);
  useEffect(() => {
    if (open) {
      setBusy(false);
      setAddMode("word");
      setTerm(initial);
      setResult(null);
      setSelected([]);
      setTopicResult(null);
      setTopicSelected([]);
      setHydrateProgress(null);
      setAutomaticCollection(true);
      automaticCollectionRef.current = true;
      setManualCollections({});
      manualCollectionsRef.current = {};
      setError("");
    } else {
      seq.current++;
      topicAbort.current?.abort();
      topicAbort.current = null;
      setBusy(false);
      setHydrateProgress(null);
    }
  }, [open, initial]);
  useEffect(() => {
    if (!open || addMode !== "topic" || popular.length) return;
    const controller = new AbortController();
    tutorRequest<{ items: { canonical: string; hits: number }[] }>(
      { action: "popularTopics" },
      controller.signal,
    )
      .then((data) => setPopular(data.items))
      .catch(() => undefined);
    return () => controller.abort();
  }, [open, addMode, ai, popular.length]);
  useEffect(() => {
    if (!open || addMode !== "topic" || !popular.length) return;
    const controller=new AbortController();
    void (async()=>{
      for (const item of popular.slice(0,4)) {
        if (controller.signal.aborted) return;
        const key=topicDeviceKey(item.canonical);
        if (readPrepared(key,validatePreparedTopic)) continue;
        try {
          const data=await postTutorJson({...key,cacheOnly:true},controller.signal,{attempts:1,timeoutMs:5000});
          if (!controller.signal.aborted) rememberPrepared(key,validatePreparedTopic(data));
        } catch { /* An uncached topic is generated only after the user's click. */ }
      }
    })();
    return ()=>controller.abort();
  },[open,addMode,popular]);
  useEffect(() => {
    // Topic requests own their loading state. A chip also updates term;
    // that must not clear the in-flight request's busy flag.
    if (addMode !== "word") return;
    if (!open || !term.trim()) {
      setBusy(false);
      return;
    }
    const id = ++seq.current;
    const ac = new AbortController();
    setResult(null);
    setSelected([]);
    setError("");
    setBusy(true);
    const timer = setTimeout(async () => {
      try {
        const key = term.trim().toLowerCase() + "|" + ai;
        let d = cache.current.get(key) || starterLookup(term.trim()) || undefined;
        if (!d) {
          if (ai)
            d = await postTutorJson<Lookup>(
              {
                action: "lookup",
                term: term.trim(),
                collections: state.collections.slice(0, 100),
              },
              ac.signal, {attempts:1,timeoutMs:30000},
            );
          else d = starterLookup(term.trim()) || undefined;
          if (d) cache.current.set(key, d);
        }
        if (id !== seq.current) return;
        if (d) setResult(d);
        else
          setError(
            "Tego hasła nie ma w bazie startowej. Nie oznacza to, że nie istnieje. Połącz AI, aby uzupełniać dowolne słowa i zwroty. Możesz też dodać je ręcznie.",
          );
      } catch (e) {
        if (id === seq.current && !ac.signal.aborted)
          setError((e as Error).message);
      } finally {
        if (id === seq.current) setBusy(false);
      }
    }, 650);
    return () => {
      clearTimeout(timer);
      ac.abort();
    };
  }, [term, open, ai, addMode]);
  const existingTopicTerms = new Set(
    state.words.map((word) => topicSelectionKey(word.en)),
  );
  const topicEntries = (result = topicResult) =>
    result?.categories.flatMap((category) =>
      category.items.map((item) => ({
        item,
        category: category.name,
        key: topicSelectionKey(item.term),
      })),
    ) || [];
  const selectedTopicItems = () => {
    const selected = new Set(topicSelected);
    return topicEntries()
      .filter(
        ({ item, key }) =>
          selected.has(key) &&
          !existingTopicTerms.has(topicSelectionKey(item.term)),
      )
      .map(({ item }) => item);
  };
  async function exploreTopic(topicOverride?: string, forceFresh = false) {
    const query = (topicOverride || term).trim();
    if (!query || busy) return;
    setBusy(true);
    setError("");
    topicAbort.current?.abort();
    const controller = new AbortController();
    topicAbort.current = controller;
    setTopicResult(null);
    setTopicSelected([]);
    setHydrateProgress(null);
    setAutomaticCollection(true);
    automaticCollectionRef.current = true;
    setManualCollections({});
    manualCollectionsRef.current = {};
    try {
      const key = topicDeviceKey(query);
      const saved = forceFresh ? null : readPrepared(key,validatePreparedTopic);
      const data = saved || await postTutorJson<TopicSuggestion>(
        {action:"topicList",topic:query,forceFresh,fast:true},controller.signal,{attempts:1,timeoutMs:45000},
      );
      if (!controller.signal.aborted) rememberPrepared(key,data);
      if (controller.signal.aborted || topicAbort.current !== controller) return;
      setTopicResult(data);
      setTopicSelected(initialTopicSelections(data, existingTopicTerms));
    } catch (e) {
      if (!controller.signal.aborted) setError((e as Error).message);
    } finally {
      if (topicAbort.current === controller) {
        topicAbort.current = null;
        setBusy(false);
      }
    }
  }
  async function rejectTopicMatch() {
    const query = topicResult?.matchedQuery || term.trim();
    if (!query || busy) return;
    try {
      await tutorRequest({ action: "forgetTopicAlias", topic: query });
      await exploreTopic(query, true);
    } catch (error) {
      setError((error as Error).message);
    }
  }
  async function hydrateTopic() {
    if (!topicResult || busy) return;
    const items = selectedTopicItems();
    if (!items.length) return;
    const collection = resolveExistingCollection(state.collections, topicResult.topic, topicResult.topic) || topicResult.topic;
    const scene = `osoba w realnej sytuacji związanej z tematem „${topicResult.topic}”`;
    setHydratingItems(items);
    setError("");
    const choices = Object.fromEntries(items.map(item => [topicSelectionKey(item.term), manualCollectionsRef.current[topicSelectionKey(item.term)] || collection]));
    setManualCollections(choices);
    manualCollectionsRef.current = choices;
    completedItems.current = items.map(item => ({
      exists:true, term:item.term, ipa:"", forms:"", collocations:"", synonyms:"", antonyms:"", note:"", alternatives:[], source:"ai",
      meanings:[{translation:item.pl, definition:"", pos:item.pos, level:item.level, spokenFrequency:item.spokenFrequency,
        context:scene, topic:topicResult.topic, scene, register:"", natural:"", collection, examples:[], acceptedAnswers:[], needsDetails:true}],
    }));
    setHydrateProgress({done:items.length,total:items.length,phase:"ready"});
  }
  function cancelHydration() {
    topicAbort.current?.abort();
    topicAbort.current = null;
    setBusy(false);
    setHydrateProgress(null);
    setError("");
    requestAnimationFrame(() => addButton.current?.focus());
  }
  function saveHydrated(items = completedItems.current) {
      const base = latestState.current;
      let next = base;
      for (const item of items)
        next = mergeSuggestions(next, item, [0], automaticCollectionRef.current ? undefined : manualCollectionsRef.current[topicSelectionKey(item.term)]);
      const diff =
        next.words.reduce((sum, word) => sum + word.meanings.length, 0) -
        base.words.reduce((sum, word) => sum + word.meanings.length, 0);
      if (onSave(next)) {
        toast.success(
          diff
            ? !automaticCollectionRef.current
              ? `Zapisano ${diff} znaczeń w wybranych kolekcjach.`
              : `Zapisano ${diff} znaczeń. Przykłady przygotują się w tle.`
            : "Wybrane znaczenia są już w Twoim słowniku.",
        );
        onOpenChange(false);
      }
  }
  const orderedTopicCategories = topicResult
    ? orderTopicCategories(topicResult.categories, topicResult.focusCategory)
    : [];
  const topicCollection = topicResult
    ? resolveExistingCollection(
        state.collections,
        topicResult.topic,
        topicResult.topic,
      ) || topicResult.topic
    : "";
  const collectionChoices = [
    ...new Set([
      ...state.collections.filter((item) => item.trim()),
      topicCollection,
    ]),
  ].filter(Boolean);
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        className={`quick-add-dialog ${addMode === "topic" ? "topic-dialog" : ""}`}
      >
        <DialogTitle>Jedno słowo. Wiele możliwości.</DialogTitle>
        <DialogDescription>
          Dodaj konkretne słowo albo odkryj zestaw dopasowany do interesującego
          Cię tematu.
        </DialogDescription>
        <div className="quick-add-content" hidden={isHydrating}>
        <Tabs
          value={addMode}
          onValueChange={(value) => {
            topicAbort.current?.abort();
            topicAbort.current = null;
            setBusy(false);
            setAddMode(value as "word" | "topic");
            setTerm("");
            setResult(null);
            setTopicResult(null);
            setSelected([]);
            setTopicSelected([]);
            setHydrateProgress(null);
            setAutomaticCollection(true);
            automaticCollectionRef.current = true;
            setManualCollections({});
            manualCollectionsRef.current = {};
            setError("");
          }}
        >
          <TabsList className="add-mode-tabs">
            <TabsTrigger value="word">
              <Search size={16} /> Dodaj słowo
            </TabsTrigger>
            <TabsTrigger value="topic">
              <Compass size={16} /> Odkrywaj temat
            </TabsTrigger>
          </TabsList>
        </Tabs>
        <label className="quick-word">
          {addMode === "word" ? <Search size={22} /> : <Compass size={22} />}
          <input
            autoFocus
            aria-label={
              addMode === "word"
                ? "Słowo do uzupełnienia"
                : "Temat propozycji słownictwa"
            }
            placeholder={
              addMode === "word"
                ? "np. do, bank, get along"
                : "np. rozmowa o pracę, fotografia, lotnisko"
            }
            value={term}
            onChange={(e) => {
              if (addMode === "topic") {
                topicAbort.current?.abort();
                topicAbort.current = null;
                setBusy(false);
                setTopicResult(null);
                setTopicSelected([]);
              }
              setTerm(e.target.value);
            }}
            maxLength={120}
            onKeyDown={(event) => {
              if (addMode === "topic" && event.key === "Enter") {
                event.preventDefault();
                exploreTopic();
              }
            }}
          />
          {busy && <LoaderCircle className="spin" size={20} />}
        </label>
        {addMode === "topic" && (
          <button
            className="btn primary topic-search"
            disabled={busy || term.trim().length < 3}
            onClick={() => exploreTopic()}
          >
            <Sparkles size={17} />
            {busy ? "Dobieram słownictwo…" : "Pokaż propozycje"}
          </button>
        )}
        <div className="quick-source">
          <Sparkles size={14} />
          {ai
            ? "Asystent AI · przykłady tworzone dla Ciebie"
            : "Baza startowa · AI jeszcze niepołączone"}
        </div>
        {addMode === "topic" && !topicResult && popular.length > 0 && (
          <div className="topic-popular" aria-label="Popularne tematy">
            <span className="small muted">Popularne teraz</span>
            <div className="row wrap">
              {popular.map((item) => (
                <button
                  className="btn secondary topic-suggestion-chip"
                  key={item.canonical}
                  disabled={busy}
                  onClick={() => {
                    setTerm(item.canonical);
                    void exploreTopic(item.canonical);
                  }}
                >
                  {item.canonical}
                </button>
              ))}
            </div>
          </div>
        )}
        {error && (
          <div className="hint-box" role="status">
            <Lightbulb size={20} />
            <span>{error}</span>
          </div>
        )}
        {addMode === "word" && result && !result.exists && (
          <div className="hint-box">
            <Lightbulb size={20} />
            <div>
              <b>Nie udało się potwierdzić tego hasła</b>
              <p>{result.note}</p>
              <div className="row wrap">
                {result.alternatives.map((t) => (
                  <button
                    key={t}
                    className="btn secondary"
                    onClick={() => setTerm(t)}
                  >
                    {t}
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}
        {addMode === "word" && result?.exists && (
          <>
            <div className="row between">
              <div>
                <h2>{result.term}</h2>
                <span className="ipa">
                  {result.ipa || "IPA nieuzupełnione"}
                </span>
              </div>
              <button
                className="btn secondary"
                onClick={() => speak(result.term)}
              >
                <Volume2 size={17} />{" "}
                {ai
                  ? "Wymowa AI (US)"
                  : state.settings.accent === "en-GB"
                    ? "Wymowa UK"
                    : "Wymowa US"}
              </button>
            </div>
            <p className="small muted">
              Wybierz dowolną liczbę znaczeń. Kolekcje utworzymy automatycznie.
            </p>
            <div className="sense-options">
              {result.meanings.map((m, i) => (
                <div
                  key={i}
                  className={
                    "sense-option " + (selected.includes(i) ? "selected" : "")
                  }
                >
                  <div className="row">
                    <Checkbox
                      id={"sense-" + i}
                      checked={selected.includes(i)}
                      onCheckedChange={(v) =>
                        setSelected((a) =>
                          v ? [...a, i] : a.filter((x) => x !== i),
                        )
                      }
                    />
                    <label htmlFor={"sense-" + i}>
                      <b>{withoutDialectLabel(m.translation)}</b>
                      <span>
                        {m.pos} · {m.level} · {m.register}
                      </span>
                    </label>
                  </div>
                  <p className="sense-example" lang="en">
                    <Highlight
                      text={m.examples[0].en}
                      focus={m.examples[0].focusEn}
                    />
                  </p>
                  <p className="sense-polish">
                    <Highlight
                      text={m.examples[0].pl}
                      focus={m.examples[0].focusPl}
                    />
                  </p>
                  {m.spokenFrequency && (
                    <p className="tiny muted">
                      CEFR {m.level} · {spokenPopularityLabel[m.spokenFrequency]}
                    </p>
                  )}
                  <div className="row between small">
                    <span className="badge lavender">↳ {m.collection}</span>
                    <button
                      className="icon-btn"
                      aria-label="Posłuchaj przykładu"
                      onClick={() => speak(m.examples[0].en)}
                    >
                      <Volume2 size={17} />
                    </button>
                  </div>
                </div>
              ))}
            </div>
            <p className="tiny muted">
              {result.source === "ai"
                ? "Poziom i popularność w codziennej mowie są oceniane osobno dla każdego znaczenia."
                : "Opracowane przykłady startowe; nie jest to wynik wyszukiwania w internecie."}
            </p>
          </>
        )}
        {addMode === "topic" && busy && !topicResult && !hydrateProgress && (
          <div
            className="topic-loading"
            role="status"
            aria-label="Wczytywanie kategorii tematu"
          >
            {Array.from({ length: 5 }, (_, categoryIndex) => (
              <section className="topic-category" key={categoryIndex}>
                <Skeleton className="topic-category-skeleton" />
                <div className="topic-options">
                  {Array.from({ length: 2 }, (_, itemIndex) => (
                    <div
                      className="topic-option topic-option-skeleton"
                      key={itemIndex}
                    >
                      <Skeleton className="topic-check-skeleton" />
                      <div>
                        <Skeleton className="topic-term-skeleton" />
                        <Skeleton className="topic-copy-skeleton" />
                        <Skeleton className="topic-meta-skeleton" />
                      </div>
                    </div>
                  ))}
                </div>
              </section>
            ))}
          </div>
        )}
        {addMode === "topic" && topicResult && (
          <>
            <div className="row between wrap topic-heading">
              <div>
                <h2>{topicResult.topic}</h2>
                <p className="small muted">
                  Pełny przekrój tematu · A1–C2 · od podstaw po zaawansowane
                  {topicResult.cached ? " · wynik z pamięci" : ""}
                </p>
              </div>
              <button
                className="text-link"
                disabled={!topicSelected.length}
                onClick={() => setTopicSelected([])}
              >
                Odznacz wszystko ({topicSelected.length})
              </button>
            </div>
            {topicResult.focusCategory && (
              <div className="hint-box topic-match-hint">
                <Compass size={19} />
                <span>
                  Pokazujemy najpierw część tematu „{topicResult.topic}”: {" "}
                  <b>{topicResult.focusCategory}</b>. Pozostałe kategorie też są
                  dostępne poniżej.
                </span>
              </div>
            )}
            {topicResult.matchSource &&
              ["alias", "fuzzy", "model"].includes(
                topicResult.matchSource,
              ) && (
                <button
                  className="text-link muted topic-rescue"
                  disabled={busy}
                  onClick={() => void rejectTopicMatch()}
                >
                  To nie to, czego szukałem
                </button>
              )}
            <div className="topic-categories">
              {orderedTopicCategories.map((category, categoryIndex) => (
                <TopicCategorySection
                  key={`${topicResult.topic}:${category.name}`}
                  category={category}
                  categoryIndex={categoryIndex}
                  pageSize={topicPageSize}
                  selected={topicSelected}
                  setSelected={setTopicSelected}
                  existingTerms={existingTopicTerms}
                  speak={speak}
                  initialCollapsed={
                    !!topicResult.focusCategory &&
                    category.name !== topicResult.focusCategory
                  }
                />
              ))}
            </div>
          </>
        )}
        </div>
        {hydrateProgress && (
          <>
          <section
            className="topic-hydration"
            ref={hydrationPanel}
            tabIndex={-1}
            aria-label="Postęp dodawania słów"
          >
            <div
              className="topic-hydration-heading"
              role="status"
              aria-live="polite"
            >
              {busy ? <LoaderCircle className="spin" size={20} /> : <CheckCircle2 size={20} />}
              <div>
                <b>
                  {hydrateProgress.phase === "details"
                    ? "Dodaję słowa i przygotowuję przykłady"
                    : hydrateProgress.phase === "ready"
                      ? "Wybrane słowa — sprawdź kolekcje"
                      : "Przygotowanie wstrzymane"}
                </b>
                <span>
                  Wybrano {hydrateProgress.total} znaczeń
                </span>
              </div>
            </div>
            <Progress
              className={busy && !hydrateProgress.done ? "hydration-indeterminate" : ""}
              aria-label="Przygotowanie znaczeń"
              value={busy && !hydrateProgress.done ? null : (hydrateProgress.done / hydrateProgress.total) * 100}
            />
            <p className="small muted">Słowa zapiszą się od razu. Możesz przypisać je do kolekcji automatycznie lub osobno wybrać kolekcję dla każdego słowa.</p>
            {busy && <p className="small muted">
              {elapsed < 30 ? "Uzupełniam tłumaczenia i przykłady" : "Nadal czekam na odpowiedź AI; gotowe partie są zachowane"} · {elapsed} s.
              {" "}Licznik zmieni się po przygotowaniu kolejnej partii słów.
            </p>}
            {error && <p className="hint-box" role="alert">{error}</p>}
              {automaticCollection && (
                  <p className="small muted">
                    Automatycznie użyję najlepiej pasującej istniejącej
                    kolekcji, obecnie: <b>{topicCollection}</b>.
                  </p>
              )}
          </section>
          {!automaticCollection && <section className="word-collection-list" aria-label="Kolekcje dla poszczególnych słów">
              <p className="small muted">Wybierz kolekcję osobno dla każdego słowa. Zapiszę je dopiero po zatwierdzeniu.</p>
              {hydratingItems.map((item) => (
                <label className="word-collection-row" key={topicSelectionKey(item.term)}>
                  <span><b>{item.term}</b><small>{withoutDialectLabel(item.pl)}</small></span>
                  <Select
                    value={manualCollections[topicSelectionKey(item.term)]}
                    onValueChange={(value) => {
                      const next = {...manualCollectionsRef.current, [topicSelectionKey(item.term)]: value};
                      manualCollectionsRef.current = next;
                      setManualCollections(next);
                    }}
                  >
                    <SelectTrigger aria-label={`Kolekcja dla ${item.term}`}>
                      <SelectValue placeholder="Wybierz kolekcję" />
                    </SelectTrigger>
                    <SelectContent>
                      {collectionChoices.map((collection) => (
                        <SelectItem key={collection} value={collection}>
                          {collection}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </label>
              ))}
          </section>}
          <div className="hydration-actions">
            <button className="btn secondary" onClick={cancelHydration}>
              Anuluj dodawanie
            </button>
            {automaticCollection && <button className="btn secondary" onClick={() => {
              setAutomaticCollection(false);
              automaticCollectionRef.current = false;
            }}>Anuluj automatyczne dopasowanie</button>}
            {hydrateProgress.phase === "error" && <button className="btn primary" onClick={() => void hydrateTopic()}>Ponów pozostałe</button>}
            {hydrateProgress.phase === "ready" && <button className="btn primary" onClick={() => saveHydrated()}>Zapisz słowa</button>}
          </div>
          </>
        )}
        <div className="modal-footer" hidden={isHydrating}>
          {addMode === "word" ? (
            <button
              className="text-link muted"
              onClick={() => {
                onOpenChange(false);
                onManual(term);
              }}
            >
              Dodaj ręcznie
            </button>
          ) : (
            <span className="small muted">
              Każde znaczenie zapisujemy osobno.
            </span>
          )}
          <button
            ref={addButton}
            className="btn primary"
            disabled={
              busy ||
              (addMode === "word"
                ? !result?.exists || !selected.length
                : !topicResult || !selectedTopicItems().length)
            }
            onClick={() => {
              if (addMode === "word" && !result) return;
              if (addMode === "topic") {
                void hydrateTopic();
                return;
              }
              let next = state;
              if (addMode === "word" && result)
                next = mergeSuggestions(state, result, selected);
              const diff =
                next.words.reduce((a, w) => a + w.meanings.length, 0) -
                state.words.reduce((a, w) => a + w.meanings.length, 0);
              if (onSave(next)) {
                toast.success(
                  diff
                    ? `Zapisano ${diff} znaczeń. Przykłady przygotują się w tle.`
                    : "Wybrane znaczenia są już w Twoim słowniku.",
                );
                onOpenChange(false);
              }
            }}
          >
            <Plus size={17} /> Dodaj{" "}
            {addMode === "word"
              ? selected.length || ""
              : selectedTopicItems().length || ""}{" "}
            {(addMode === "word"
              ? selected.length
              : selectedTopicItems().length) === 1
              ? "znaczenie"
              : "znaczeń"}
          </button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
export function ReadingPractice({
  state,
  onSave,
  ai,
  speak,
  onExit,
}: {
  state: State;
  onSave: (s: State) => boolean;
  ai: boolean;
  speak: ExerciseVoice["speak"];
  onExit: () => void;
}) {
  const level = estimatedLevel(state);
  const selectedMeanings = selectReadingMeanings(state, level.targetLevel);
  const [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  const mounted = useRef(true);
  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);
  const current = state.reading;
  async function generate(personalized=false) {
    setBusy(true);
    setError("");
    try {
      const context = dominantTopicContext(selectedMeanings);
      const readingMeanings = context
        ? selectedMeanings.filter(
            (item) =>
              item.topic === context.topic && item.scene === context.scene,
          )
        : selectedMeanings;
      let reading: Reading | null;
      const makeRequest = (variant:number) => ({
        action:"reading",level:level.targetLevel,
        words:readingMeanings.map(({en,meaningId,translation,level})=>({en,meaningId,translation,level})),
        topic:context?.topic,scene:context?.scene,previousTitles:(state.readingHistory || []).slice(-10).map(r=>r.title).filter(Boolean),variant,
      });
      const variant=(state.readingHistory?.length || 0);
      const validate=(data:unknown):Reading=>({...readingSchema.parse(data),id:`prepared-${crypto.randomUUID()}`,source:"ai"});
      if(personalized && ai) {
        const request=makeRequest(variant);
        reading=readPrepared(request,validate);
        if(!reading) {
          reading=validate(await postTutorJson(request,AbortSignal.timeout(45000),{attempts:1}));
          rememberPrepared(request,reading);
        }
      } else reading=starterReading(level.targetLevel,state.readingHistory || [],context?.topic);
      if (!reading) {
        setError(
          "Nie udało się odczytać zestawu. Spróbuj ponownie.",
        );
        return;
      }
      // Only explicitly authored word-in-context questions update a meaning.
      // Merely finding a dictionary word in evidence is not a test of that word.
      reading.questions=reading.questions.map(q=>q.meaningId && !readingMeanings.some(m=>m.meaningId===q.meaningId) ? {...q,meaningId:undefined} : q);
      if (mounted.current)
        onSave({
          ...state,
          reading: {
            reading,
            answers: reading.questions.map(() => -1),
            submitted: false,
          },
        });
    } catch (e) {
      if (mounted.current) setError((e as Error).message);
    } finally {
      if (mounted.current) setBusy(false);
    }
  }
  const correct =
    current?.answers.filter((a, i) => a === current.reading.questions[i].answer)
      .length || 0;
  return (
    <section className="reading-practice">
      <div className="row between">
        <button className="text-link muted" onClick={onExit}>
          <Pause size={17} /> Wróć do ćwiczeń
        </button>
        <span className="badge lavender">Czytanie ze zrozumieniem</span>
      </div>
      <div className="reading-level">
        <BookOpen size={24} />
        <div>
          <b>
            Twój poziom: {level.level} · tekst: {level.targetLevel}
          </b>
          <p>
            {level.count
              ? `Na podstawie ${level.count} znaczeń · pewność ${level.confidence === "high" ? "wyższa" : "wstępna"}. To wskazówka, nie certyfikowana ocena.`
              : "Wstępnie A1; tekst jest o jeden krok wyżej. Poziom dopasuje się do wyników nauki."}
          </p>
        </div>
      </div>
      {!current ? (
        <div className="card reading-intro">
          <h1>
            Mała historia.
            <br />
            Więcej zrozumienia.
          </h1>
          <p>
            {"Zapisany bank tekstów A1–C2 działa od razu i bez AI. Im wyższy poziom, tym dłuższy tekst i więcej pytań o intencje, wnioski oraz pozornie podobne informacje."}
          </p>
          <button className="btn primary" disabled={busy} onClick={()=>void generate()}>
            {busy ? (
              <LoaderCircle className="spin" size={17} />
            ) : (
              <BookOpen size={17} />
            )}{" "}
            {busy ? "Przygotowuję tekst…" : "Przygotuj czytankę"}
          </button>
          {ai && <button className="text-link" disabled={busy} onClick={()=>void generate(true)}>Utwórz tekst z moich słów (AI)</button>}
        </div>
      ) : (
        <>
          <article className="card reading-text">
            <div className="row between">
              <span className="badge gray">
                {current.reading.level} ·{" "}
                {current.reading.source === "ai" ? "Tekst AI" : "Bank czytanek"}
              </span>
              <button
                className="icon-btn"
                aria-label="Odsłuchaj tekst"
                onClick={() => speak(current.reading.paragraphs.join("\n"),undefined,"exercise")}
              >
                <Volume2 size={21} />
              </button>
            </div>
            <h1>{current.reading.title}</h1><p className="small muted">{current.reading.paragraphs.join(" ").split(/\s+/).length} słów · {current.reading.questions.length} pytań. Podkreślone słowa są w Twoim słowniku — dotknij ich, aby zobaczyć znaczenia.</p>
            {current.reading.paragraphs.map((p, i) => (
              <p lang="en" key={i}>
                <ReadingVocabulary text={p} words={state.words}/>
              </p>
            ))}
          </article>
          <div className="reading-questions">
            {current.reading.questions.map((q, i) => (
              <section className="card reading-question" key={i}>
                <ExerciseKind kind="Czytanie" detail="Rozumienie tekstu"/>
                <h3>
                  {i + 1}. {q.question}
                </h3>
                <div className="answer-options">
                  {q.options.map((o, j) => (
                    <button
                      key={j}
                      aria-pressed={current.answers[i] === j}
                      disabled={current.submitted}
                      className={
                        (current.answers[i] === j ? "chosen " : "") +
                        (current.submitted && q.answer === j
                          ? "answer-correct"
                          : "")
                      }
                      onClick={() => {
                        const answers = [...current.answers];
                        answers[i] = j;
                        onSave({ ...state, reading: { ...current, answers } });
                      }}
                    >
                      <span>{"ABCD"[j]}</span>
                      {o}
                    </button>
                  ))}
                </div>
                {current.submitted && (
                  <div
                    className={
                      "feedback " +
                      (current.answers[i] === q.answer ? "correct" : "wrong")
                    }
                  >
                    <div>
                      <b>
                        {current.answers[i] === q.answer
                          ? "Dobrze!"
                          : `Niepoprawna odpowiedź. Poprawna: ${"ABCD"[q.answer]}`}
                      </b>
                      <AnswerExplanation key={`${current.reading.id}:${i}`} correct={current.answers[i] === q.answer}><p>{q.explanation}</p>
                      <blockquote>“{q.evidence}”</blockquote></AnswerExplanation>
                    </div>
                  </div>
                )}
                {current.submitted && <ReportExercise snapshot={{mode:"Czytanie",question:q.question,answer:q.options[current.answers[i]] || "",expected:[q.options[q.answer]],target:readingTarget(q,current.reading)}}/>}
              </section>
            ))}
          </div>
          {current.submitted ? (
            <div className="card reading-result">
              <CheckCircle2 size={30} />
              <h2>
                {correct} / {current.reading.questions.length} poprawnych
                odpowiedzi
              </h2>
              <p>
                Pytania o słowo w kontekście delikatnie aktualizują jego
                rozpoznawanie.
              </p>
              <button
                className="btn primary"
                disabled={busy}
                onClick={()=>void generate()}
              >
                {busy ? (
                  <LoaderCircle className="spin" size={17} />
                ) : (
                  <RotateCcw size={17} />
                )}{" "}
                Następny tekst
              </button>
            </div>
          ) : (
            <button
              className="btn primary reading-submit"
              disabled={current.answers.includes(-1)}
              onClick={() => {
                if (current.submitted) return;
                const completed = {
                  ...current,
                  submitted: true,
                  completedAt: Date.now(),
                };
                const learned = applyReadingResults(state, completed);
                onSave({
                  ...learned,
                  reading: completed,
                  readingHistory: [
                    ...(learned.readingHistory || []),
                    {
                      id: current.reading.id,
                      at: Date.now(),
                      level: current.reading.level,
                      correct,
                      total: current.reading.questions.length,
                      title: current.reading.title,
                    },
                  ],
                });
              }}
            >
              Sprawdź odpowiedzi <ArrowRight size={17} />
            </button>
          )}
        </>
      )}
      {error && (
        <p className="error-banner" role="alert">
          {error}
        </p>
      )}
    </section>
  );
}

export function SkillPractice({
  state,
  onSave,
  ai,
  kind,
  speak,
  prefetch,
  stop,
  onExit,
}: {
  state: State;
  onSave: (s: State) => boolean;
  ai: boolean;
  kind: PracticeKind;
  speak: ExerciseVoice["speak"];
  prefetch?:ExerciseVoice["prefetch"];
  stop?:ExerciseVoice["stop"];
  onExit: () => void;
}) {
  const level = estimatedLevel(state);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const current = state.practice?.set.kind === kind ? state.practice : null;
  const displayedGrammar=useRef("");
  const latestPractice=useRef({state,onSave});latestPractice.current={state,onSave};
  const displayedItem=current?.set.items[current.index];
  useEffect(()=>{
    if (!current || current.completedAt || displayedItem?.category!=="grammar" || !displayedItem.bankId) return;
    const key=`${current.set.id}:${current.index}`;
    if (displayedGrammar.current===key) return;
    displayedGrammar.current=key;
    const latest=latestPractice.current;
    latest.onSave(markGrammarSeen(latest.state,displayedItem));
  },[current?.set.id,current?.index,current?.completedAt,displayedItem?.bankId]);
  const labels = {
    grammar: "Gramatyka",
    idioms: "Idiomy",
    mixed: "Miks językowy",
  } as const;
  async function generate() {
    setBusy(true);
    setError("");
    try {
      const variant=(state.practiceHistory || []).filter(item=>item.kind===kind).length;
      const set=starterPractice(kind,level.targetLevel,variant,grammarSelectionSeen(state));
      onSave({
        ...state,
        practice: {
          set: {...set,id:crypto.randomUUID()},
          answers: set.items.map(() => -1),
          writtenAnswers: set.items.map(() => ""),
          index: 0,
        },
      });
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  if (!current)
    return (
      <section className="reading-practice skill-practice">
        <div className="row between">
          <button className="text-link muted" onClick={onExit}>
            <Pause size={17} /> Wróć do wyboru ćwiczeń
          </button>
          <span className="badge lavender">{labels[kind]}</span>
        </div>
        <div className="card practice-intro">
          <div>
            <span className="eyebrow">POZIOM {level.targetLevel}</span>
            <h1>{labels[kind]}</h1>
            <p>
              {kind === "grammar"
                ? "Ponad 300 zdań na Twoim poziomie, dostępnych od razu. Najpierw zobaczysz zadania, których jeszcze nie rozwiązywałeś."
                : kind === "idioms"
                  ? "Znaczenie, kontekst i różnice, które pomagają używać idiomów naturalnie."
                  : "Gramatyka i idiomy w różnych sytuacjach: cztery pytania ABCD i dwie luki do samodzielnego uzupełnienia."}
            </p>
          </div>
          <button className="btn primary" disabled={busy} onClick={generate}>
            {busy ? (
              <LoaderCircle className="spin" size={17} />
            ) : (
              <Sparkles size={17} />
            )}
            {busy ? "Tworzę zestaw…" : "Rozpocznij zestaw"}
          </button>
        </div>
        {error && (
          <p className="error-banner" role="alert">
            {error}
          </p>
        )}
      </section>
    );
  const item = current.set.items[current.index];
  const chosen = current.answers[current.index];
  const answered = chosen >= 0;
  const written=current.writtenAnswers?.[current.index] || "";
  const input=item.format==="input";
  function checkWritten() {
    if(answered || !written.trim()) return;
    const result=checkPracticeInput(item,written);
    const answers=[...current!.answers];answers[current!.index]=result.choice;
    onSave({...state,practice:{...current!,answers}});
  }

  const correct = current.answers.filter(
    (answer, index) => answer === current.set.items[index].answer,
  ).length;
  const completed = !!current.completedAt;
  return (
    <section className="reading-practice skill-practice">
      <div className="row between">
        <button className="text-link muted" onClick={onExit}>
          <Pause size={17} /> Zrób przerwę
        </button>
        <span className="badge lavender">
          {labels[kind]} · {current.set.level}
        </span>
      </div>
      {completed ? (
        <div className="card reading-result">
          <CheckCircle2 size={32} />
          <h2>
            {correct} / {current.set.items.length} poprawnych odpowiedzi
          </h2>
          <p>
            Zestaw zapisaliśmy w historii. Możesz od razu rozpocząć kolejny.
          </p>
          <button className="btn primary" disabled={busy} onClick={generate}>
            {busy ? (
              <LoaderCircle className="spin" size={17} />
            ) : (
              <RotateCcw size={17} />
            )}
            Następny zestaw
          </button>
        </div>
      ) : (
        <section className="card practice-card">
          <div className="row between wrap">
            <span className="badge gray">
              {item.category === "grammar" ? "Gramatyka" : "Idiom"} ·{" "}
              {current.set.source === "ai" ? "AI" : "Gotowy zestaw · tematyka ogólna"}
            </span>
            <b>
              {current.index + 1} / {current.set.items.length}
            </b>
          </div>
          <Progress
            value={
              ((current.index + Number(answered)) / current.set.items.length) *
              100
            }
            aria-label="Postęp zestawu"
          />
          <ExerciseKind kind={item.category==="grammar"?"Gramatyka":"Idiomy"} detail={input?"Wpisz odpowiedź":"Wybierz odpowiedź"}/>
          <h2>{item.prompt}</h2>
          <div className="practice-context">
            <p lang="en">{item.context}</p>
            <ExerciseAudio text={exerciseAudioText(item.context,answered,item.options[item.answer])} solved={answered} speak={speak} prefetch={prefetch} stop={stop}/>
            {answered && <ReportExercise snapshot={{mode:labels[kind],question:item.prompt+"\n"+item.context,answer:input ? written : item.options[chosen] || "",expected:[item.options[item.answer],...(item.acceptedAnswers || [])],target:practiceTarget(item)}}/>}

          </div>
          {input ? <form className="answer-form production-answer-form" onSubmit={e=>{e.preventDefault();checkWritten();}}>
            <HintDisclosure key={`${current.set.id}:${current.index}`} text={item.inputHint || "Dobierz formę do kontekstu zdania."}/><label htmlFor="mixed-answer" className="sr-only">Twoja odpowiedź</label>
            <input id="mixed-answer" autoComplete="off" spellCheck={false} maxLength={500} placeholder="Wpisz odpowiedź…" value={written} disabled={answered} onChange={e=>{
              const writtenAnswers=current.set.items.map((_,i)=>current.writtenAnswers?.[i] || "");writtenAnswers[current.index]=e.target.value;
              onSave({...state,practice:{...current,writtenAnswers}});
            }}/>
            {!answered && <button className="btn primary" disabled={!written.trim()} type="submit">Sprawdź</button>}
          </form> : <div className="answer-options practice-options">
            {item.options.map((option, index) => (
              <button
                key={option}
                disabled={answered}
                aria-pressed={chosen === index}
                className={
                  (chosen === index ? "chosen " : "") +
                  (answered && item.answer === index ? "answer-correct" : "") +
                  (answered && chosen === index && chosen !== item.answer
                    ? " answer-wrong"
                    : "")
                }
                onClick={() => {
                  const answers = [...current.answers];
                  answers[current.index] = index;
                  onSave({ ...state, practice: { ...current, answers } });
                }}
              >
                <span>{"ABCD"[index]}</span>
                {option}
              </button>
            ))}
          </div>}
          {answered && (
            <div
              className={
                "feedback " + (chosen === item.answer ? "correct" : "wrong")
              }
            >
              <div>
                <b>
                  {chosen === item.answer
                    ? "Dobrze!"
                    : `Niepoprawna odpowiedź. Poprawna: ${input ? item.options[item.answer] : "ABCD"[item.answer]}`}
                </b>
                <AnswerExplanation key={`${current.set.id}:${current.index}`} correct={chosen === item.answer}><p>{item.explanation}</p>
                <p className="sentence-translation">{item.translation}</p></AnswerExplanation>
              </div>
            </div>
          )}
          {answered && (
            <button
              className="btn primary practice-next"
              onClick={() => {
                if (current.index + 1 < current.set.items.length) {
                  onSave({
                    ...state,
                    practice: { ...current, index: current.index + 1 },
                  });
                  return;
                }
                const completedAt = Date.now();
                onSave({
                  ...state,
                  practice: { ...current, completedAt },
                  practiceHistory: [
                    ...(state.practiceHistory || []),
                    {
                      id: current.set.id,
                      at: completedAt,
                      kind,
                      level: current.set.level,
                      correct,
                      total: current.set.items.length,
                      title: current.set.title,
                    },
                  ],
                });
              }}
            >
              {current.index + 1 < current.set.items.length
                ? "Następne pytanie"
                : "Zakończ zestaw"}
              <ArrowRight size={17} />
            </button>
          )}
        </section>
      )}
      {error && (
        <p className="error-banner" role="alert">
          {error}
        </p>
      )}
    </section>
  );
}
export function NextWords({
  state,
  onSave,
  ai,
  speak,
  onExplore,
}: {
  state: State;
  onSave: (s: State) => boolean;
  ai: boolean;
  speak: (s: string) => void;
  onExplore: (term: string) => void;
}) {
  const [items, setItems] = useState<Recommendation[] | null>(null),
    [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  const local = recommendations(state);
  const list = (items || local).filter(
    (r) =>
      !state.words.some(
        (w) => !w.archived && w.en.toLowerCase() === r.term.toLowerCase(),
      ),
  );
  const mastered = state.words
    .filter((w) => !w.archived)
    .flatMap((w) =>
      w.meanings
        .filter((m) => mastery(m) >= MASTERED_THRESHOLD)
        .map((m) => ({
          en: w.en,
          translation: m.translation,
          level: m.level || w.level,
        })),
    )
    .slice(0, 15);
  return (
    <section className="card next-words">
      <div className="section-heading">
        <div>
          <h2>Gotowość na krok dalej?</h2>
          <p className="small muted">
            Podobny sens, bogatsze słownictwo. Zwróć uwagę na różnice.
          </p>
        </div>
        <Sparkles className="purple" size={24} />
      </div>
      {list.map((r) => (
        <div className="next-word" key={r.term}>
          <div className="row between">
            <span className="small muted">Znasz: {r.known}</span>
            <span className="badge lavender">około {r.level}</span>
          </div>
          <h3>
            {r.term}{" "}
            <button
              aria-label={`Posłuchaj ${r.term}`}
              className="icon-btn"
              onClick={() => speak(r.term)}
            >
              <Volume2 size={17} />
            </button>
          </h3>
          <p>{r.translation}</p>
          <p className="small muted">{r.difference}</p>
          <p className="next-word-example">“{r.example}”</p>
          <button
            className="text-link"
            onClick={() => {
              if (onSave(mergeSuggestions(state, recommendationLookup(r), [0])))
                toast.success("Dodano do kolekcji Krok dalej.");
            }}
          >
            <Plus size={16} /> Wybierz znaczenie
          </button>
        </div>
      ))}
      {!list.length && (
        <p className="small muted">
          {mastered.length
            ? "Brak nowych propozycji w bazie startowej. AI może dobrać kolejne."
            : "Gdy opanujesz znaczenia na co najmniej 80%, zaproponujemy kolejny krok."}
        </p>
      )}
      {ai && mastered.length > 0 && (
        <button
          className="btn secondary"
          disabled={busy}
          onClick={async () => {
            setBusy(true);
            setError("");
            try {
              const d = await tutorRequest<{ items: Recommendation[] }>({
                action: "recommend",
                known: mastered,
                existing: state.words.map((w) => w.en).slice(0, 500),
              });
              setItems(d.items);
            } catch (e) {
              setError((e as Error).message);
            } finally {
              setBusy(false);
            }
          }}
        >
          {busy ? "Dobieram propozycje…" : "Dobierz propozycje z AI"}{" "}
          <Sparkles size={16} />
        </button>
      )}
      {error && <p className="error-text">{error}</p>}
    </section>
  );
}
