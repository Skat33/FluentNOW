"use client";
import {ReportSync} from "./report-sync";
import {ExerciseKind} from "./exercise-kind";
import {vocabularyTarget} from "@/lib/report-corrections";
import { CombinedPractice } from "./combined-practice";
import { makeCombinedSession, orderCombinedTasks, studyLabels, type StudyMode, type CombinedSession } from "@/lib/combined-session";
import { useAnswerScroll } from "./use-answer-scroll";
import { ReportScope, ReportExercise, ExerciseReports } from "./exercise-reports";
import { ExerciseAudio } from "./exercise-audio";
import { vocabularyAudioText } from "@/lib/exercise-audio";
import { availableExampleCount } from "@/lib/example-pool";
import { AnswerExplanation } from "./answer-explanation";
import { VocabularyPreparation } from "./vocabulary-preparation";
import { useState, useEffect, useRef, useMemo, useReducer } from "react";
import { useVoice } from "./use-voice";
import { ProductionPractice } from "./production-practice";
import { GeminiSettings } from "./gemini-settings";
import {
  disconnected,
  readApiJson,
  type GeminiConnection,
} from "@/lib/gemini-client";
import {
  QuickAdd,
  ReadingPractice,
  SkillPractice,
  NextWords,
  Highlight,
  SentenceTranslation,
  tutorRequest,
} from "./tutor-ui";
import { examplePair, localGrade, vocabularyAnswers, estimatedLevel } from "@/lib/tutor-local";
import type {
  Grade,
  ExamplePair,
  Lookup,
  ExampleRefresh,
  PracticeKind,
} from "@/lib/tutor-types";
import { stateSchema } from "@/lib/state-schema";
import {
  initialNavigation,
  navigationReducer,
  type View,
} from "./fluent-navigation";
import { TodayView } from "./views/today-view";
import { WordsView } from "./views/words-view";
import { CollectionsView } from "./views/collections-view";
import { StudyView } from "./views/study-view";
import { StatsView } from "./views/stats-view";
import { SettingsView } from "./views/settings-view";
import {
  clearQueuedState,
  compactReviews,
  mergeStates,
  queuedState,
  queueState,
} from "@/lib/state-sync";
import {
  BookOpen,
  LayoutDashboard,
  Layers,
  ChartNoAxesCombined,
  Settings,
  Plus,
  Search,
  ArrowRight,
  ArrowUpRight,
  Volume2,
  Flame,
  Target,
  Check,
  ChevronRight,
  Clock,
  Hourglass,
  Headphones,
  PenLine,
  Brain,
  Repeat2,
  Sparkles,
  Briefcase,
  Plane,
  MessagesSquare,
  Heart,
  Utensils,
  Star,
  MoreHorizontal,
  Sun,
  Moon,
  Download,
  Upload,
  Pause,
  Play,
  X,
  ArrowLeft,
  Lightbulb,
  CheckCircle2,
  TriangleAlert,
  CloudCheck,
  CloudOff,
  LogOut,
  Maximize2,
  Minimize2,
  RotateCcw,
  Trash2,
  GraduationCap,
  AudioLines,
  CalendarDays,
  ArrowLeftRight,
  FolderPlus,
  HelpCircle,
  LoaderCircle,
} from "lucide-react";
import {
  SidebarProvider,
  Sidebar,
  SidebarContent,
  SidebarHeader,
  SidebarFooter,
  SidebarMenu,
  SidebarMenuItem,
  SidebarMenuButton,
} from "@/components/ui/sidebar";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import {
  AlertDialog,
  AlertDialogContent,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogCancel,
  AlertDialogAction,
} from "@/components/ui/alert-dialog";
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from "@/components/ui/select";
import { Progress } from "@/components/ui/progress";
import { Switch } from "@/components/ui/switch";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Toaster, toast } from "sonner";
import {
  seed,
  mastery,
  MASTERED_THRESHOLD,
  wordMastery,
  due,
  status,
  makeSession,
  exercisePromptAudioAllowed,
  recordAnswer,
  normalize,
  skillNames,
  exerciseNames,
  meaningOptions,
  clozeText,
  clozeSpan,
  migrateState,
  State,
  Word,
  Meaning,
  Skill,
} from "@/lib/learning";
const nav = [
  { id: "today", label: "Dzisiaj", icon: LayoutDashboard },
  { id: "words", label: "Mój słownik", icon: BookOpen },
  { id: "collections", label: "Kolekcje", icon: Layers },
  { id: "study", label: "Ćwiczenia", icon: Brain },
  { id: "stats", label: "Postępy", icon: ChartNoAxesCombined },
] as const;
const icons = [
  MessagesSquare,
  Plane,
  Briefcase,
  GraduationCap,
  Heart,
  Utensils,
];
const dayKey = (n: number) => new Date(n).toLocaleDateString("sv-SE");
const dateLabel = (n: number) =>
  !n
    ? "Pierwsza powtórka"
    : n <= Date.now()
      ? "Dzisiaj"
      : new Date(n).toLocaleDateString("pl-PL", {
          day: "numeric",
          month: "short",
        });
function Choice({
  value,
  onChange,
  items,
  label,
}: {
  value: string;
  onChange: (s: string) => void;
  items: string[];
  label: string;
}) {
  return (
    <Select value={value} onValueChange={onChange}>
      <SelectTrigger aria-label={label}>
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {items.map((s) => (
          <SelectItem key={s} value={s}>
            {s}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
function blankMeaning(): Meaning {
  return {
    id: crypto.randomUUID(),
    translation: "",
    definition: "",
    examples: [""],
    context: "",
    register: "neutralny",
    natural: "",
    scores: {},
  };
}
function blankWord(collection = "Codzienne rozmowy"): Word {
  return {
    id: crypto.randomUUID(),
    en: "",
    ipa: "",
    pos: "rzeczownik",
    level: "",
    collection,
    tags: [],
    source: "",
    note: "",
    forms: "",
    collocations: "",
    synonyms: "",
    antonyms: "",
    important: false,
    hard: false,
    archived: false,
    created: Date.now(),
    meanings: [blankMeaning()],
  };
}
function download(name: string, body: string, type = "application/json") {
  const a = document.createElement("a");
  const u = URL.createObjectURL(new Blob([body], { type }));
  a.href = u;
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(u), 1000);
}
function parseDelimited(text: string): string[][] {
  const sep = text.includes("\t")
    ? "\t"
    : text.split("\n")[0].includes(";")
      ? ";"
      : ",";
  const rows: string[][] = [];
  let row: string[] = [],
    v = "",
    q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') {
      if (q && text[i + 1] === '"') {
        v += '"';
        i++;
      } else q = !q;
    } else if (c === sep && !q) {
      row.push(v);
      v = "";
    } else if (c === "\n" && !q) {
      row.push(v.replace(/\r$/, ""));
      rows.push(row);
      row = [];
      v = "";
    } else v += c;
  }
  if (q) throw new Error("Niedomknięty cudzysłów w pliku.");
  if (v || row.length) {
    row.push(v);
    rows.push(row);
  }
  return rows;
}
export default function Fluent({
  user,
}: {
  user: {
    name: string;
    email: string;
  } | null;
}) {
  const [quickAdd, setQuickAdd] = useState(false);
  const [quickTerm, setQuickTerm] = useState("");
  const [connection, setConnection] = useState<GeminiConnection>(disconnected);
  const aiAvailable = connection.connected;
  const speechAvailable = aiAvailable && !!connection.speechModel;
  const [readingMode, setReadingMode] = useState(false);
  const [practiceMode, setPracticeMode] = useState<PracticeKind | "production" | null>(null);
  const [grading, setGrading] = useState(false);
  const [grade, setGrade] = useState<Grade | null>(null);
  const [contextBusy, setContextBusy] = useState(false);
  const [levelBusy, setLevelBusy] = useState(false);
  const [sceneBusy, setSceneBusy] = useState<string | null>(null);
  const [sceneDrafts, setSceneDrafts] = useState<Record<string, string>>({});
  const gradingSeq = useRef(0);
  const [state, setState] = useState<State>(() => seed());
  const stateRef = useRef(state);
  const revision = useRef(0);
  const ready = useRef(false);
  const saveChain = useRef(Promise.resolve());
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pendingState = useRef<State | null>(null);
  const saving = useRef(false);
  const [sync, setSync] = useState(
    user ? "Łączenie…" : "Zapis lokalny na tym urządzeniu",
  );
  const [navigation, dispatchNavigation] = useReducer(
    navigationReducer,
    initialNavigation,
  );
  const view = navigation.view;
  const detail = navigation.detail;
  const setView = (next: View) =>
    dispatchNavigation({ type: "navigate", view: next });
  const setDetail = (id: string | null) => {
    dispatchNavigation(id ? { type: "open-word", id } : { type: "close-word" });
    if (id) window.location.hash = `words/${encodeURIComponent(id)}`;
    else if (window.location.hash.startsWith("#words/"))
      history.replaceState(null, "", "#words");
  };
  const [dark, setDark] = useState(false);
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState("Wszystkie");
  const [collectionFilter, setCollectionFilter] =
    useState("Wszystkie kolekcje");
  const [sort, setSort] = useState("Ostatnio dodane");
  const [editing, setEditing] = useState<Word | null>(null);
  const [importOpen, setImportOpen] = useState(false);
  const [importText, setImportText] = useState("");
  const [importError, setImportError] = useState("");
  const [collectionOpen, setCollectionOpen] = useState(false);
  const [collectionName, setCollectionName] = useState("");
  const [minutes, setMinutes] = useState("5");

  const [selectedModes,setSelectedModes]=useState<StudyMode[]>(['mixed']);
  const mode=selectedModes[0] || 'mixed';
  const chooseMany=selectedModes.length>1;
  const [combinedActive,setCombinedActive]=useState(false);
  const [combinedDraft,setCombinedDraft]=useState<CombinedSession|null>(null);
  const [shuffleSession,setShuffleSession]=useState(false);
  const [exitAction,setExitAction]=useState<(()=>void)|null>(null);
  const [focus, setFocus] = useState(false);
  const [active, setActive] = useState(false);
  const [answer, setAnswer] = useState("");
  const [hint, setHint] = useState(false);
  const [showVariants, setShowVariants] = useState(false);
  const [feedback, setFeedback] = useState<"correct" | "wrong" | null>(null);
  const [revealed, setRevealed] = useState(false);
  const answerReviewRef = useAnswerScroll(!!feedback || revealed);
  const [confidence, setConfidence] = useState("2");
  const [answerSeconds, setAnswerSeconds] = useState(0);
  const [displaySeconds, setDisplaySeconds] = useState(0);
  const timerStopped = useRef(false);
  const started = useRef(0);
  const [confirm, setConfirm] = useState<"reset" | "delete" | null>(null);
  const [install, setInstall] = useState<any>(null);
  const [error, setError] = useState("");
  const [hasSpeech, setHasSpeech] = useState(true);
  const [shortcut, setShortcut] = useState("Ctrl K");
  const searchRef = useRef<HTMLInputElement>(null);
  useEffect(() => {
    stateRef.current = state;
  }, [state]);
  useEffect(() => {
    const ac = new AbortController();
    fetch("/api/gemini", { cache: "no-store", signal: ac.signal })
      .then((r) => readApiJson<GeminiConnection>(r))
      .then((d) => {
        if (!ac.signal.aborted) setConnection(d);
      })
      .catch(() => {});
    return () => ac.abort();
  }, []);
  const {
    speak,
    prefetch,
    prefetchMany,
    stop: stopSpeech,
    loading: speechLoading,
    playbackBlocked,
    resumeBlockedPlayback,
    voices,
    voiceLabel,
    isNaturalVoice,
  } = useVoice(aiAvailable, state.settings, connection.speechModel);
  useEffect(() => {
    setHasSpeech("speechSynthesis" in window);
    setShortcut(/Mac|iPhone|iPad/i.test(navigator.platform) ? "⌘ K" : "Ctrl K");
    const theme = localStorage.getItem("fluent-theme") === "dark";
    setDark(theme);
    document.documentElement.classList.toggle("dark", theme);
    const onInstall = (e: Event) => {
      e.preventDefault();
      setInstall(e);
    };
    window.addEventListener("beforeinstallprompt", onInstall);
    if ("serviceWorker" in navigator)
      navigator.serviceWorker.register("/sw.js").catch(() => {});
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === "k") {
        e.preventDefault();
        searchRef.current?.focus();
      }
    };
    window.addEventListener("keydown", onKey);
    if (user)
      fetch("/api/state", { cache: "no-store" })
        .then(async (r) => {
          const d = await r.json();
          if (!r.ok) throw new Error(d.error);
          const remote = migrateState(d.state);
          const queued = await queuedState();
          const migrated = queued
            ? compactReviews(mergeStates(queued, remote))
            : remote;
          if (migrated.settings.voiceRevision !== 2)
            migrated.settings = {
              ...migrated.settings,
              accent: "en-US",
              voiceRevision: 2,
            };
          setState(migrated);
          stateRef.current = migrated;
          revision.current = d.revision;
          ready.current = true;
          if (queued) {
            pendingState.current = migrated;
            setSync("Synchronizowanie zmian offline…");
            setTimeout(() => {
              saveChain.current = flushSaves();
            }, 0);
          } else setSync("Zsynchronizowano");
        })
        .catch((e) => {
          queuedState().then((queued) => {
            if (queued) {
              const migrated = migrateState(queued);
              setState(migrated);
              stateRef.current = migrated;
              ready.current = true;
              setSync("Offline · zapis lokalny");
            } else {
              setError(e.message);
              ready.current = true;
              setSync("Offline · zapis lokalny");
            }
          });
        });
    else
      queuedState()
        .then((queued) => {
          if (queued) {
            const migrated = migrateState(queued);
            setState(migrated);
            stateRef.current = migrated;
          }
          ready.current = true;
          setSync("Zapis lokalny na tym urządzeniu");
        })
        .catch(() => {
          ready.current = true;
          setSync("Tryb gościa");
        });
    return () => {
      window.removeEventListener("beforeinstallprompt", onInstall);
      window.removeEventListener("keydown", onKey);
      if (saveTimer.current) clearTimeout(saveTimer.current);
    };
  }, []);
  async function flushSaves() {
    if (!user || saving.current || !ready.current) return;
    saving.current = true;
    try {
      while (pendingState.current) {
        const candidate = pendingState.current;
        pendingState.current = null;
        let saved = false;
        for (let attempt = 0; attempt < 3 && !saved; attempt++) {
          try {
            const response = await fetch("/api/state", {
              method: "PUT",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                state: candidate,
                revision: revision.current,
              }),
            });
            const data = await response.json().catch(() => ({}));
            if (response.status === 409 && data.state) {
              const merged = compactReviews(
                mergeStates(candidate, migrateState(data.state)),
              );
              revision.current = data.revision;
              pendingState.current = merged;
              stateRef.current = merged;
              setState(merged);
              await queueState(merged);
              saved = true;
              break;
            }
            if (!response.ok)
              throw new Error(
                data.error || `Błąd zapisu HTTP ${response.status}`,
              );
            revision.current = data.revision;
            saved = true;
            setError("");
            setSync("Zsynchronizowano");
          } catch (error) {
            if (attempt < 2)
              await new Promise((resolve) =>
                setTimeout(resolve, 300 * 2 ** attempt),
              );
            else {
              pendingState.current = candidate;
              await queueState(candidate);
              setError((error as Error).message || "Brak sieci.");
              setSync("Offline · zapis lokalny");
            }
          }
        }
        if (!saved) break;
      }
      if (!pendingState.current) await clearQueuedState();
    } finally {
      saving.current = false;
    }
  }
  function persist(next: State) {
    if (user && !ready.current) {
      toast.error("Poczekaj na pobranie konta lub odśwież stronę.");
      return false;
    }
    const previousMeaningIds = new Set(
      stateRef.current.words.flatMap((word) =>
        word.meanings.map((meaning) => meaning.id),
      ),
    );
    next = {...next,words:next.words.map(word => ({...word,meanings:word.meanings.map(meaning =>
      !previousMeaningIds.has(meaning.id) && !meaning.enrichment && meaning.examples.length < 15
        ? {...meaning,enrichment:{phase:"examples" as const,groups:[],attempts:0,retryAt:0}} : meaning)}))};
    const newAudio = next.words.flatMap((word) =>
      word.meanings
        .filter((meaning) => !previousMeaningIds.has(meaning.id))
        .flatMap((meaning) => [
          { text: word.en, mode: "word" as const },
          ...meaning.examples.map((text) => ({
            text,
            mode: "sentence" as const,
          })),
        ]),
    );
    if (newAudio.length) prefetchMany(newAudio);
    const compacted = compactReviews(next);
    setState(compacted);
    stateRef.current = compacted;
    if (!user) {
      queueState(compacted).catch(() => {});
      setSync("Zapisano na tym urządzeniu");
      return true;
    }
    setSync("Zapis lokalny…");
    pendingState.current = compacted;
    queueState(compacted).catch(() => {});
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => {
      saveChain.current = flushSaves();
    }, 2500);
    return true;
  }
  useEffect(() => {
    const online = () => {
      if (pendingState.current) saveChain.current = flushSaves();
    };
    const message = (event: MessageEvent) => {
      if (event.data?.type === "FLUENT_SYNC" && pendingState.current)
        saveChain.current = flushSaves();
    };
    window.addEventListener("online", online);
    navigator.serviceWorker?.addEventListener("message", message);
    return () => {
      window.removeEventListener("online", online);
      navigator.serviceWorker?.removeEventListener("message", message);
    };
  }, [user]);
  const exerciseInProgress = view==='study' && (
    (combinedActive && !!state.combined && !state.combined.completedAt) ||
    (active && !!state.session && state.session.index<state.session.tasks.length) ||
    (readingMode && !!state.reading && !state.reading.submitted) ||
    (practiceMode==='production' && !!state.production && !state.production.completedAt) ||
    (practiceMode && practiceMode!=='production' && !!state.practice && state.practice.set.kind===practiceMode && !state.practice.completedAt)
  );
  function requestExit(action:()=>void) {
    if(exerciseInProgress){history.replaceState(null,'','#study');setExitAction(()=>action);}
    else {stopSpeech();action();}
  }
  const navigationGuard=useRef(requestExit);navigationGuard.current=requestExit;
  useEffect(()=>{
    if(!exerciseInProgress)return;
    const beforeUnload=(e:BeforeUnloadEvent)=>{e.preventDefault();e.returnValue='';};
    window.addEventListener('beforeunload',beforeUnload);
    return()=>window.removeEventListener('beforeunload',beforeUnload);
  },[exerciseInProgress]);
  function go(v: View) {
    requestExit(()=>{
      gradingSeq.current++;setGrading(false);setReadingMode(false);setPracticeMode(null);setCombinedActive(false);
      setView(v);setActive(false);setFocus(false);
      history.pushState(null,'','#'+v);window.scrollTo(0,0);
    });
  }
  useEffect(() => {
    const onHash=()=>{
      const hash=window.location.hash;
      const [section,encodedId]=hash.slice(1).split('/');
      const v=section as View;
      if(![...nav.map(n=>n.id),'settings'].includes(v))return;
      navigationGuard.current(()=>{
        if(v==='words' && encodedId)dispatchNavigation({type:'open-word',id:decodeURIComponent(encodedId)});
        else dispatchNavigation({type:'navigate',view:v});
        setActive(false);setCombinedActive(false);setReadingMode(false);setPracticeMode(null);setFocus(false);
        history.replaceState(null,'',hash);
      });
    };
    onHash();window.addEventListener('hashchange',onHash);
    return()=>window.removeEventListener('hashchange',onHash);
  },[]);
  const words = state.words.filter((w) => !w.archived);
  const meanings = words.flatMap((w) => w.meanings);
  const missingLevels = words.reduce(
    (count, word) =>
      count +
      word.meanings.filter((meaning) => !(meaning.level || word.level)).length,
    0,
  );
  const dueCount = meanings.filter((m) => due(m) <= Date.now()).length;
  const learned = meanings.filter((m) => mastery(m) >= MASTERED_THRESHOLD).length;
  const realReviews = state.reviews.filter((review) => !review.demo);
  const today = realReviews.filter((r) => dayKey(r.at) === dayKey(Date.now()));
  const summaryCount = (state.reviewSummaries || []).reduce(
    (sum, item) => sum + item.count,
    0,
  );
  const summaryCorrect = (state.reviewSummaries || []).reduce(
    (sum, item) => sum + item.correct,
    0,
  );
  const accuracy =
    realReviews.length + summaryCount
      ? Math.round(
          ((realReviews.filter((r) => r.correct && !r.hint).length +
            summaryCorrect) /
            (realReviews.length + summaryCount)) *
            100,
        )
      : 0;
  const dailyPercent = Math.min(
    100,
    (today.length / state.settings.goal) * 100,
  );
  const week = Array.from({ length: 7 }, (_, i) => {
    const d = Date.now() - (6 - i) * 86400000;
    return {
      day: new Date(d)
        .toLocaleDateString("pl-PL", { weekday: "short" })
        .replace(".", ""),
      count: realReviews.filter((r) => dayKey(r.at) === dayKey(d)).length,
    };
  });
  let streak = 0;
  for (let i = 0; i < 365; i++) {
    if (
      realReviews.some(
        (r) => dayKey(r.at) === dayKey(Date.now() - i * 86400000),
      )
    )
      streak++;
    else if (i > 0) break;
  }
  const displayed = state.words
    .filter(
      (w) =>
        (filter === "Archiwum" ? w.archived : !w.archived) &&
        (filter === "Wszystkie" ||
          filter === "Archiwum" ||
          (filter === "Ważne" && w.important) ||
          status(w) === filter) &&
        (collectionFilter === "Wszystkie kolekcje" ||
          w.collection === collectionFilter) &&
        [w.en, ...w.meanings.map((m) => m.translation), ...w.tags]
          .join(" ")
          .toLowerCase()
          .includes(query.toLowerCase()),
    )
    .sort((a, b) =>
      sort === "Alfabetycznie"
        ? a.en.localeCompare(b.en)
        : sort === "Najtrudniejsze"
          ? wordMastery(a) - wordMastery(b)
          : b.created - a.created,
    );
  const selected = state.words.find((w) => w.id === detail);
  async function refreshMeaningExamples(word: Word, meaning: Meaning) {
    const scene = (sceneDrafts[meaning.id] ?? meaning.scene ?? "").trim();
    if (!scene || sceneBusy) return;
    setSceneBusy(meaning.id);
    try {
      const refreshed = await tutorRequest<ExampleRefresh>({
        action: "recontextualize",
        meaningId: meaning.id,
        term: word.en,
        translation: meaning.translation,
        scene,
      });
      const next: State = {
        ...state,
        words: state.words.map((current) =>
          current.id === word.id
            ? {
                ...current,
                updatedAt: Date.now(),
                meanings: current.meanings.map((item) =>
                  item.id === meaning.id
                    ? {
                        ...item,
                        topic: item.topic || word.collection,
                        scene,
                        usedExamples: [],
                        enrichment: {phase:"examples",groups:[],attempts:0,retryAt:0},
                        examples: refreshed.examples.map((pair) => pair.en),
                        exampleTranslations: refreshed.examples.map(
                          (pair) => pair.pl,
                        ),
                        exampleFocusEn: refreshed.examples.map(
                          (pair) => pair.focusEn,
                        ),
                        exampleFocusPl: refreshed.examples.map(
                          (pair) => pair.focusPl,
                        ),
                      }
                    : item,
                ),
              }
            : current,
        ),
      };
      if (persist(next)) toast.success("Przykłady zapisano w wybranej scenie.");
    } catch (error) {
      toast.error((error as Error).message);
    } finally {
      setSceneBusy(null);
    }
  }
  const session = state.session;
  const task = session?.tasks[session.index];
  useEffect(() => {
    if (!active || view !== "study" || !task) return;
    const interval = window.setInterval(() => {
      if (!timerStopped.current)
        setDisplaySeconds(Math.max(0, Math.floor((Date.now() - started.current) / 1000)));
    }, 1000);
    return () => window.clearInterval(interval);
  }, [active, view, session?.tasks, session?.index]);
  const taskWord = state.words.find((w) => w.id === task?.wordId);
  const taskMeaning = taskWord?.meanings.find((m) => m.id === task?.meaningId);
  const example =
    taskMeaning?.examples[(task?.example ?? 0) % taskMeaning.examples.length] ||
    "";
  const exampleIndex =
    (task?.example ?? 0) % (taskMeaning?.examples.length || 1);
  const currentPair =
    taskWord && taskMeaning
      ? examplePair(taskWord, taskMeaning, exampleIndex)
      : null;
  const taskFocus=clozeSpan(example,currentPair?.focusEn || taskWord?.en || "")?.match || currentPair?.focusEn || taskWord?.en || "";
  useEffect(() => {
    if (!active || view !== "study" || !taskWord) return;
    if (task && exercisePromptAudioAllowed(task.type))
      prefetch(taskWord.en, "exercise");
    const nextTask = session?.tasks[(session?.index || 0) + 1];
    const nextWord = state.words.find((word) => word.id === nextTask?.wordId);
    if (nextWord && nextTask && exercisePromptAudioAllowed(nextTask.type))
      prefetch(nextWord.en, "exercise");
  }, [active, view, taskWord?.id, task?.type, session?.index]);
  useEffect(() => {
    if (
      !active ||
      view !== "study" ||
      !taskWord ||
      !taskMeaning ||
      currentPair ||
      session?.mode === "pairs" ||
      !example ||
      !aiAvailable
    ) {
      setContextBusy(false);
      return;
    }
    const ac = new AbortController();
    const wordId = taskWord.id,
      meaningId = taskMeaning.id,
      index = exampleIndex;
    setContextBusy(true);
    tutorRequest<ExamplePair>(
      {
        action: "context",
        term: taskWord.en,
        translation: taskMeaning.translation,
        example,
      },
      ac.signal,
    )
      .then((pair) => {
        if (ac.signal.aborted) return;
        const latest = stateRef.current;
        const w = latest.words.find((w) => w.id === wordId),
          m = w?.meanings.find((m) => m.id === meaningId);
        if (!m || m.examples[index] !== example) return;
        const translations = [...(m.exampleTranslations || [])],
          enFocus = [...(m.exampleFocusEn || [])],
          plFocus = [...(m.exampleFocusPl || [])];
        for (let i = 0; i < m.examples.length; i++) {
          translations[i] ??= "";
          enFocus[i] ??= "";
          plFocus[i] ??= "";
        }
        translations[index] = pair.pl;
        enFocus[index] = pair.focusEn;
        plFocus[index] = pair.focusPl;
        persist({
          ...latest,
          words: latest.words.map((w) =>
            w.id === wordId
              ? {
                  ...w,
                  meanings: w.meanings.map((m) =>
                    m.id === meaningId
                      ? {
                          ...m,
                          exampleTranslations: translations,
                          exampleFocusEn: enFocus,
                          exampleFocusPl: plFocus,
                        }
                      : m,
                  ),
                }
              : w,
          ),
        });
      })
      .catch(() => {})
      .finally(() => {
        if (!ac.signal.aborted) setContextBusy(false);
      });
    return () => ac.abort();
  }, [active, view, taskMeaning?.id, example, aiAvailable]);
  const options = useMemo(
    () =>
      task && taskWord && taskMeaning
        ? meaningOptions(state, taskWord, taskMeaning, task)
        : [],
    [
      task?.wordId,
      task?.meaningId,
      task?.type,
      task?.example,
      session?.index,
      state.words,
    ],
  );
  function resetQuestion() {
    gradingSeq.current++;
    setGrading(false);
    setGrade(null);
    setAnswer("");
    setHint(false);
    setShowVariants(false);
    setFeedback(null);
    setRevealed(false);
    setConfidence("2");
    setAnswerSeconds(0);
    setDisplaySeconds(0);
    timerStopped.current = false;
    started.current = Date.now();
  }
  const vocabularyUpdating = state.words.some(w=>!w.archived && w.meanings.some(m=>m.enrichment && !availableExampleCount(m))) &&
    !state.words.some(w=>!w.archived && w.meanings.some(m=>availableExampleCount(m)>0));
  const waitingForVocabulary = (id:string) => vocabularyUpdating && ["mixed","mistakes","pairs"].includes(id);
  function start(selectedMode = mode, collection?: string) {
    setCombinedActive(false);
    if (selectedMode === "reading") {
      setActive(false);
      setPracticeMode(null);
      setReadingMode(true);
      return;
    }
    const practice =
      selectedMode === "production" ? "production" : selectedMode === "grammar"
        ? "grammar"
        : selectedMode === "idioms"
          ? "idioms"
          : selectedMode === "language-mix"
            ? "mixed"
            : null;
    if (practice) {
      setActive(false);
      setReadingMode(false);
      setPracticeMode(practice);
      return;
    }
    const s = makeSession(state, Number(minutes), selectedMode, collection);
    if (!s.tasks.length) {
      toast.info(
        vocabularyUpdating ? "Zadania są aktualizowane. Gotowe ćwiczenia pojawią się automatycznie." : selectedMode === "mistakes"
          ? "Nie masz jeszcze słów wymagających trybu pomyłek."
          : "Dodaj słowa do tej kolekcji, aby rozpocząć.",
      );
      return;
    }
    if (!persist({ ...state, session: s })) return;
    setView("study");
    setActive(true);
    resetQuestion();
  }
  async function check() {
    if (!task || !taskWord || !taskMeaning || !answer.trim() || grading) return;
    const seconds=Math.max(0.1,(Date.now()-started.current)/1000);
    timerStopped.current = true;
    setDisplaySeconds(Math.floor(seconds));
    const g=localGrade(answer,task.type===2 ? {...taskWord,en:taskFocus} : taskWord,taskMeaning,task.type,example);
    setAnswerSeconds(seconds);
    setGrade(g);
    setFeedback(g.verdict==="correct" ? "correct" : "wrong");
  }
  function advance(correct: boolean) {
    if (!task) return;
    const elapsed =
      answerSeconds || Math.max(0.1, (Date.now() - started.current) / 1000);
    const next = recordAnswer(
      state,
      task,
      correct,
      elapsed,
      Number(confidence),
      hint,
      grade?.spellingCorrect ?? correct,
    );
    if (!persist(next)) return;
    resetQuestion();
  }
  function saveWord(e: React.FormEvent) {
    e.preventDefault();
    if (!editing) return;
    if (
      editing.meanings.some(
        (m) => !m.translation.trim() || !m.examples.some((e) => e.trim()),
      )
    ) {
      toast.error(
        "Dodaj tłumaczenie i przynajmniej jeden przykład dla każdego znaczenia.",
      );
      return;
    }
    const w = {
      ...editing,
      en: editing.en.trim(),
      updatedAt: Date.now(),
      meanings: editing.meanings.map((m) => {
        const indices = m.examples
          .map((e, i) => (e.trim() ? i : -1))
          .filter((i) => i >= 0);
        return {
          ...m,
          translation: m.translation.trim(),
          examples: indices.map((i) => m.examples[i]),
          exampleTranslations: indices.map(
            (i) => m.exampleTranslations?.[i] || "",
          ),
          exampleFocusEn: indices.map((i) => m.exampleFocusEn?.[i] || ""),
          exampleFocusPl: indices.map((i) => m.exampleFocusPl?.[i] || ""),
        };
      }),
    };
    const next = {
      ...state,
      words: state.words.some((x) => x.id === w.id)
        ? state.words.map((x) => (x.id === w.id ? w : x))
        : [w, ...state.words],
    };
    if (persist(next)) {
      setEditing(null);
      toast.success("Słowo zapisane. Każde znaczenie ma własny postęp.");
    }
  }
  function updateMeaning(id: string, key: string, value: unknown) {
    setEditing((w) =>
      w
        ? {
            ...w,
            meanings: w.meanings.map((m) =>
              m.id === id ? { ...m, [key]: value } : m,
            ),
          }
        : w,
    );
  }
  function importWords() {
    try {
      if (importText.trim().startsWith("{")) {
        const s = JSON.parse(importText);
        if (s.version !== 1 || !s.state)
          throw new Error("To nie jest eksport Fluent.");
        const migrated = migrateState(s.state);
        const parsed = stateSchema.safeParse(migrated);
        if (!parsed.success)
          throw new Error(
            "Niepoprawna kopia Fluent: brakuje wymaganych pól albo zawiera uszkodzone dane.",
          );
        if (persist(parsed.data)) {
          setImportOpen(false);
          toast.success("Przywrócono eksport Fluent.");
        }
        return;
      }
      const rows = parseDelimited(importText).filter((r) =>
        r.some((c) => c.trim()),
      );
      if (
        ["english", "angielski", "front", "en"].includes(
          rows[0]?.[0]?.toLowerCase(),
        )
      )
        rows.shift();
      if (!rows.length) throw new Error("Wklej przynajmniej jeden wpis.");
      if (rows.length > 500) throw new Error("Importuj do 500 znaczeń naraz.");
      const created: Word[] = [];
      for (const [i, r] of rows.entries()) {
        if (!r[0]?.trim() || !r[1]?.trim())
          throw new Error(
            `Wiersz ${i + 1}: potrzebne jest słowo i polskie tłumaczenie.`,
          );
        const existing = created.find(
          (w) => normalize(w.en) === normalize(r[0]),
        );
        const m = {
          ...blankMeaning(),
          translation: r[1].trim(),
          examples: [r[2]?.trim() || r[0].trim()],
          context: r[2]
            ? "Import"
            : "Dodaj zdanie przykładowe przed ćwiczeniem kontekstu.",
        };
        if (existing) existing.meanings.push(m);
        else
          created.push({
            ...blankWord(r[3]?.trim() || state.collections[0] || "Moje słowa"),
            en: r[0].trim(),
            level: r[5]?.trim() || "",
            tags: (r[4] || "").split(" ").filter(Boolean),
            source: "Import",
            meanings: [m],
          });
      }
      const collections = [
        ...new Set([...state.collections, ...created.map((w) => w.collection)]),
      ];
      if (
        persist({ ...state, words: [...created, ...state.words], collections })
      ) {
        setImportOpen(false);
        setImportText("");
        toast.success(
          `Dodano ${created.length} wpisów. Uzupełnij kontekst w słowniku.`,
        );
      }
    } catch (e) {
      setImportError((e as Error).message);
    }
  }
  function exportCsv() {
    const rows = [
      ["English", "Polish", "Example", "Collection", "Tags"],
      ...state.words.flatMap((w) =>
        w.meanings.map((m) => [
          w.en,
          m.translation,
          m.examples[0],
          w.collection,
          w.tags.join(" "),
        ]),
      ),
    ];
    download(
      "fluent-slownictwo.csv",
      "\ufeff" +
        rows
          .map((r) => r.map((c) => '"' + c.replace(/"/g, '""') + '"').join(","))
          .join("\r\n"),
      "text/csv;charset=utf-8",
    );
  }
  async function fillMissingLevels() {
    if (!aiAvailable || levelBusy) return;
    setLevelBusy(true);
    try {
      const next = structuredClone(state);
      const candidates = next.words
        .filter(
          (word) =>
            !word.archived &&
            word.meanings.some((meaning) => !(meaning.level || word.level)),
        )
        .slice(0, 20);
      for (const word of candidates) {
        const lookup = await tutorRequest<Lookup>({
          action: "lookup",
          term: word.en,
          collections: next.collections.slice(0, 100),
        });
        if (!lookup.exists) continue;
        word.meanings = word.meanings.map((meaning) => {
          if (meaning.level || word.level) return meaning;
          const suggestion =
            lookup.meanings.find(
              (item) =>
                normalize(item.translation) === normalize(meaning.translation),
            ) || lookup.meanings[0];
          return suggestion ? { ...meaning, level: suggestion.level } : meaning;
        });
      }
      persist(next);
      toast.success("Uzupełniono dostępne poziomy CEFR.");
    } catch (error) {
      toast.error((error as Error).message);
    } finally {
      setLevelBusy(false);
    }
  }
  const speechButton = (text: string, ipa = "", mode?: "word" | "sentence" | "exercise") => (
    <span className="speech-control">
      <button
        className="icon-btn sound"
        aria-label={`Odsłuchaj: ${text}`}
        aria-busy={speechLoading}
        onClick={(e) => {
          e.stopPropagation();
          speak(text, undefined, mode);
        }}
      >
        {speechLoading ? (
          <LoaderCircle className="spin" size={18} />
        ) : (
          <Volume2 size={18} />
        )}
      </button>
      {ipa && <span className="ipa tiny">{ipa}</span>}
    </span>
  );
  const collectionCard = (name: string, i: number) => {
    const Icon = icons[i % icons.length];
    const ws = words.filter((w) => w.collection === name);
    const value = ws.length
      ? Math.round(ws.reduce((a, w) => a + wordMastery(w), 0) / ws.length)
      : 0;
    return (
      <button
        className="collection-card"
        key={name}
        onClick={() => {
          setCollectionFilter(name);
          setQuery("");
          setFilter("Wszystkie");
          go("words");
        }}
      >
        <div className="row between">
          <span className={"collection-icon color-" + (i % 6)}>
            <Icon size={22} />
          </span>
          <ArrowUpRight size={17} className="muted" />
        </div>
        <h3>{name}</h3>
        <p>
          {ws.length} słów <span>·</span> {ws.flatMap((w) => w.meanings).length}{" "}
          znaczeń
        </p>
        <div className="row between tiny">
          <span>Opanowanie</span>
          <b>{value}%</b>
        </div>
        <Progress value={value} aria-label={`Opanowanie kolekcji ${name}`} />
      </button>
    );
  };
  const wordTable = (list: Word[], compact = false) => (
    <Table className="word-table">
      <TableHeader>
        <TableRow>
          <TableHead>Słowo / zwrot</TableHead>
          <TableHead>Znaczenie</TableHead>
          {!compact && <TableHead>Kolekcja</TableHead>}
          <TableHead>Opanowanie</TableHead>
          <TableHead>Status</TableHead>
          <TableHead>
            <span className="sr-only">Szczegóły</span>
          </TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {list.map((w) => (
          <TableRow key={w.id}>
            <TableCell>
              <div className="row">
                <button className="word-name" onClick={() => setDetail(w.id)}>
                  {w.en}
                </button>
                {speechButton(w.en, w.ipa, "word")}
                {w.important && <Star size={13} className="gold" />}
              </div>
              <span className="tiny muted">
                {w.pos} <span className="level">{w.level}</span>
              </span>
            </TableCell>
            <TableCell>
              <span>{w.meanings[0].translation}</span>
              {w.meanings.length > 1 && (
                <div className="tiny purple">
                  +{w.meanings.length - 1} inne znaczenie
                </div>
              )}
            </TableCell>
            {!compact && (
              <TableCell className="muted">{w.collection}</TableCell>
            )}
            <TableCell>
              <div className="mastery">
                <Progress
                  value={wordMastery(w)}
                  aria-label={`Opanowanie ${w.en}`}
                />
                <span>{wordMastery(w)}%</span>
              </div>
            </TableCell>
            <TableCell>
              <span
                className={
                  "badge " +
                  (status(w) === "Opanowane"
                    ? "green"
                    : status(w) === "Trudne"
                      ? "orange"
                      : status(w) === "Nowe"
                        ? "gray"
                        : "lavender")
                }
              >
                {status(w)}
              </span>
            </TableCell>
            <TableCell>
              <button
                className="icon-btn"
                aria-label={`Szczegóły ${w.en}`}
                onClick={() => setDetail(w.id)}
              >
                <ChevronRight size={17} />
              </button>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
  const weeklyCard = (
    <section className="card activity-card">
      <div className="row between">
        <h2>Twój tydzień</h2>
        <span className="tiny muted">Ostatnie 7 dni</span>
      </div>
      <div className="row week-total">
        <strong>{week.reduce((s, d) => s + d.count, 0)}</strong>
        <span>wykonanych ćwiczeń</span>
        <span className="little-spark">
          <ChartNoAxesCombined size={20} />
        </span>
      </div>
      <div
        className="week-chart"
        role="img"
        aria-label={week
          .map((d) => d.day + ": " + d.count + " ćwiczeń")
          .join(", ")}
      >
        {week.map((d, i) => (
          <div className="day-bar" key={i}>
            <span className="bar-number">{d.count}</span>
            <div
              className={"bar " + (i === 6 ? "current" : "")}
              style={{
                height: Math.max(
                  5,
                  (d.count / Math.max(20, ...week.map((x) => x.count))) * 87,
                ),
              }}
            />
            <span>{d.day}</span>
          </div>
        ))}
      </div>
      <div className="card-foot">
        <span className="dot-purple" />
        Każda mała sesja robi różnicę.
      </div>
    </section>
  );
  return (
    <SidebarProvider
      style={{ "--sidebar-width": "232px" } as React.CSSProperties}
    >
      <Toaster position="bottom-right" richColors />
      {playbackBlocked && (
        <button
          className="btn primary audio-unlock"
          onClick={resumeBlockedPlayback}
        >
          <Play size={16} /> Uruchom dźwięk
        </button>
      )}
      <a href="#main" className="skip-link">
        Przejdź do treści
      </a>
      <Sidebar className={focus ? "focus-hidden" : "app-sidebar"}>
        <SidebarHeader>
          <button className="brand" onClick={() => go("today")}>
            <span className="brand-mark">
              <AudioLines size={25} />
            </span>
            fluent<span className="brand-period">.</span>
          </button>
          <div className="workspace-label">TWÓJ MAŁY KROK. CODZIENNIE.</div>
        </SidebarHeader>
        <SidebarContent>
          <SidebarMenu className="main-nav">
            {nav.map((n) => (
              <SidebarMenuItem key={n.id}>
                <SidebarMenuButton
                  isActive={view === n.id}
                  onClick={() => go(n.id)}
                  className="nav-button"
                >
                  <n.icon size={20} />
                  <span>{n.label}</span>
                  {n.id === "study" && (
                    <span className="nav-count">{dueCount}</span>
                  )}
                </SidebarMenuButton>
              </SidebarMenuItem>
            ))}
          </SidebarMenu>
          <div className="side-collections">
            <div className="row between">
              <span className="eyebrow">TWOJE KOLEKCJE</span>
              <button
                className="icon-btn"
                aria-label="Nowa kolekcja"
                onClick={() => setCollectionOpen(true)}
              >
                <Plus size={16} />
              </button>
            </div>
            {state.collections.slice(0, 3).map((n, i) => (
              <button
                key={n}
                onClick={() => {
                  setCollectionFilter(n);
                  go("words");
                }}
              >
                <span className={"collection-dot color-" + i} />
                {n}
              </button>
            ))}
          </div>
        </SidebarContent>
        <SidebarFooter>
          <button
            className={
              "side-settings " + (view === "settings" ? "selected" : "")
            }
            onClick={() => go("settings")}
          >
            <Settings size={19} /> Ustawienia
          </button>
          <div className="profile" onClick={() => go("settings")}>
            <div className="avatar">{user ? user.name.slice(0, 1) : "O"}</div>
            <div>
              <b>{user ? "Moje konto" : "Tryb gościa"}</b>
              <span>
                {user ? "Twoja przestrzeń nauki" : "AI działa bez logowania"}
              </span>
            </div>
            <ChevronRight size={16} />
          </div>
        </SidebarFooter>
      </Sidebar>
      <div className={"app-shell " + (focus ? "focused" : "")}>
        <header className={"topbar " + (focus ? "focus-hidden" : "")}>
          <div className="breadcrumb">
            Moja przestrzeń <ChevronRight size={14} />
            <b>
              {view === "settings"
                ? "Ustawienia"
                : nav.find((n) => n.id === view)?.label}
            </b>
          </div>
          <div className="top-actions">
            <label className="global-search">
              <Search size={17} />
              <input
                ref={searchRef}
                aria-label="Szukaj słowa, tłumaczenia lub tagu"
                placeholder="Znajdź słowo…"
                value={query}
                onChange={(e) => {
                  setQuery(e.target.value);
                  go("words");
                }}
              />
              <kbd>{shortcut}</kbd>
            </label>
            <button className="streak-chip" onClick={() => go("stats")}>
              <Flame size={18} />
              <b>{streak}</b>
              <span>dni z nauką</span>
            </button>
            <button
              className="avatar small-avatar"
              aria-label="Ustawienia konta"
              onClick={() => go("settings")}
            >
              {user ? user.name.slice(0, 1) : "O"}
            </button>
          </div>
        </header>
        <main id="main" className="main-content"><ReportScope.Provider value={user?.email || "guest"}><ReportSync/>
          <VocabularyPreparation state={state} onSave={persist} enabled={aiAvailable && (!user || ready.current)} />
          {error && (
            <div className="error-banner" role="alert">
              <CloudOff size={18} />
              <span>{error}</span>
              <button
                onClick={() =>
                  download(
                    "fluent-kopia.json",
                    JSON.stringify(
                      { version: 1, state: stateRef.current },
                      null,
                      2,
                    ),
                  )
                }
              >
                Zapisz kopię
              </button>
            </div>
          )}
          {view === "today" && (
            <TodayView>
              <div className="page-heading">
                <div>
                  <div className="eyebrow greeting">
                    TWÓJ ANGIELSKI, TWÓJ RYTM
                  </div>
                  <h1>
                    Dobrze Cię widzieć <span className="greeting-sun">✳</span>
                  </h1>
                  <p>Kolejny mały krok do swobodnej rozmowy.</p>
                </div>
                <button
                  className="btn primary"
                  onClick={() => {
                    setQuickTerm("");
                    setQuickAdd(true);
                  }}
                >
                  <Plus size={18} /> Dodaj słowo
                </button>
              </div>
              <div className="dashboard-grid">
                <section className="session-banner">
                  <div className="banner-copy">
                    <span className="banner-label">
                      <span /> TWOJA CODZIENNA SESJA
                    </span>
                    <h2>
                      Trochę dzisiaj.
                      <br />
                      Na dłużej w pamięci.
                    </h2>
                    <p>
                      {dueCount} znaczeń czeka na powtórkę.
                      <br />
                      Zrób dla siebie kilka dobrych minut.
                    </p>
                    <button
                      className="btn white"
                      onClick={() =>
                        state.session &&
                        state.session.index < state.session.tasks.length
                          ? (setView("study"), setActive(true), resetQuestion())
                          : start()
                      }
                    >
                      <Play size={17} fill="currentColor" />
                      {session && session.index < session.tasks.length
                        ? "Kontynuuj sesję"
                        : "Zaczynam naukę"}
                      <ArrowRight size={18} />
                    </button>
                    <span className="banner-meta">
                      <Clock size={14} /> około {minutes} min <span>·</span> do{" "}
                      {Number(minutes) * 2} ćwiczeń
                    </span>
                  </div>
                  <div className="daily-ring">
                    <div className="daily-ring-graphic">
                    <svg
                      viewBox="0 0 160 160"
                      aria-label={`Cel dzienny ${Math.round(dailyPercent)} procent`}
                    >
                      <circle cx="80" cy="80" r="65" className="ring-base" />
                      <circle
                        cx="80"
                        cy="80"
                        r="65"
                        className="ring-progress"
                        strokeDasharray={`${dailyPercent * 4.084} 408.4`}
                        transform="rotate(-90 80 80)"
                      />
                    </svg>
                    <div className="ring-label">
                      <Target size={24} />
                      <strong>
                        {today.length}
                        <span> / {state.settings.goal}</span>
                      </strong>
                      <span>cel na dziś</span>
                    </div>
                    </div>
                    <div className="ring-caption">
                      <Sparkles size={14} />{" "}
                      {dailyPercent >= 100
                        ? "Cel osiągnięty!"
                        : "Po prostu, krok po kroku"}
                    </div>
                  </div>
                </section>
                {weeklyCard}
              </div>
              <div className="stats-strip">
                <div>
                  <span className="stat-icon lavender">
                    <BookOpen size={22} />
                  </span>
                  <div>
                    <span>Słów w Twoim słowniku</span>
                    <strong>
                      {words.length}
                      <small>{meanings.length} znaczeń</small>
                    </strong>
                  </div>
                </div>
                <div>
                  <span className="stat-icon mint">
                    <CheckCircle2 size={22} />
                  </span>
                  <div>
                    <span>Opanowane znaczenia</span>
                    <strong>
                      {learned}
                      <small>już zostają z Tobą</small>
                    </strong>
                  </div>
                </div>
                <div>
                  <span className="stat-icon peach">
                    <Target size={22} />
                  </span>
                  <div>
                    <span>Skuteczność odpowiedzi</span>
                    <strong>
                      {accuracy}%<small>w swoim tempie</small>
                    </strong>
                  </div>
                </div>
              </div>
              <div className="section-heading">
                <h2>
                  Twoje kolekcje{" "}
                  <span className="count-text">{state.collections.length}</span>
                </h2>
                <button className="text-link" onClick={() => go("collections")}>
                  Wszystkie kolekcje <ArrowRight size={16} />
                </button>
              </div>
              <div className="collection-grid home-collections">
                {state.collections.slice(0, 3).map(collectionCard)}
                <button
                  className="new-collection"
                  onClick={() => setCollectionOpen(true)}
                >
                  <span>
                    <Plus size={23} />
                  </span>
                  <b>Nowa kolekcja</b>
                  <p>Zrób miejsce na nowe słowa</p>
                </button>
              </div>
              <div className="bottom-grid">
                <section className="card recent-card">
                  <div className="section-heading">
                    <h2>Ostatnio dodane</h2>
                    <button
                      className="text-link"
                      onClick={() => {
                        setCollectionFilter("Wszystkie kolekcje");
                        go("words");
                      }}
                    >
                      Cały słownik <ArrowRight size={16} />
                    </button>
                  </div>
                  {words.length ? (
                    wordTable(words.slice(0, 4), true)
                  ) : (
                    <div className="empty-state">
                      <BookOpen />
                      <h3>Pierwsze słowo zaczyna historię</h3>
                      <button
                        className="btn primary"
                        onClick={() => {
                          setQuickTerm("");
                          setQuickAdd(true);
                        }}
                      >
                        Dodaj słowo
                      </button>
                    </div>
                  )}
                </section>
                <section className="phrase-card">
                  <div className="row between">
                    <span className="eyebrow">MAŁA DAWKA ANGIELSKIEGO</span>
                    <Sparkles size={18} />
                  </div>
                  <h2>
                    “One step
                    <br />
                    at a time.”
                  </h2>
                  <p>Krok po kroku.</p>
                  <div className="phrase-context">
                    Nie musisz wiedzieć wszystkiego.
                    <br />
                    Wystarczy, że zrobisz kolejny krok.
                  </div>
                  <button
                    className="text-link"
                    aria-busy={speechLoading}
                    onClick={() => speak("One step at a time.")}
                  >
                    {speechLoading ? <LoaderCircle className="spin" size={17} /> : <Volume2 size={17} />}
                    {speechLoading ? "Przygotowuję nagranie…" : "Posłuchaj wymowy"}
                  </button>
                </section>
              </div>
              <div className="page-note">
                {state.demo
                  ? "Zestaw demonstracyjny · słowa i wcześniejsza aktywność są przykładowe."
                  : "Twoje słownictwo. Twój postęp."}
                <button onClick={() => go("settings")}>
                  {state.demo ? "Zacznij z własnymi słowami" : "Ustaw swój cel"}{" "}
                  <ArrowUpRight size={13} />
                </button>
              </div>
            </TodayView>
          )}
          {view === "words" && (
            <WordsView>
              <div className="page-heading">
                <div>
                  <div className="eyebrow">TWOJE SŁOWA W KONTEKŚCIE</div>
                  <h1>
                    Mój słownik{" "}
                    <span className="count-text">{words.length}</span>
                  </h1>
                  <p>
                    Każde znaczenie ma swoją historię. I swój rytm powtórek.
                  </p>
                </div>
                <div className="row">
                  <button
                    className="btn secondary"
                    onClick={() => setImportOpen(true)}
                  >
                    <Upload size={17} /> Importuj
                  </button>
                  <button
                    className="btn primary"
                    onClick={() => {
                      setQuickTerm("");
                      setQuickAdd(true);
                    }}
                  >
                    <Plus size={18} /> Dodaj słowo
                  </button>
                </div>
              </div>
              <section className="card vocabulary">
                <div className="filter-bar">
                  <label className="search-input">
                    <Search size={17} />
                    <input
                      placeholder="Słowo, tłumaczenie lub tag…"
                      aria-label="Szukaj w słowniku"
                      value={query}
                      onChange={(e) => setQuery(e.target.value)}
                    />
                  </label>
                  <Choice
                    value={collectionFilter}
                    onChange={setCollectionFilter}
                    items={["Wszystkie kolekcje", ...state.collections]}
                    label="Kolekcja"
                  />
                  <Choice
                    value={sort}
                    onChange={setSort}
                    items={[
                      "Ostatnio dodane",
                      "Alfabetycznie",
                      "Najtrudniejsze",
                    ]}
                    label="Sortowanie"
                  />
                </div>
                <Tabs value={filter} onValueChange={setFilter}>
                  <TabsList className="filter-tabs" variant="line">
                    {[
                      "Wszystkie",
                      "Nowe",
                      "Uczę się",
                      "Trudne",
                      "Opanowane",
                      "Ważne",
                      "Archiwum",
                    ].map((f) => (
                      <TabsTrigger key={f} value={f}>
                        {f}
                      </TabsTrigger>
                    ))}
                  </TabsList>
                </Tabs>
                {displayed.length ? (
                  wordTable(displayed)
                ) : (
                  <div className="empty-state">
                    <Search size={32} />
                    <h3>Tu jeszcze nie ma słów</h3>
                    <p>Dodaj nowe słowo lub zmień filtry wyszukiwania.</p>
                    <button
                      className="btn secondary"
                      onClick={() => {
                        setQuery("");
                        setFilter("Wszystkie");
                        setCollectionFilter("Wszystkie kolekcje");
                      }}
                    >
                      Wyczyść filtry
                    </button>
                  </div>
                )}
                <div className="table-foot">
                  <span>
                    {displayed.length} wpisów · znaczenia oceniane osobno
                  </span>
                  {collectionFilter !== "Wszystkie kolekcje" && (
                    <button
                      className="text-link"
                      onClick={() => start("mixed", collectionFilter)}
                    >
                      Ćwicz kolekcję <Play size={15} />
                    </button>
                  )}
                </div>
              </section>
            </WordsView>
          )}
          {view === "collections" && (
            <CollectionsView>
              <div className="page-heading">
                <div>
                  <div className="eyebrow">SŁOWNICTWO NA KAŻDĄ SYTUACJĘ</div>
                  <h1>Twoje kolekcje</h1>
                  <p>Porządkuj słowa tak, jak myślisz o świecie.</p>
                </div>
                <button
                  className="btn primary"
                  onClick={() => setCollectionOpen(true)}
                >
                  <FolderPlus size={18} /> Nowa kolekcja
                </button>
              </div>
              <div className="collection-grid full-collections">
                {state.collections.map(collectionCard)}
              </div>
              <section className="pair-banner">
                <ArrowLeftRight size={28} />
                <div>
                  <h2>Podobne słowa, inna historia</h2>
                  <p>
                    Automatycznie wykryte podobne znaczenia z Twojego słownika.
                  </p>
                </div>
                <button
                  className="btn secondary"
                  onClick={() => start("pairs")}
                >
                  Poćwicz różnice <ArrowRight size={16} />
                </button>
              </section>
            </CollectionsView>
          )}
          {view === "study" && combinedActive && <CombinedPractice state={state} onSave={persist} speak={speak} prefetch={prefetch} stop={stopSpeech} onExit={()=>requestExit(()=>setCombinedActive(false))}/>}
          {view === "study" && !combinedActive && readingMode && (
            <ReadingPractice
              state={state}
              onSave={persist}
              ai={aiAvailable}
              speak={speak}
              onExit={() => requestExit(()=>setReadingMode(false))}
            />
          )}
          {view === "study" && !combinedActive && practiceMode === "production" && <ProductionPractice speak={speak} prefetch={prefetch} stop={stopSpeech} state={state} onSave={persist} ai={aiAvailable} onExit={()=>requestExit(()=>setPracticeMode(null))}/>}
          {view === "study" && !combinedActive && practiceMode && practiceMode !== "production" && (
            <SkillPractice
              state={state}
              onSave={persist}
              ai={aiAvailable}
              kind={practiceMode}
              prefetch={prefetch}
              stop={stopSpeech}
              speak={speak}
              onExit={() => requestExit(()=>setPracticeMode(null))}
            />
          )}
          {view === "study" &&
            !combinedActive &&
            !readingMode &&
            !practiceMode &&
            (!active || !session) && (
              <StudyView>
                <div className="page-heading">
                  <div>
                    <div className="eyebrow">KILKA MINUT DLA SIEBIE</div>
                    <h1>Na co masz dziś ochotę?</h1>
                    <p>
                      Wybierz swój rytm. Możesz zrobić przerwę w dowolnej
                      chwili.
                    </p>
                  </div>
                </div>
                {state.combined && !state.combined.completedAt && <div className="resume-card"><Pause size={22}/><div><b>Twoja sesja łączona czeka</b><p>Ukończono {state.combined.index} z {state.combined.tasks.length} zadań. Kolejność jest zapisana.</p></div><button className="btn primary" onClick={()=>{setActive(false);setReadingMode(false);setPracticeMode(null);setCombinedActive(true);}}>Kontynuuj <Play size={16}/></button></div>}
                {session && session.index < session.tasks.length && (
                  <div className="resume-card">
                    <Pause size={22} />
                    <div>
                      <b>Twoja sesja czeka</b>
                      <p>
                        Ukończono {session.index} z {session.tasks.length}{" "}
                        ćwiczeń.
                      </p>
                    </div>
                    <button
                      className="btn primary"
                      onClick={() => {
                        setActive(true);
                        resetQuestion();
                      }}
                    >
                      Kontynuuj <Play size={16} />
                    </button>
                  </div>
                )}
                <div className="study-setup card">
                  <h2>Ile masz czasu?</h2>
                  <Tabs value={minutes} onValueChange={setMinutes}>
                    <TabsList className="duration-tabs">
                      {["5", "10", "15"].map((m) => (
                        <TabsTrigger value={m} key={m}>
                          <Clock size={17} />
                          {m} minut
                        </TabsTrigger>
                      ))}
                    </TabsList>
                  </Tabs>
                  <p className="study-selection-info" aria-live="polite">{chooseMany ? `Wybrano ${selectedModes.length} rodzaje — połączymy je w jednej sesji.` : "Zaznacz jeden lub kilka rodzajów ćwiczeń."}</p>
                  <div className="study-modes study-modes-eight">
                    {[
                      {
                        id: "mixed",
                        icon: Repeat2,
                        title: "Codzienna mieszanka",
                        desc: "Nowe i znane słowa. Powtórki dopasowane do Ciebie.",
                      },
                      {
                        id: "mistakes",
                        icon: Lightbulb,
                        title: "Tryb pomyłek",
                        desc: "Spokojnie przećwicz słowa, które potrzebują trochę uwagi.",
                      },
                      {
                        id: "pairs",
                        icon: ArrowLeftRight,
                        title: "Słowa w parach",
                        desc: "Ćwicz automatycznie wykryte słowa o podobnych znaczeniach.",
                      },
                      {
                        id: "reading",
                        icon: BookOpen,
                        title: "Czytanie",
                        desc: "Tekst dopasowany do poziomu i pytania o sens oraz szczegóły.",
                      },
                      {
                        id: "grammar",
                        icon: PenLine,
                        title: "Gramatyka",
                        desc: "Reguły ćwiczone w naturalnych zdaniach i dialogach.",
                      },
                      {
                        id: "idioms",
                        icon: MessagesSquare,
                        title: "Idiomy",
                        desc: "Znaczenie, kontekst i ważne różnice w użyciu.",
                      },
                      {
                        id: "production",
                        icon: PenLine,
                        title: "Produkcja gramatyczna",
                        desc: "Wpisz formę czasownika, odczytując wskazówki ze zdania.",
                      },
                      {
                        id: "language-mix",
                        icon: Sparkles,
                        title: "Miks językowy",
                        desc: "Gramatyka i idiomy: pytania ABCD i samodzielne wpisywanie.",
                      },
                    ].map((m) => (
                      <button
                        key={m.id}
                        aria-pressed={selectedModes.includes(m.id as StudyMode)}
                        disabled={waitingForVocabulary(m.id)}
                        className={
                          "mode-card " + ((selectedModes.includes(m.id as StudyMode)) ? "selected" : "")
                        }
                        onClick={() => setSelectedModes(prev=>prev.includes(m.id as StudyMode)?prev.filter(id=>id!==m.id):[...prev,m.id as StudyMode])}
                      >
                        {waitingForVocabulary(m.id) ? <Hourglass size={25} aria-label="Zadania są aktualizowane"/> : <m.icon size={25} />}
                        <h3>{m.title}</h3>
                        <p>{waitingForVocabulary(m.id) ? "Zadania są aktualizowane. Wróć za chwilę — ćwiczenia pojawią się automatycznie." : m.desc}</p>
                        <span className="radio-indicator">
                          {(selectedModes.includes(m.id as StudyMode)) && <Check size={12} />}
                        </span>
                      </button>
                    ))}
                  </div>
                  <div className="row between setup-footer">
                    <p>
                      <Clock size={16} /> Około {minutes} min ·{" "}
                      {!selectedModes.length ? 0 : chooseMany ? Math.round(Number(minutes)/5)*8 : mode === "reading"
                        ? "3–6"
                        : mode === "production" ? 6 : ["grammar", "idioms", "language-mix"].includes(mode)
                          ? 6
                          : makeSession(state, Number(minutes), mode).tasks
                              .length}{" "}
                      ćwiczeń
                    </p>
                    <button className="btn primary" disabled={!selectedModes.length || (!chooseMany && waitingForVocabulary(mode))} onClick={() => {
                      if(!chooseMany){start();return;}
                      const draft=makeCombinedSession(state,selectedModes,Number(minutes),false);
                      if(!draft.tasks.length){toast.info('Wybrane ćwiczenia nie mają jeszcze gotowych zadań.');return;}
                      setShuffleSession(false);setCombinedDraft(draft);
                    }}>
                      {!selectedModes.length ? "Wybierz ćwiczenie" : !chooseMany && waitingForVocabulary(mode) ? "Zadania są aktualizowane" : "Rozpocznij sesję"} <ArrowRight size={18} />
                    </button>
                  </div>
                </div>
                <NextWords
                  state={state}
                  onSave={persist}
                  ai={aiAvailable}
                  speak={speak}
                  onExplore={(term) => {
                    setQuickTerm(term);
                    setQuickAdd(true);
                  }}
                />
              </StudyView>
            )}
          {view === "study" &&
            !combinedActive &&
            !readingMode &&
            !practiceMode &&
            active &&
            session && (
              <StudyView>
                <div className="study-surface">
                  <div className="row between">
                    <button
                      className="text-link muted"
                      onClick={() => requestExit(()=>{
                        setActive(false);setFocus(false);
                        toast("Sesja wstrzymana. Możesz wrócić do niej później.");
                      })}
                    >
                      <Pause size={17} /> Zrób przerwę
                    </button>
                    <button
                      className="icon-btn"
                      aria-label={focus ? "Wyłącz skupienie" : "Tryb skupienia"}
                      onClick={() => setFocus(!focus)}
                    >
                      {focus ? (
                        <Minimize2 size={20} />
                      ) : (
                        <Maximize2 size={20} />
                      )}
                    </button>
                  </div>
                  {task && taskWord && taskMeaning ? (
                    <>
                      <div className="session-progress">
                        <span>Twój mały krok</span>
                        <b>
                          {session.index + 1} / {session.tasks.length}
                        </b>
                        <Progress
                          value={(session.index / session.tasks.length) * 100}
                          aria-label="Postęp sesji"
                        />
                      </div>
                      <section className="exercise-card card">
                        <ExerciseKind kind={task.type===4?"Słuchanie":"Słownictwo"} detail={exerciseNames[task.type]}/>
                        <div className="exercise-meta">
                          {taskWord.collection} <span>·</span>{" "}
                          {taskMeaning.level || taskWord.level} <span>·</span>{" "}
                          {taskMeaning.register}
                          <span aria-hidden="true" style={{ fontVariantNumeric: "tabular-nums", whiteSpace: "nowrap" }}>
                            {String(Math.floor(displaySeconds / 60)).padStart(2, "0")}:{String(displaySeconds % 60).padStart(2, "0")}
                          </span>
                        </div>
                        {task.type === 0 ? (
                          <>
                            <h2>
                              {taskWord.en}{" "}
                              {speechButton(taskWord.en, taskWord.ipa, "exercise")}
                            </h2>
                            <p className="ipa">{taskWord.ipa}</p>
                            <p className="example" lang="en">
                              “
                              <Highlight
                                text={example}
                                focus={currentPair?.focusEn || taskWord.en}
                              />
                              ”
                            </p>
                            {revealed ? (
                              <div className="revealed" ref={answerReviewRef}>
                                <SentenceTranslation
                                  pair={currentPair}
                                  pending={contextBusy}
                                />
                                <p className="small">
                                  <b>{taskWord.en}</b> —{" "}
                                  {taskMeaning.translation}
                                </p>
                                <p>{taskMeaning.definition}</p>
                              </div>
                            ) : (
                              <button
                                className="btn secondary"
                                onClick={() => {
                                  setRevealed(true);
                                  timerStopped.current = true;
                                  setDisplaySeconds(Math.max(0, Math.floor((Date.now() - started.current) / 1000)));
                                  setAnswerSeconds(
                                    Math.max(
                                      0.1,
                                      (Date.now() - started.current) / 1000,
                                    ),
                                  );
                                }}
                              >
                                Odsłoń znaczenie
                              </button>
                            )}
                          </>
                        ) : task.type === 1 ? (
                          <>
                            <p className="question-label">
                              Jak powiesz to po angielsku?
                            </p>
                            <h2>{taskMeaning.translation}</h2>
                            <SentenceTranslation
                              pair={currentPair}
                              pending={contextBusy}
                            />
                            <p className="muted small">
                              Podaj słowo lub pasujący zwrot. Kontekst:{" "}
                              {taskMeaning.context || taskWord.collection}
                            </p>
                          </>
                        ) : task.type === 2 ? (
                          <>
                            <p className="question-label">
                              Uzupełnij zdanie słowem ze swojego słownika
                            </p>
                            <h2 className="cloze">
                              {clozeText(
                                example,
                                currentPair?.focusEn || taskWord.en,
                              )?.replace("________",session.mode==="pairs" ? `________ (${taskMeaning.translation})` : "________") || example}
                            </h2>
                            {session.mode!=="pairs" && <SentenceTranslation
                              pair={currentPair}
                              pending={contextBusy}
                            />}
                            <p className="muted small">
                              {session.mode==="pairs" ? "Wpisz słowo pasujące do polskiej podpowiedzi w nawiasie. Dobierz formę do zdania." : "Uzupełnij angielskie zdanie tak, aby zachować powyższy sens."}
                            </p>
                          </>
                        ) : task.type === 3 ? (
                          <>
                            <p className="question-label">
                              Co oznacza wyróżnione słowo w tym kontekście?
                            </p>
                            <h2>{taskWord.en}</h2>
                            <p className="example" lang="en">
                              “
                              <Highlight
                                text={example}
                                focus={currentPair?.focusEn || taskWord.en}
                              />
                              ”
                            </p>
                            <form className="answer-form" onSubmit={(event) => { event.preventDefault(); if (!feedback && !grading) void check(); }}>
                              <label htmlFor="meaning-answer" className="sr-only">Polskie znaczenie</label>
                              <input id="meaning-answer" autoFocus value={answer} onChange={(event) => setAnswer(event.target.value)} disabled={!!feedback || grading} placeholder="Wpisz polskie znaczenie…" autoComplete="off" />
                            </form>
                            {!showVariants && !feedback && <button className="text-link" onClick={() => { setShowVariants(true); setHint(true); }}>Pokaż warianty</button>}
                            {showVariants && <div className="answer-options">
                              {options.map((o, i) => (
                                <button
                                  key={o}
                                  disabled={!!feedback}
                                  className={answer === o ? "chosen" : ""}
                                  onClick={() => setAnswer(o)}
                                >
                                  <span>{i + 1}</span>
                                  {o}
                                  {answer === o && <Check size={17} />}
                                </button>
                              ))}
                            </div>}
                          </>
                        ) : (
                          <>
                            <p className="question-label">
                              Posłuchaj i zapisz po angielsku
                            </p>
                            <button
                              className="big-audio"
                              aria-label="Odsłuchaj słowo do dyktanda"
                              onClick={() => speak(taskWord.en,undefined,"exercise")}
                            >
                              {speechLoading ? (
                                <LoaderCircle className="spin" size={38} />
                              ) : (
                                <Volume2 size={38} />
                              )}
                            </button>
                            <button
                              className="text-link"
                              onClick={() => speak(taskWord.en, true,"exercise")}
                            >
                              Odtwórz wolniej
                            </button>
                            <p className="muted small">
                              {hasSpeech || aiAvailable
                                ? voiceLabel
                                : "Brak syntezy mowy — możesz pominąć zadanie."}
                            </p>
                          </>
                        )}
                        {task.type!==4 && <ExerciseAudio text={vocabularyAudioText(example,taskFocus,![0,3].includes(task.type) && !feedback)} solved={!!feedback || revealed} speak={speak} prefetch={prefetch} stop={stopSpeech}/>}
                        {[1, 2, 4].includes(task.type) && (
                          <form
                            onSubmit={(e) => {
                              e.preventDefault();
                              if (!feedback && !grading) check();
                            }}
                            className="answer-form"
                          >
                            <label htmlFor="answer" className="sr-only">
                              Twoja odpowiedź
                            </label>
                            <input
                              id="answer"
                              key={session.index}
                              autoFocus
                              value={answer}
                              onChange={(e) => {
                                setAnswer(e.target.value);
                                setGrade(null);
                              }}
                              disabled={!!feedback || grading}
                              placeholder="Wpisz swoją odpowiedź…"
                              autoComplete="off"
                              spellCheck={false}
                            />
                          </form>
                        )}
                        {hint &&
                          !feedback &&
                          grade?.verdict !== "uncertain" && (
                            <div className="hint-box">
                              <Lightbulb size={19} />
                              <div>
                                <b>Mała podpowiedź</b>
                                <p>
                                  {task.type === 3
                                    ? taskMeaning.definition ||
                                      `Kontekst: ${taskMeaning.context}`
                                    : `Zaczyna się od „${taskWord.en.slice(0, 2)}…” i ma ${taskWord.en.length} znaków. ${taskWord.note}`}
                                </p>
                              </div>
                            </div>
                          )}
                        {feedback && (
                          <div ref={answerReviewRef} className={"feedback " + feedback} role="status">
                            {feedback === "correct" ? (
                              <CheckCircle2 size={23} />
                            ) : (
                              <Lightbulb size={23} />
                            )}
                            <div>
                              <h3>
                                {feedback === "correct"
                                  ? hint
                                    ? "Udało się z podpowiedzią"
                                    : "Dokładnie tak!"
                                  : "Niepoprawna odpowiedź"}
                              </h3>
                              <p>
                                <b>{taskWord.en}</b> — {taskMeaning.translation}
                              </p>
                              <AnswerExplanation key={`${taskMeaning.id}:${task.example}`} correct={feedback === "correct"}><p className="ipa">{taskWord.ipa}</p>
                              {feedback === "correct" && grade && (
                                <p>{grade.explanation}</p>
                              )}
                              {feedback === "wrong" && (
                                <p>
                                  {grade?.explanation ||
                                    "Sprawdź znaczenie użyte w tym kontekście."}
                                </p>
                              )}
                              <p lang="en">
                                “
                                <Highlight
                                  text={example}
                                  focus={currentPair?.focusEn || taskWord.en}
                                />
                                ”
                              </p>
                              <SentenceTranslation
                                pair={currentPair}
                                pending={contextBusy}
                              />
                              <p>
                                {taskWord.note || taskMeaning.definition}{" "}
                                {taskMeaning.natural &&
                                  `W rozmowie: ${taskMeaning.natural}.`}
                              </p>
                              <button
                                className="text-link"
                                onClick={() => speak(example,undefined,"exercise")}
                              >
                                <Volume2 size={15} /> Posłuchaj zdania
                              </button></AnswerExplanation>
                            </div>
                          </div>
                        )}
                        {(feedback || revealed) && <ReportExercise snapshot={{mode:session.mode==="pairs" ? "Słowa w parach" : exerciseNames[task.type],question:example,answer,expected:vocabularyAnswers(task.type===2 ? {...taskWord,en:taskFocus} : taskWord,taskMeaning,task.type,example),wordId:taskWord.id,meaningId:taskMeaning.id,target:vocabularyTarget(task.type===2?taskFocus:taskWord.en,taskMeaning.translation,task.type,example,vocabularyAnswers(task.type===2 ? {...taskWord,en:taskFocus} : taskWord,taskMeaning,task.type,example))}}/>}
                        {(feedback || (task.type === 0 && revealed)) && (
                          <div className="confidence">
                            <span className="sr-only">Czas odpowiedzi: {displaySeconds} sekund.</span>
                            <span>Na ile czujesz się pewnie?</span>
                            <Tabs
                              value={confidence}
                              onValueChange={setConfidence}
                            >
                              <TabsList>
                                <TabsTrigger value="1">Niepewnie</TabsTrigger>
                                <TabsTrigger value="2">
                                  Całkiem dobrze
                                </TabsTrigger>
                                <TabsTrigger value="3">
                                  Bardzo pewnie
                                </TabsTrigger>
                              </TabsList>
                            </Tabs>
                          </div>
                        )}
                        <div className="exercise-actions">
                          {task.type === 0 ? (
                            revealed && (
                              <>
                                <button
                                  className="btn secondary"
                                  onClick={() => advance(false)}
                                >
                                  Jeszcze nie pamiętam
                                </button>
                                <button
                                  className="btn primary"
                                  onClick={() => advance(true)}
                                >
                                  Pamiętam <Check size={18} />
                                </button>
                              </>
                            )
                          ) : feedback ? (
                            <button
                              className="btn primary"
                              onClick={() => advance(feedback === "correct")}
                            >
                              Dalej <ArrowRight size={18} />
                            </button>
                          ) : (
                            <>
                              <button
                                className="text-link muted"
                                onClick={() => setHint(true)}
                              >
                                <Lightbulb size={16} /> Podpowiedź
                              </button>
                              <button
                                className="btn primary"
                                disabled={!answer.trim() || grading}
                                onClick={check}
                              >
                                {grading
                                  ? "Sprawdzam znaczenie…"
                                  : "Sprawdź odpowiedź"}{" "}
                                <ArrowRight size={17} />
                              </button>
                            </>
                          )}
                        </div>
                        {task.type === 4 && !hasSpeech && !aiAvailable && (
                          <button
                            className="text-link"
                            onClick={() => {
                              const next = structuredClone(state);
                              next.session!.tasks[next.session!.index].type = 1;
                              persist(next);
                              resetQuestion();
                            }}
                          >
                            Zmień na tłumaczenie
                          </button>
                        )}
                      </section>
                      <p className="center small muted">
                        <CloudCheck size={14} className="inline-icon" />{" "}
                        {user
                          ? "Postęp zapisujemy po każdym zakończonym zadaniu."
                          : "Postęp zapisujemy lokalnie po każdym zadaniu."}
                      </p>
                    </>
                  ) : (
                    <section className="card session-finished">
                      <div className="finish-icon">
                        <Check size={42} />
                      </div>
                      <span className="eyebrow">DOBRA ROBOTA</span>
                      <h1>Mały krok za Tobą.</h1>
                      <p>Zrobiłeś dziś coś dobrego dla swojego angielskiego.</p>
                      <div className="finish-stats">
                        <div>
                          <strong>{session.tasks.length}</strong>
                          <span>ćwiczeń</span>
                        </div>
                        <div>
                          <strong>{session.correct}</strong>
                          <span>samodzielnie poprawnych</span>
                        </div>
                        <div>
                          <strong>
                            {session.tasks.length
                              ? Math.round(
                                  (session.correct / session.tasks.length) *
                                    100,
                                )
                              : 0}
                            %
                          </strong>
                          <span>skuteczności</span>
                        </div>
                      </div>
                      <p className="muted">
                        Kolejne terminy powtórek są już dopasowane do Twoich
                        odpowiedzi.
                      </p>
                      <button
                        className="btn primary"
                        onClick={() => {
                          persist({ ...state, session: null });
                          go("stats");
                        }}
                      >
                        Zobacz swój postęp <ArrowRight size={17} />
                      </button>
                    </section>
                  )}
                </div>
              </StudyView>
            )}
          {view === "stats" && (
            <StatsView>
              <div className="page-heading">
                <div>
                  <div className="eyebrow">WIĘCEJ NIŻ LICZBY</div>
                  <h1>Spójrz, ile już za Tobą.</h1>
                  <p>
                    Postęp rośnie z każdą powtórką. Przerwa go nie przekreśla.
                  </p>
                </div>
                <button
                  className="btn secondary"
                  onClick={() =>
                    download(
                      "fluent-historia.json",
                      JSON.stringify(
                        { version: 1, reviews: state.reviews },
                        null,
                        2,
                      ),
                    )
                  }
                >
                  <Download size={17} /> Eksport historii
                </button>
              </div>
              {state.demo && (
                <div className="demo-note">
                  <Sparkles size={16} /> Statystyki zawierają przykładową
                  historię zestawu startowego i Twoje nowe odpowiedzi.
                </div>
              )}
              <div className="metric-grid">
                {[
                  {
                    n: words.length,
                    l: "Poznawanych słów",
                    sub: meanings.length + " osobnych znaczeń",
                    icon: BookOpen,
                  },
                  {
                    n: learned,
                    l: "Opanowanych znaczeń",
                    sub: "Średni wynik co najmniej 80%",
                    icon: CheckCircle2,
                  },
                  {
                    n: accuracy + "%",
                    l: "Skuteczność",
                    sub: "Bez użycia podpowiedzi",
                    icon: Target,
                  },
                  {
                    n: streak,
                    l: "Dni w obecnej serii",
                    sub: "Każdy powrót ma znaczenie",
                    icon: Flame,
                  },
                ].map((m) => (
                  <section className="card metric" key={m.l}>
                    <m.icon size={21} />
                    <strong>{m.n}</strong>
                    <b>{m.l}</b>
                    <p>{m.sub}</p>
                  </section>
                ))}
              </div>
              <div className="stats-two">
                {weeklyCard}
                <section className="card skill-card">
                  <h2>Twoje umiejętności</h2>
                  <p className="small muted">Wyniki ćwiczonych znaczeń</p>
                  {Object.entries(skillNames).map(([k, label]) => {
                    const scores = meanings
                      .map((m) => m.scores[k as Skill])
                      .filter(Boolean);
                    const val = scores.length
                      ? Math.round(
                          scores.reduce((s, x) => s + x!.value, 0) /
                            scores.length,
                        )
                      : 0;
                    return (
                      <div className="skill-row" key={k}>
                        <span>{label}</span>
                        <Progress value={val} aria-label={label} />
                        <b>{scores.length ? val + "%" : "—"}</b>
                      </div>
                    );
                  })}
                  <span className="tiny muted">
                    „—” oznacza umiejętność jeszcze niećwiczoną. Ocena wymowy
                    jest planowana.
                  </span>
                </section>
              </div>
              <div className="stats-two">
                <section className="card padded">
                  <div className="section-heading">
                    <h2>Warto do nich wrócić</h2>
                    <button
                      className="text-link"
                      onClick={() => start("mistakes")}
                    >
                      Ćwicz <ArrowRight size={16} />
                    </button>
                  </div>
                  {words
                    .filter(
                      (w) =>
                        status(w) === "Trudne" ||
                        w.meanings.some((m) =>
                          Object.values(m.scores).some(
                            (s) => s.wrong || s.slow,
                          ),
                        ),
                    )
                    .sort((a, b) => wordMastery(a) - wordMastery(b))
                    .slice(0, 5)
                    .map((w) => (
                      <button
                        className="hard-word"
                        key={w.id}
                        onClick={() => setDetail(w.id)}
                      >
                        <div>
                          <b>{w.en}</b>
                          <span>{w.meanings[0].translation}</span>
                        </div>
                        <span className="badge orange">{wordMastery(w)}%</span>
                        <ChevronRight size={16} />
                      </button>
                    ))}
                  {!words.some((w) => status(w) === "Trudne") && (
                    <p className="muted">
                      Tutaj pojawią się słowa, które potrzebują dodatkowej
                      powtórki.
                    </p>
                  )}
                </section>
                <section className="card padded">
                  <h2>Kolejne małe kroki</h2>
                  <p className="small muted">
                    Prognoza powtórek · liczba znaczeń
                  </p>
                  <div className="forecast">
                    {Array.from({ length: 7 }, (_, i) => {
                      const date = Date.now() + i * 86400000;
                      const count = meanings.filter((m) =>
                        i === 0
                          ? due(m) <= Date.now()
                          : dayKey(due(m)) === dayKey(date),
                      ).length;
                      return (
                        <div key={i}>
                          <span>
                            {i === 0
                              ? "Dziś"
                              : new Date(date).toLocaleDateString("pl-PL", {
                                  weekday: "short",
                                })}
                          </span>
                          <div>
                            <i
                              style={{
                                width:
                                  Math.max(
                                    2,
                                    (count / Math.max(dueCount, 1)) * 100,
                                  ) + "%",
                              }}
                            />
                          </div>
                          <b>{count}</b>
                        </div>
                      );
                    })}
                  </div>
                  <p className="tiny muted">
                    Terminy zmieniają się po odpowiedziach. Kontrolna powtórka
                    wróci najpóźniej po 90 dniach.
                  </p>
                </section>
              </div>
              {(state.readingHistory?.length || 0) > 0 && (
                <section className="card padded reading-stats">
                  <h2>Rozumienie tekstu</h2>
                  <p>
                    {state.readingHistory!.length} czytanek ·{" "}
                    {state.readingHistory!.reduce((a, r) => a + r.correct, 0)} /{" "}
                    {state.readingHistory!.reduce((a, r) => a + r.total, 0)}{" "}
                    poprawnych odpowiedzi
                  </p>
                  <p className="small muted">
                    Wynik czytania jest niezależny od przypominania słów.
                  </p>
                </section>
              )}
              {(state.practiceHistory?.length || 0) > 0 && (
                <section className="card padded reading-stats">
                  <h2>Gramatyka i idiomy</h2>
                  <p>
                    {state.practiceHistory!.length} zestawów ·{" "}
                    {state.practiceHistory!.reduce(
                      (sum, item) => sum + item.correct,
                      0,
                    )}{" "}
                    /{" "}
                    {state.practiceHistory!.reduce(
                      (sum, item) => sum + item.total,
                      0,
                    )}{" "}
                    poprawnych odpowiedzi
                  </p>
                  <p className="small muted">
                    Wyniki obejmują osobne zestawy i sesje mieszane.
                  </p>
                </section>
              )}
              <section className="card padded activity-calendar">
                <div className="section-heading">
                  <h2>Kalendarz aktywności</h2>
                  <span className="small muted">Ostatnie 12 tygodni</span>
                </div>
                <div
                  className="calendar-grid"
                  role="img"
                  aria-label="Kalendarz ostatnich 84 dni. Intensywność koloru oznacza liczbę odpowiedzi."
                >
                  {Array.from({ length: 84 }, (_, i) => {
                    const d = Date.now() - (83 - i) * 86400000;
                    const n = realReviews.filter(
                      (r) => dayKey(r.at) === dayKey(d),
                    ).length;
                    return (
                      <div
                        key={i}
                        title={
                          new Date(d).toLocaleDateString("pl-PL") +
                          ": " +
                          n +
                          " ćwiczeń"
                        }
                        style={{
                          background: n
                            ? `rgba(112,75,221,${Math.min(1, 0.25 + n / 25)})`
                            : undefined,
                        }}
                      />
                    );
                  })}
                </div>
                <div className="calendar-legend">
                  <span>Mniej</span>
                  <i />
                  <i />
                  <i />
                  <i />
                  <span>Więcej</span>
                </div>
              </section>
              <div className="stats-two">
                <section className="card padded">
                  <h2>Postęp według poziomu</h2>
                  {["A1", "A2", "B1", "B2", "C1", "C2"].map((l) => {
                    const ws = words.filter((w) => w.level === l);
                    const value = ws.length
                      ? Math.round(
                          ws.reduce((s, w) => s + wordMastery(w), 0) /
                            ws.length,
                        )
                      : 0;
                    return (
                      <div className="skill-row" key={l}>
                        <span>
                          {l}{" "}
                          <small className="muted">· {ws.length} słów</small>
                        </span>
                        <Progress value={value} />
                        <b>{value}%</b>
                      </div>
                    );
                  })}
                </section>
                <section className="card padded">
                  <h2>Tygodniowy przyrost</h2>
                  <div className="weekly-growth">
                    <strong>
                      +
                      {
                        new Set(
                          realReviews
                            .filter(
                              (r) =>
                                r.at > Date.now() - 7 * 86400000 &&
                                r.masteryVersion === 2 &&
                                r.before < MASTERED_THRESHOLD &&
                                r.after >= MASTERED_THRESHOLD,
                            )
                            .map((r) => r.meaningId),
                        ).size
                      }
                    </strong>
                    <span>znaczeń przekroczyło próg opanowania</span>
                  </div>
                  <p className="muted small">
                    Liczymy unikalne znaczenia, których wynik wzrósł z poniżej
                    {MASTERED_THRESHOLD}% do co najmniej {MASTERED_THRESHOLD}% w ostatnich 7 dniach.
                    {" "}Przyrost liczymy od wdrożenia oceny pięciu umiejętności; wcześniejsza historia pozostaje zapisana.
                  </p>
                  <button
                    className="text-link"
                    onClick={() => go("collections")}
                  >
                    Sprawdź postęp w kolekcjach <ArrowRight size={16} />
                  </button>
                </section>
              </div>
            </StatsView>
          )}
          {view === "settings" && (
            <SettingsView>
              <div className="page-heading">
                <div>
                  <div className="eyebrow">PO TWOJEMU</div>
                  <h1>Ustawienia</h1>
                  <p>Dopasuj małe rzeczy. Łatwiej będzie wracać.</p>
                </div>
              </div>
              <GeminiSettings
                connection={connection}
                onChange={setConnection}
              />
              <div className="settings-grid">
                <section className="card padded">
                  <h2>Twój rytm nauki</h2>
                  <div className="ai-status small">
                    <Sparkles size={17} />
                    {aiAvailable
                      ? "Gemini połączone · słownictwo, ocena i lektor"
                      : "Połącz Gemini powyżej. Bez połączenia działa baza startowa i głosy urządzenia."}
                  </div>
                  <div className="setting-row">
                    <div>
                      <b>Cel dzienny</b>
                      <p>Liczba krótkich ćwiczeń</p>
                    </div>
                    <Choice
                      value={String(state.settings.goal)}
                      onChange={(v) =>
                        persist({
                          ...state,
                          settings: { ...state.settings, goal: Number(v) },
                        })
                      }
                      items={["5", "10", "15", "20", "30", "50"]}
                      label="Dzienny cel"
                    />
                  </div>
                  <div className="setting-row">
                    <div>
                      <b>Preferowana pora nauki</b>
                      <p>
                        Zapisana na koncie. Powiadomienia push w kolejnym
                        etapie.
                      </p>
                    </div>
                    <input
                      type="time"
                      value={state.settings.reminder}
                      aria-label="Preferowana pora nauki"
                      onChange={(e) => {
                        if (e.target.value)
                          persist({
                            ...state,
                            settings: {
                              ...state.settings,
                              reminder: e.target.value,
                            },
                          });
                      }}
                    />
                  </div>
                  <div className="setting-row">
                    <div>
                      <b>Ciemny motyw</b>
                      <p>Wygląd na tym urządzeniu</p>
                    </div>
                    <Switch
                      aria-label="Ciemny motyw"
                      checked={dark}
                      onCheckedChange={(v) => {
                        setDark(v);
                        document.documentElement.classList.toggle("dark", v);
                        localStorage.setItem(
                          "fluent-theme",
                          v ? "dark" : "light",
                        );
                      }}
                    />
                  </div>
                  <div className="setting-row">
                    <div>
                      <b>Wymowa</b>
                      <p>
                        Domyślnie amerykańska wymowa. Lektor AI używa naturalnej
                        intonacji.
                      </p>
                    </div>
                    {speechAvailable ? (
                      <span className="badge lavender">AI · amerykańska</span>
                    ) : (
                      <Choice
                        value={
                          state.settings.accent === "en-GB"
                            ? "Brytyjska"
                            : "Amerykańska"
                        }
                        items={["Brytyjska", "Amerykańska"]}
                        label="Akcent głosu urządzenia"
                        onChange={(v) =>
                          persist({
                            ...state,
                            settings: {
                              ...state.settings,
                              accent: v === "Brytyjska" ? "en-GB" : "en-US",
                            },
                          })
                        }
                      />
                    )}
                  </div>
                  <div className="setting-row">
                    <div>
                      <b>Wolniejsze odtwarzanie</b>
                      <p>Więcej czasu, żeby usłyszeć szczegóły</p>
                    </div>
                    <Switch
                      aria-label="Wolne odtwarzanie"
                      checked={state.settings.slow}
                      onCheckedChange={(v) =>
                        persist({
                          ...state,
                          settings: { ...state.settings, slow: v },
                        })
                      }
                    />
                  </div>
                  {!speechAvailable && voices.length > 0 && (
                    <div className="setting-row voice-choice">
                      <div>
                        <b>Głos urządzenia</b>
                        <p>Wybierz głos, który brzmi dla Ciebie najlepiej.</p>
                      </div>
                      <Select
                        value={state.settings.voice || "auto"}
                        onValueChange={(v) =>
                          persist({
                            ...state,
                            settings: {
                              ...state.settings,
                              voice: v === "auto" ? "" : v,
                            },
                          })
                        }
                      >
                        <SelectTrigger aria-label="Głos lektora">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="auto">
                            Automatycznie · preferuj US
                          </SelectItem>
                          {voices.map((v) => (
                            <SelectItem key={v.voiceURI} value={v.voiceURI}>
                              {v.name} ({v.lang})
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  )}
                  <p className="tiny muted">{voiceLabel}</p>
                  {missingLevels > 0 && (
                    <div className="setting-row">
                      <div>
                        <b>{missingLevels} znaczeń bez poziomu CEFR</b>
                        <p>
                          Nie wpływają na oszacowanie poziomu, dopóki ich nie
                          uzupełnisz.
                        </p>
                      </div>
                      {aiAvailable && (
                        <button
                          className="btn secondary"
                          disabled={levelBusy}
                          onClick={fillMissingLevels}
                        >
                          {levelBusy ? (
                            <LoaderCircle className="spin" size={16} />
                          ) : (
                            <Sparkles size={16} />
                          )}{" "}
                          Uzupełnij poziomy
                        </button>
                      )}
                    </div>
                  )}
                  {!speechAvailable && voices.length > 0 && !isNaturalVoice && (
                    <p className="hint-box small">
                      Ten głos może brzmieć mechanicznie. Dodaj naturalny
                      angielski głos w ustawieniach mowy systemu, a potem
                      wybierz go powyżej.
                    </p>
                  )}
                  <button
                    className="btn secondary"
                    onClick={() =>
                      speak("A little practice every day goes a long way.")
                    }
                  >
                    <Volume2 size={17} /> Wypróbuj głos
                  </button>
                </section>
                <div>
                  <section className="card padded account-card">
                    <div className="row">
                      <div className="avatar">
                        {user ? user.name.slice(0, 1) : "O"}
                      </div>
                      <div>
                        <h2>{user ? "Twoje konto" : "Tryb gościa"}</h2>
                        <p>
                          {user
                            ? user.email
                            : "Gemini działa od razu, bez zakładania konta."}
                        </p>
                      </div>
                    </div>
                    <div className="sync-state">
                      <CloudCheck size={17} />
                      {sync}
                    </div>
                    <p className="small muted">
                      {user
                        ? "Słowa i ukończone zadania są przypisane do Twojego konta. Odśwież aplikację na drugim urządzeniu, aby pobrać ostatnie zmiany."
                        : "Słowa i postęp zapisują się na tym urządzeniu. Logowanie jest opcjonalne i służy tylko do synchronizacji między urządzeniami."}
                    </p>
                    {user ? (
                      <a
                        className="text-link"
                        href="/signout-with-chatgpt?return_to=%2F"
                        target="_top"
                      >
                        <LogOut size={16} /> Wyloguj się
                      </a>
                    ) : (
                      <a
                        className="btn secondary"
                        href="/signin-with-chatgpt?return_to=%2F"
                        target="_top"
                      >
                        Włącz synchronizację <ArrowRight size={16} />
                      </a>
                    )}
                  </section>
                  <section className="card padded pwa-card">
                    <h2>Fluent pod ręką</h2>
                    <p className="muted small">
                      Dodaj aplikację do ekranu głównego. Powłoka i bieżący
                      postęp działają offline, a zmiany synchronizują się po
                      powrocie sieci. Gemini i lektor AI wymagają internetu, ale
                      nie wymagają logowania.
                    </p>
                    {install ? (
                      <button
                        className="btn secondary"
                        onClick={async () => {
                          await install.prompt();
                          setInstall(null);
                        }}
                      >
                        <Download size={17} /> Zainstaluj aplikację
                      </button>
                    ) : (
                      <p className="small">
                        W menu przeglądarki wybierz „Zainstaluj aplikację” lub
                        „Dodaj do ekranu głównego”, jeśli ta opcja jest
                        dostępna.
                      </p>
                    )}
                  </section>
                </div>
              </div>
              <section className="card padded data-settings">
                <h2>Twoje dane należą do Ciebie</h2>
                <p className="muted small">
                  Nie zapisujemy nagrań mikrofonu ani haseł. Po połączeniu AI
                  wysyłamy do Google Gemini treść aktualnego zadania, odpowiedź
                  lub wybrane słownictwo. Odsłuchiwane słowa mogą być wysyłane
                  do Free Dictionary API. Po skonfigurowaniu Azure Speech tekst
                  do odczytania trafia do Microsoft; zapasowy lektor korzysta
                  z Gemini. Głosy Azure i Gemini są syntetyczne.
                </p>
                <div className="row wrap">
                  <button
                    className="btn secondary"
                    onClick={() =>
                      download(
                        "fluent-kopia.json",
                        JSON.stringify({ version: 1, state }, null, 2),
                      )
                    }
                  >
                    <Download size={17} /> Pełna kopia JSON
                  </button>
                  <button className="btn secondary" onClick={()=>download("fluent-bank-zdan.json",JSON.stringify({version:1,pools:state.words.flatMap(w=>w.meanings.filter(m=>m.examples.length).map(m=>({term:w.en,translation:m.translation,topic:m.topic,scene:m.scene,enrichment:m.enrichment,usedExamples:m.usedExamples || [],examples:m.examples.map((en,i)=>({en,pl:m.exampleTranslations?.[i],focusEn:m.exampleFocusEn?.[i],focusPl:m.exampleFocusPl?.[i]}))})))},null,2))}>
                    <Download size={17}/> Bank zdań JSON
                  </button>
                  <button className="btn secondary" onClick={exportCsv}>
                    <Download size={17} /> Słowa CSV / Anki
                  </button>
                  <button
                    className="btn secondary"
                    onClick={() => setImportOpen(true)}
                  >
                    <Upload size={17} /> Importuj dane
                  </button>
                  <button
                    className="btn secondary"
                    onClick={() => setConfirm("reset")}
                  >
                    <RotateCcw size={17} /> Zacznij od pustego słownika
                  </button>
                  {user && (
                    <button
                      className="btn danger"
                      onClick={() => setConfirm("delete")}
                    >
                      <Trash2 size={17} /> Usuń dane Fluent
                    </button>
                  )}
                </div>
                <p className="tiny muted">
                  CSV: jedno znaczenie w wierszu. W Anki przypisz English →
                  przód, Polish → tył. Pełną historię zachowuje kopia JSON.
                </p>
              </section>
              <ExerciseReports/>
              <section className="roadmap card padded">
                <div className="section-heading">
                  <h2>Co dalej?</h2>
                  <a className="text-link" href="/plan-produktu.md" download>
                    Plan produktu <Download size={16} />
                  </a>
                </div>
                <div className="roadmap-grid">
                  <div>
                    <span className="badge green">Dostępne</span>
                    <h3>Twój codzienny rytm</h3>
                    <p>
                      Szybki wybór znaczeń i tematów, pełne tłumaczenia zdań,
                      czytanki, gramatyka, idiomy i sesje mieszane z Gemini.
                    </p>
                  </div>
                  <div>
                    <span className="badge lavender">Następny etap</span>
                    <h3>Jeszcze lepsza synchronizacja</h3>
                    <p>
                      Powiadomienia, bogatsze raporty tygodniowe i historia
                      zmian.
                    </p>
                  </div>
                  <div>
                    <span className="badge gray">W planach</span>
                    <h3>Więcej prawdziwych rozmów</h3>
                    <p>
                      Mikrofon, orientacyjna ocena wymowy, dialogi sytuacyjne
                      oraz wydobywanie słów z dłuższego tekstu.
                    </p>
                  </div>
                </div>
              </section>
            </SettingsView>
          )}
        </ReportScope.Provider></main>
        <footer className={"app-footer " + (focus ? "focus-hidden" : "")}>
          <span>
            <span className="mini-brand">fluent.</span> Angielski w Twoim
            rytmie.
          </span>
          <span className="row tiny muted">
            {sync === "Zsynchronizowano" ? (
              <CloudCheck size={14} />
            ) : (
              <CloudOff size={14} />
            )}{" "}
            {sync}
          </span>
        </footer>
      </div>
      <nav
        className={"mobile-nav " + (focus ? "focus-hidden" : "")}
        aria-label="Nawigacja mobilna"
      >
        {nav.map((n) => (
          <button
            className={view === n.id ? "active" : ""}
            aria-current={view === n.id ? "page" : undefined}
            key={n.id}
            onClick={() => go(n.id)}
          >
            <n.icon size={21} />
            <span>{n.id === "words" ? "Słownik" : n.label}</span>
          </button>
        ))}
      </nav>
      <QuickAdd
        open={quickAdd}
        onOpenChange={setQuickAdd}
        initial={quickTerm}
        state={state}
        onSave={persist}
        ai={aiAvailable}
        speak={speak}
        onManual={(term) =>
          setEditing({ ...blankWord(state.collections[0]), en: term })
        }
      />
      <Dialog
        open={!!editing}
        onOpenChange={(v) => {
          if (!v) setEditing(null);
        }}
      >
        <DialogContent className="word-dialog">
          <DialogTitle>
            {state.words.some((w) => w.id === editing?.id)
              ? "Edytuj słowo"
              : "Nowe słowo. Nowe możliwości."}
          </DialogTitle>
          <DialogDescription>
            Dodaj zwrot i jego konkretne znaczenia. Każde będziemy ćwiczyć
            osobno.
          </DialogDescription>
          {editing && (
            <form onSubmit={saveWord} className="word-form">
              <div className="form-grid">
                <label>
                  Po angielsku <span>*</span>
                  <input
                    required
                    value={editing.en}
                    onChange={(e) =>
                      setEditing({ ...editing, en: e.target.value })
                    }
                    placeholder="np. get the hang of"
                    maxLength={300}
                  />
                </label>
                <label>
                  Wymowa IPA
                  <input
                    value={editing.ipa}
                    onChange={(e) =>
                      setEditing({ ...editing, ipa: e.target.value })
                    }
                    placeholder="np. /bæŋk/"
                  />
                </label>
                <label>
                  Część mowy
                  <Choice
                    value={editing.pos}
                    onChange={(v) => setEditing({ ...editing, pos: v })}
                    items={[
                      "rzeczownik",
                      "czasownik",
                      "przymiotnik",
                      "przysłówek",
                      "zwrot",
                      "czasownik frazowy",
                      "zdanie",
                      "inne",
                    ]}
                    label="Część mowy"
                  />
                </label>
                <label>
                  Poziom
                  <Choice
                    value={editing.level}
                    onChange={(v) => setEditing({ ...editing, level: v })}
                    items={["A1", "A2", "B1", "B2", "C1", "C2"]}
                    label="Poziom CEFR"
                  />
                </label>
              </div>
              {editing.en.trim().toLowerCase() === "bank" &&
                editing.meanings.length === 1 &&
                !editing.meanings[0].translation && (
                  <div className="hint-box">
                    <Lightbulb size={20} />
                    <div>
                      <b>Które znaczenie masz na myśli?</b>
                      <p>„bank” to instytucja finansowa albo brzeg rzeki.</p>
                      <div className="row wrap">
                        <button
                          type="button"
                          className="text-link"
                          onClick={() =>
                            setEditing({
                              ...editing,
                              meanings: structuredClone(
                                seed().words[6].meanings,
                              ).map((m) => ({
                                ...m,
                                id: crypto.randomUUID(),
                                scores: {},
                              })),
                            })
                          }
                        >
                          Dodaj oba znaczenia z przykładami
                        </button>
                      </div>
                    </div>
                  </div>
                )}
              {editing.meanings.map((m, i) => (
                <fieldset className="meaning-fieldset" key={m.id}>
                  <legend>ZNACZENIE {i + 1}</legend>
                  <label>
                    Polskie tłumaczenie <span>*</span>
                    <input
                      required
                      value={m.translation}
                      onChange={(e) =>
                        updateMeaning(m.id, "translation", e.target.value)
                      }
                      placeholder="Jedno konkretne znaczenie"
                    />
                  </label>
                  <label>
                    Przykłady po angielsku <span>*</span>
                    <textarea
                      required
                      rows={2}
                      value={m.examples.join("\n")}
                      onChange={(e) =>
                        setEditing((w) =>
                          w
                            ? {
                                ...w,
                                meanings: w.meanings.map((x) =>
                                  x.id === m.id
                                    ? {
                                        ...x,
                                        examples: e.target.value.split("\n"),
                                        exampleTranslations: [],
                                        exampleFocusEn: [],
                                        exampleFocusPl: [],
                                      }
                                    : x,
                                ),
                              }
                            : w,
                        )
                      }
                      placeholder="Każde zdanie w osobnym wierszu. Możesz używać naturalnych form odmienionych."
                    />
                  </label>
                  <label>
                    Tłumaczenia całych zdań (po jednym w wierszu)
                    <textarea
                      rows={2}
                      value={(m.exampleTranslations || []).join("\n")}
                      onChange={(e) =>
                        updateMeaning(
                          m.id,
                          "exampleTranslations",
                          e.target.value.split("\n"),
                        )
                      }
                      placeholder="Polskie odpowiedniki przykładów powyżej"
                    />
                  </label>
                  <label>
                    Polskie wyrażenia do pogrubienia (po jednym w wierszu)
                    <textarea
                      rows={2}
                      value={(m.exampleFocusPl || []).join("\n")}
                      onChange={(e) =>
                        updateMeaning(
                          m.id,
                          "exampleFocusPl",
                          e.target.value.split("\n"),
                        )
                      }
                    />
                  </label>
                  <label>
                    Akceptowane warianty po angielsku
                    <input
                      value={(m.acceptedAnswers || []).join("; ")}
                      onChange={(e) =>
                        updateMeaning(
                          m.id,
                          "acceptedAnswers",
                          e.target.value.split(";").map((x) => x.trim()),
                        )
                      }
                      placeholder="lend someone; lend something to someone"
                    />
                  </label>
                  <label>
                    Akceptowane warianty po polsku
                    <input value={(m.acceptedTranslations || []).join("; ")}
                      onChange={e=>updateMeaning(m.id,"acceptedTranslations",e.target.value.split(";").map(s=>s.trim()).filter(Boolean))}
                      placeholder="np. pożyczyć; pożyczać; wypożyczyć" />
                  </label>
                  <div className="form-grid">
                    <label>
                      Kontekst
                      <input
                        value={m.context}
                        onChange={(e) =>
                          updateMeaning(m.id, "context", e.target.value)
                        }
                        placeholder="np. prośba o pomoc"
                      />
                    </label>
                    <label>
                      Rejestr
                      <Choice
                        value={m.register}
                        onChange={(v) => updateMeaning(m.id, "register", v)}
                        items={[
                          "formalny",
                          "neutralny",
                          "potoczny",
                          "slangowy",
                          "zawodowy",
                          "przestarzały",
                        ]}
                        label="Rejestr językowy"
                      />
                    </label>
                  </div>
                  <label>
                    Definicja / wyjaśnienie
                    <input
                      value={m.definition}
                      onChange={(e) =>
                        updateMeaning(m.id, "definition", e.target.value)
                      }
                      placeholder="Co dokładnie oznacza ten zwrot?"
                    />
                  </label>
                  <label>
                    Naturalny odpowiednik w rozmowie
                    <input
                      value={m.natural}
                      onChange={(e) =>
                        updateMeaning(m.id, "natural", e.target.value)
                      }
                      placeholder="Opcjonalnie — z zachowaniem sensu i sytuacji"
                    />
                  </label>
                </fieldset>
              ))}
              <button
                className="text-link"
                type="button"
                onClick={() =>
                  setEditing({
                    ...editing,
                    meanings: [...editing.meanings, blankMeaning()],
                  })
                }
              >
                <Plus size={16} /> Dodaj inne znaczenie
              </button>
              <div className="form-grid">
                <label>
                  Kolekcja
                  <Choice
                    value={editing.collection}
                    onChange={(v) => setEditing({ ...editing, collection: v })}
                    items={
                      state.collections.length
                        ? state.collections
                        : ["Moje słowa"]
                    }
                    label="Kolekcja słowa"
                  />
                </label>
                <label>
                  Tagi
                  <input
                    value={editing.tags.join(", ")}
                    onChange={(e) =>
                      setEditing({
                        ...editing,
                        tags: e.target.value.split(",").map((t) => t.trim()),
                      })
                    }
                    placeholder="podróże, przydatne"
                  />
                </label>
              </div>
              <details className="extra-fields">
                <summary>
                  Więcej szczegółów: formy, kolokacje, źródło i notatka
                </summary>
                <div className="form-grid">
                  {[
                    { k: "forms", l: "Odmiana / formy" },
                    { k: "collocations", l: "Kolokacje" },
                    { k: "synonyms", l: "Synonimy" },
                    { k: "antonyms", l: "Antonimy" },
                    { k: "source", l: "Źródło" },
                    { k: "note", l: "Twoja notatka" },
                  ].map((f) => (
                    <label key={f.k}>
                      {f.l}
                      <input
                        value={String(editing[f.k as keyof Word] || "")}
                        onChange={(e) =>
                          setEditing({ ...editing, [f.k]: e.target.value })
                        }
                      />
                    </label>
                  ))}
                </div>
              </details>
              <div className="modal-footer">
                <button
                  type="button"
                  className="btn secondary"
                  onClick={() => setEditing(null)}
                >
                  Anuluj
                </button>
                <button className="btn primary" type="submit">
                  <Check size={17} /> Zapisz słowo
                </button>
              </div>
            </form>
          )}
        </DialogContent>
      </Dialog>
      <Sheet
        open={!!selected}
        onOpenChange={(v) => {
          if (!v) setDetail(null);
        }}
      >
        <SheetContent className="word-sheet">
          <SheetHeader>
            <SheetTitle>
              <span className="detail-title">{selected?.en}</span>
            </SheetTitle>
            <SheetDescription>
              {selected?.pos} · {selected?.level} · {selected?.ipa}
            </SheetDescription>
          </SheetHeader>
          {selected && (
            <div className="detail-content">
              <div className="row wrap">
                <button
                  className="btn secondary"
                  onClick={() => speak(selected.en, undefined, "word")}
                >
                  <Volume2 size={17} /> Posłuchaj{" "}
                  <span className="ipa tiny">{selected.ipa}</span>
                </button>
                <button
                  className="btn secondary"
                  onClick={() => {
                    setEditing(structuredClone(selected));
                    setDetail(null);
                  }}
                >
                  <PenLine size={17} /> Edytuj
                </button>
                <button
                  className={"icon-btn " + (selected.important ? "gold" : "")}
                  aria-label="Oznacz jako ważne"
                  onClick={() =>
                    persist({
                      ...state,
                      words: state.words.map((w) =>
                        w.id === selected.id
                          ? {
                              ...w,
                              important: !w.important,
                              updatedAt: Date.now(),
                            }
                          : w,
                      ),
                    })
                  }
                >
                  <Star
                    size={20}
                    fill={selected.important ? "currentColor" : "none"}
                  />
                </button>
              </div>
              <div className="row between detail-overview">
                <span>{selected.collection}</span>
                <span
                  className={"badge " + (selected.hard ? "orange" : "lavender")}
                >
                  {status(selected)}
                </span>
              </div>
              {selected.meanings.map((m, i) => (
                <section className="detail-meaning" key={m.id}>
                  <div className="row between">
                    <span className="eyebrow">
                      ZNACZENIE {i + 1} · {m.level || selected.level}
                    </span>
                    <span className="badge gray">{m.register}</span>
                  </div>
                  <h2>{m.translation}</h2>
                  <p className="muted">{m.definition}</p>
                  {m.spokenFrequency && (
                    <p className="small muted">
                      <b>Popularność w codziennej mowie:</b>{" "}
                      {m.spokenFrequency === "very_common"
                        ? "bardzo popularne"
                        : m.spokenFrequency === "common"
                          ? "popularne"
                          : m.spokenFrequency === "less_common"
                            ? "mniej popularne"
                            : "rzadkie"}
                    </p>
                  )}
                  {m.examples.map((ex, j) => (
                    <div className="example-row" key={j}>
                      <div>
                        <span lang="en">
                          “
                          <Highlight
                            text={ex}
                            focus={
                              examplePair(selected, m, j)?.focusEn ||
                              selected.en
                            }
                          />
                          ”
                        </span>
                        <SentenceTranslation
                          pair={examplePair(selected, m, j)}
                        />
                      </div>
                      {speechButton(ex, selected.ipa, "sentence")}
                    </div>
                  ))}
                  <div className="meaning-scene-box">
                    <div className="row between wrap">
                      <b>Scena przykładów</b>
                      {m.topic && (
                        <span className="badge lavender">{m.topic}</span>
                      )}
                    </div>
                    <p className="tiny muted">
                      Wpisz sytuację, aby ponownie osadzić oba przykłady bez
                      zmiany znaczenia.
                    </p>
                    <div className="meaning-scene-controls">
                      <input
                        aria-label={`Scena przykładów dla ${selected.en}`}
                        value={sceneDrafts[m.id] ?? m.scene ?? ""}
                        onChange={(event) =>
                          setSceneDrafts((current) => ({
                            ...current,
                            [m.id]: event.target.value,
                          }))
                        }
                        placeholder="np. pasażer przy kontroli bezpieczeństwa na lotnisku"
                      />
                      <button
                        className="btn secondary"
                        disabled={
                          !aiAvailable ||
                          sceneBusy === m.id ||
                          !(sceneDrafts[m.id] ?? m.scene ?? "").trim()
                        }
                        title={
                          aiAvailable
                            ? "Wygeneruj dwa nowe przykłady w tej scenie"
                            : "Ta funkcja wymaga połączenia z Gemini"
                        }
                        onClick={() => void refreshMeaningExamples(selected, m)}
                      >
                        {sceneBusy === m.id ? (
                          <LoaderCircle className="spin" size={16} />
                        ) : (
                          <Sparkles size={16} />
                        )}
                        Osadź ponownie
                      </button>
                    </div>
                  </div>
                  {m.context && (
                    <p className="small">
                      <b>Kontekst:</b> {m.context}
                    </p>
                  )}
                  {m.natural && (
                    <div className="hint-box">
                      <MessagesSquare size={19} />
                      <span>
                        Naturalnie w rozmowie: <b>{m.natural}</b>
                      </span>
                    </div>
                  )}
                  <div className="meaning-stats">
                    <div>
                      <span>Opanowanie</span>
                      <b>{mastery(m)}%</b>
                    </div>
                    <div>
                      <span>Kolejna powtórka</span>
                      <b>{dateLabel(due(m))}</b>
                    </div>
                    <div>
                      <span>Ostatnia powtórka</span>
                      <b>
                        {Math.max(
                          0,
                          ...Object.values(m.scores).map((s) => s.last),
                        )
                          ? new Date(
                              Math.max(
                                ...Object.values(m.scores).map((s) => s.last),
                              ),
                            ).toLocaleDateString("pl-PL")
                          : "Jeszcze przed Tobą"}
                      </b>
                    </div>
                    <div>
                      <span>Poprawne / błędy*</span>
                      <b>
                        {Object.values(m.scores).reduce(
                          (a, s) => a + s.correct,
                          0,
                        )}{" "}
                        /{" "}
                        {Object.values(m.scores).reduce(
                          (a, s) => a + s.wrong,
                          0,
                        )}
                      </b>
                    </div>
                  </div>
                  {Object.entries(skillNames).map(([k, label]) => (
                    <div className="skill-row" key={k}>
                      <span>{label}</span>
                      <Progress value={m.scores[k as Skill]?.value || 0} />
                      <b>
                        {m.scores[k as Skill]
                          ? m.scores[k as Skill]!.value + "%"
                          : "—"}
                      </b>
                    </div>
                  ))}
                  <span className="tiny muted">
                    * Wyniki umiejętności — zadanie może ćwiczyć więcej niż
                    jedną.
                  </span>
                  {(() => {
                    const errors = realReviews.filter(
                      (r) => r.meaningId === m.id && r.error,
                    );
                    const counts = errors.reduce(
                      (a, r) => ({ ...a, [r.error]: (a[r.error] || 0) + 1 }),
                      {} as Record<string, number>,
                    );
                    const top = Object.entries(counts).sort(
                      (a, b) => b[1] - a[1],
                    )[0];
                    return top ? (
                      <p className="small muted">
                        Najczęściej: {top[0]} ({top[1]})
                      </p>
                    ) : null;
                  })()}
                </section>
              ))}
              {(selected.note ||
                selected.forms ||
                selected.collocations ||
                selected.synonyms ||
                selected.antonyms ||
                selected.source) && (
                <section className="detail-meaning">
                  <h3>Warto zapamiętać</h3>
                  {[
                    { l: "Formy", v: selected.forms },
                    { l: "Kolokacje", v: selected.collocations },
                    { l: "Synonimy", v: selected.synonyms },
                    { l: "Antonimy", v: selected.antonyms },
                    { l: "Notatka", v: selected.note },
                    { l: "Źródło", v: selected.source },
                  ]
                    .filter((f) => f.v)
                    .map((f) => (
                      <p key={f.l} className="small">
                        <b>{f.l}:</b> {f.v}
                      </p>
                    ))}
                </section>
              )}
              <div className="row wrap">
                {selected.tags.filter(Boolean).map((t) => (
                  <span className="badge gray" key={t}>
                    #{t}
                  </span>
                ))}
              </div>
              <div className="setting-row">
                <span>Szczególnie trudne</span>
                <Switch
                  checked={selected.hard}
                  aria-label="Oznacz jako trudne"
                  onCheckedChange={(v) =>
                    persist({
                      ...state,
                      words: state.words.map((w) =>
                        w.id === selected.id
                          ? { ...w, hard: v, updatedAt: Date.now() }
                          : w,
                      ),
                    })
                  }
                />
              </div>
              <button
                className="text-link muted"
                onClick={() => {
                  persist({
                    ...state,
                    words: state.words.map((w) =>
                      w.id === selected.id
                        ? { ...w, archived: !w.archived, updatedAt: Date.now() }
                        : w,
                    ),
                  });
                  setDetail(null);
                  toast.success(
                    selected.archived
                      ? "Przywrócono słowo"
                      : "Zarchiwizowano z zachowaniem historii",
                  );
                }}
              >
                <Layers size={16} />
                {selected.archived ? "Przywróć ze schowka" : "Archiwizuj słowo"}
              </button>
            </div>
          )}
        </SheetContent>
      </Sheet>
      <Dialog open={collectionOpen} onOpenChange={setCollectionOpen}>
        <DialogContent>
          <DialogTitle>Miejsce na nowe słowa</DialogTitle>
          <DialogDescription>
            Nazwij swoją kolekcję. Może być tematem, sytuacją albo inspiracją.
          </DialogDescription>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              const name = collectionName.trim();
              if (!name) return;
              if (state.collections.includes(name)) {
                toast.error("Taka kolekcja już istnieje.");
                return;
              }
              if (
                persist({ ...state, collections: [...state.collections, name] })
              ) {
                setCollectionOpen(false);
                setCollectionName("");
                toast.success("Kolekcja utworzona.");
              }
            }}
          >
            <label className="field-label">
              Nazwa kolekcji
              <input
                required
                autoFocus
                maxLength={80}
                placeholder="np. Mój następny wyjazd"
                value={collectionName}
                onChange={(e) => setCollectionName(e.target.value)}
              />
            </label>
            <div className="modal-footer">
              <button className="btn primary">
                Utwórz kolekcję <Plus size={17} />
              </button>
            </div>
          </form>
        </DialogContent>
      </Dialog>
      <Dialog open={importOpen} onOpenChange={setImportOpen}>
        <DialogContent className="import-dialog">
          <DialogTitle>Więcej słów, jednym ruchem</DialogTitle>
          <DialogDescription>
            Wklej listę, wybierz CSV / TSV lub przywróć pełną kopię JSON z
            Fluent.
          </DialogDescription>
          <div className="import-example">
            <code>borrow,pożyczyć od kogoś,Can I borrow your pen?</code>
            <p>
              Kolumny: English, Polish, Example, Collection, Tags.
              <br />
              Dwa znaczenia słowa umieść w osobnych wierszach. Bez przykładów
              dodamy sam zwrot do późniejszego uzupełnienia.
            </p>
          </div>
          <label className="upload-zone">
            <Upload size={22} />
            <b>Wybierz plik CSV, TSV lub JSON</b>
            <input
              className="sr-only"
              type="file"
              accept=".csv,.tsv,.txt,.json"
              onChange={async (e) => {
                const f = e.target.files?.[0];
                if (f) {
                  if (f.size > 4000000) {
                    setImportError("Wybierz plik mniejszy niż 4 MB.");
                    return;
                  }
                  setImportText(await f.text());
                  setImportError("");
                }
              }}
            />
          </label>
          <textarea
            rows={7}
            aria-label="Dane do importu"
            placeholder="Wklej słowa i tłumaczenia…"
            value={importText}
            onChange={(e) => {
              setImportText(e.target.value);
              setImportError("");
            }}
          />
          {importError && (
            <p className="error-text" role="alert">
              {importError}
            </p>
          )}
          <div className="modal-footer">
            <button
              className="btn secondary"
              onClick={() => setImportOpen(false)}
            >
              Anuluj
            </button>
            <button
              className="btn primary"
              disabled={!importText.trim()}
              onClick={importWords}
            >
              <Upload size={16} /> Importuj
            </button>
          </div>
        </DialogContent>
      </Dialog>
      <Dialog open={!!combinedDraft} onOpenChange={open=>{if(!open)setCombinedDraft(null);}}>
        <DialogContent className="combined-setup-dialog">
          <DialogTitle>Twoja sesja łączona</DialogTitle>
          <DialogDescription>Sprawdź zestaw i wybierz kolejność przed rozpoczęciem. Ustawienie obowiązuje przez całą sesję.</DialogDescription>
          <ul className="combined-summary">{combinedDraft?.modes.map(m=>{const count=combinedDraft.tasks.filter(t=>t.mode===m).length;return <li key={m}><span>{studyLabels[m]}</span><b>{count?`${count} zadań`:'Brak gotowych zadań — pominięte'}</b></li>;})}</ul>
          <div className="multi-select-toggle"><label htmlFor="shuffle-session"><b>Losuj kolejność ćwiczeń</b><span>Przeplataj pojedyncze zadania z wybranych rodzajów. Gdy to możliwe, kolejne zadanie będzie z innego rodzaju.</span></label><Switch id="shuffle-session" checked={shuffleSession} onCheckedChange={setShuffleSession}/></div>
          <p className="small muted">{combinedDraft?.tasks.length} zadań · około {combinedDraft?.minutes} minut. {shuffleSession?'Losowanie nastąpi raz, przy starcie.':'Bez losowania zadania są pogrupowane według rodzaju.'}</p>
          <div className="combined-setup-actions"><button className="btn secondary" onClick={()=>setCombinedDraft(null)}>Zmień wybór</button><button className="btn primary" onClick={()=>{
            if(!combinedDraft)return;
            const tasks=orderCombinedTasks(combinedDraft.tasks,shuffleSession);
            if(!persist({...state,combined:{...combinedDraft,tasks,random:shuffleSession,updatedAt:Date.now()}}))return;
            setCombinedDraft(null);setReadingMode(false);setPracticeMode(null);setActive(false);setCombinedActive(true);window.scrollTo(0,0);
          }}>Rozpocznij naukę <Play size={17}/></button></div>
        </DialogContent>
      </Dialog>
      <AlertDialog open={!!exitAction} onOpenChange={open=>{if(!open)setExitAction(null);}}>
        <AlertDialogContent><AlertDialogHeader><AlertDialogTitle>Wyjść z ćwiczeń?</AlertDialogTitle><AlertDialogDescription>Wykonane zadania zostaną zapisane. Możesz później kontynuować sesję. Niezatwierdzona odpowiedź może wymagać ponownego wpisania.</AlertDialogDescription></AlertDialogHeader><AlertDialogFooter><AlertDialogCancel>Zostań w ćwiczeniu</AlertDialogCancel><AlertDialogAction onClick={()=>{const action=exitAction;setExitAction(null);stopSpeech();action?.();}}>Zapisz i wyjdź</AlertDialogAction></AlertDialogFooter></AlertDialogContent>
      </AlertDialog>
      <AlertDialog
        open={!!confirm}
        onOpenChange={(v) => {
          if (!v) setConfirm(null);
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>
              {confirm === "delete"
                ? "Usunąć wszystkie dane Fluent?"
                : "Zacząć własną historię?"}
            </AlertDialogTitle>
            <AlertDialogDescription>
              Usuniemy słowa, znaczenia i historię nauki z tej aplikacji.
              Najpierw możesz zapisać pełną kopię JSON w Ustawieniach. Ta
              operacja nie usuwa konta ChatGPT.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Anuluj</AlertDialogCancel>
            <AlertDialogAction
              onClick={async () => {
                if (confirm === "delete") {
                  if (saveTimer.current) clearTimeout(saveTimer.current);
                  await flushSaves();
                  await saveChain.current;
                  try {
                    const r = await fetch("/api/state", { method: "DELETE" });
                    if (!r.ok) throw new Error();
                    ready.current = false;
                    setConnection(disconnected);
                    setState({
                      ...seed(),
                      words: [],
                      reviews: [],
                      collections: ["Moje słowa"],
                      session: null,
                      reading: null,
                      readingHistory: [],
                      practice: null,
                      practiceHistory: [],
                      demo: false,
                    });
                    setSync("Dane usunięte");
                    await clearQueuedState();
                    toast.success(
                      "Usunięto dane Fluent. Nowa nauka zacznie się po ponownym otwarciu aplikacji.",
                    );
                  } catch {
                    toast.error(
                      "Nie udało się usunąć danych. Spróbuj ponownie.",
                    );
                  }
                } else {
                  persist({
                    ...state,
                    words: [],
                    reviews: [],
                    collections: ["Moje słowa"],
                    session: null,
                    reading: null,
                    readingHistory: [],
                    practice: null,
                    practiceHistory: [],
                    demo: false,
                  });
                  setCollectionFilter("Wszystkie kolekcje");
                  toast.success("Gotowe na Twoje pierwsze słowo.");
                }
                setConfirm(null);
              }}
            >
              {confirm === "delete" ? "Tak, usuń dane" : "Tak, wyczyść słownik"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </SidebarProvider>
  );
}
