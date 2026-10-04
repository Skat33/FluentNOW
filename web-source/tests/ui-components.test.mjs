import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import test, { after } from "node:test";
import { fileURLToPath } from "node:url";

import React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createServer } from "vite";

const root = fileURLToPath(new URL("..", import.meta.url));
const vite = await createServer({
  appType: "custom",
  configFile: false,
  root,
  resolve: { alias: { "@": root } },
  server: { middlewareMode: true },
});

after(async () => {
  await vite.close();
});

test("D: vocabulary timer is neutral, freezes on submission and exposes only static answer time", async () => {
  const source = await readFile(path.join(root, "app/fluent.tsx"), "utf8");
  assert.match(source, /if \(!timerStopped.current\)[\s\S]*?setDisplaySeconds/);
  assert.match(source, /return \(\) => window.clearInterval\(interval\)/);
  assert.match(source, /setDisplaySeconds\(0\);\s*timerStopped.current = false/);
  assert.match(source, /timerStopped.current = true;\s*setDisplaySeconds\(Math.floor\(seconds\)\)/);
  assert.match(source, /<span aria-hidden="true"[^>]*>[\s\S]*?displaySeconds[\s\S]*?<\/span>/);
  assert.match(source, /className="sr-only">Czas odpowiedzi: \{displaySeconds\} sekund/);
});

test("quick add replaces the long list with focused progress during hydration", async () => {
  const source = await readFile(path.join(root, "app/tutor-ui.tsx"), "utf8");
  assert.match(source, /className="quick-add-content" hidden=\{isHydrating\}/);
  assert.match(source, /className="modal-footer" hidden=\{isHydrating\}/);
  assert.match(source, /hydrationPanel\.current\?\.focus/);
  assert.match(source, /aria-label="Postęp dodawania słów"/);
  assert.match(source, /Anuluj automatyczne dopasowanie/);
  assert.match(source, /Anuluj dodawanie/);
  assert.match(source, /if \(controller\.signal\.aborted\) return;/);
  assert.match(source, /if \(addMode !== "word"\) return;/);
  assert.match(source, /onClick=\{cancelHydration\}/);
  assert.match(source, /manualCollectionsRef\.current\[topicSelectionKey\(item.term\)\]/);
  const cancel = source.slice(source.indexOf("function cancelHydration"), source.indexOf("function saveHydrated"));
  assert.doesNotMatch(cancel, /onOpenChange/);
  assert.doesNotMatch(cancel, /setTopicSelected|setTopicResult/);
  const panel = source.indexOf('className="topic-hydration"');
  assert.ok(source.lastIndexOf("</div>", panel) > source.indexOf('className="quick-add-content"'));
});

test("topic import resumes only missing batches and never loses original order", async () => {
  const { prepareTopicItems } = await vite.ssrLoadModule("/lib/topic-import.ts");
  const items = Array.from({ length: 11 }, (_, i) => ({ term: `word-${i}`, pl: `słowo-${i}` }));
  const cache = new Map();
  const progress = [];
  let calls = 0;
  const options = { topic: "Lotnisko", items, cache, signal: new AbortController().signal, onProgress: (n) => progress.push(n) };
  await assert.rejects(() => prepareTopicItems({ ...options, request: async (batch) => {
    if (++calls === 2) throw new Error("LIMIT");
    return { items: batch.map(({ term }) => ({ term })) };
  }}), /LIMIT/);
  assert.deepEqual(progress, [0, 5]);
  assert.equal(cache.size, 5);
  const batches = [];
  const result = await prepareTopicItems({ ...options, request: async (batch) => {
    batches.push(batch.length);
    return { items: batch.map(({ term }) => ({ term })) };
  }});
  assert.deepEqual(batches, [5, 1]);
  assert.deepEqual(result.map((item) => item.term), items.map((item) => item.term));
  assert.deepEqual(progress, [0, 5, 5, 10, 11]);
});

test("cancelled or malformed hydration cannot leak late results into saved words", async () => {
  const { prepareTopicItems } = await vite.ssrLoadModule("/lib/topic-import.ts");
  const controller = new AbortController();
  const cache = new Map();
  const items = [{term: "gate", pl: "bramka"}];
  await assert.rejects(() => prepareTopicItems({ topic: "Lotnisko", items, cache, signal: controller.signal, onProgress: () => {}, request: async () => {
    controller.abort();
    return {items: [{term: "gate"}]};
  }}), {name: "AbortError"});
  assert.equal(cache.size, 0);
  await assert.rejects(() => prepareTopicItems({ topic: "Lotnisko", items, cache, signal: new AbortController().signal, onProgress: () => {}, request: async () => ({items: [{term: "wrong"}]}) }), /Niekompletna/);
  assert.equal(cache.size, 0);
});

test("AI speech failures require explicit consent for the device voice", async () => {
  const source = await readFile(path.join(root, "app/use-voice.ts"), "utf8");
  assert.match(source, /toast\.loading\(`Przygotowuję nagranie/);
  assert.match(source, /action: \{ label: "Głos urządzenia"/);
  assert.match(source, /Never silently switch[\s\S]*?return;/);
});

test("mobile fixes constrain dialogs, separate the daily goal and hide filter scrollbars", async () => {
  const css = await readFile(path.join(root, "app/globals.css"), "utf8");
  const source = await readFile(path.join(root, "app/fluent.tsx"), "utf8");
  assert.match(css, /\.quick-add-dialog\s*\{[^}]*width:\s*calc\(100vw - 32px\)/);
  assert.match(css, /\.quick-add-dialog \[hidden\]\s*\{\s*display:\s*none !important/);
  assert.match(css, /\.quick-word input\s*\{[^}]*min-width:\s*0/);
  assert.match(css, /\.filter-tabs\s*\{[^}]*overflow-y:\s*hidden;[^}]*scrollbar-width:\s*none/);
  assert.match(css, /\.global-search\s*\{[^}]*background:\s*color-mix/);
  assert.match(css, /grid-template-columns:\s*88px minmax\(0, 1fr\)/);
  assert.doesNotMatch(css, /\.daily-ring svg\s*\{/);
  assert.doesNotMatch(source, /Małe kroki, wielki postęp/);
});

async function readCssTree(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const contents = await Promise.all(
    entries.map(async (entry) => {
      const entryPath = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        return readCssTree(entryPath);
      }
      return entry.name.endsWith(".css") ? readFile(entryPath, "utf8") : "";
    }),
  );
  return contents.join("\n");
}

test("emits the production animation, responsive and accessible chart styles", async () => {
  const css = await readCssTree(path.join(root, "dist"));

  assert.match(css, /--tw-enter-opacity/);
  assert.match(css, /mask-image:/);
  assert.match(css, /tw-shimmer/);
  assert.match(css, /prefers-reduced-motion:\s*reduce/);
  const appCss = await readFile(path.join(root, "app/globals.css"), "utf8");
  assert.match(appCss, /\.bar-number\s*\{[^}]*opacity:\s*1/);
  assert.doesNotMatch(appCss, /\.day-bar:nth-child/);
});

test("forwards progress semantics to the primitive", async () => {
  const { Progress } = await vite.ssrLoadModule("/components/ui/progress.tsx");
  const html = renderToStaticMarkup(
    React.createElement(Progress, { value: 37 }),
  );

  assert.match(html, /aria-valuenow="37"/);
  assert.match(html, /aria-valuetext="37%"/);
  assert.match(html, /data-state="loading"/);
});

test("emits chart themes for the starter's media dark mode", async () => {
  const { ChartStyle } = await vite.ssrLoadModule("/components/ui/chart.tsx");
  const html = renderToStaticMarkup(
    React.createElement(ChartStyle, {
      id: "contract",
      config: {
        latency: { theme: { light: "#ffffff", dark: "#000000" } },
      },
    }),
  );

  assert.match(html, /\[data-chart=contract\]/);
  assert.match(html, /@media \(prefers-color-scheme: dark\)/);
  assert.doesNotMatch(html, /\.dark/);
});

test("renders sidebar skeletons deterministically", async () => {
  const { SidebarMenuSkeleton } = await vite.ssrLoadModule(
    "/components/ui/sidebar.tsx",
  );
  const first = renderToStaticMarkup(React.createElement(SidebarMenuSkeleton));
  const second = renderToStaticMarkup(React.createElement(SidebarMenuSkeleton));

  assert.equal(first, second);
  assert.match(first, /--skeleton-width:70%/);
});

test("topic cards use stable term keys and responsive category pagination", async () => {
  const {
    topicSelectionKey,
    topicPageLayout,
    topicPageAfterResize,
    orderTopicCategories,
    initialTopicSelections,
    practiceAudioAllowed,
    dialectDescription,
  } = await vite.ssrLoadModule("/app/tutor-ui.tsx");

  assert.equal(topicSelectionKey("  Boarding Pass "), "boarding pass");
  assert.equal(topicSelectionKey("BOARDING PASS"), "boarding pass");
  assert.deepEqual(topicPageLayout(390), { columns: 1, pageSize: 6 });
  assert.deepEqual(topicPageLayout(800), { columns: 2, pageSize: 12 });
  assert.deepEqual(topicPageLayout(1280), { columns: 3, pageSize: 18 });
  assert.equal(
    topicPageAfterResize(2, 6, 12),
    1,
    "the first visible card stays visible after widening",
  );
  assert.equal(topicPageAfterResize(1, 18, 6), 3);
  assert.deepEqual(
    orderTopicCategories(
      [{ name: "Bagaż" }, { name: "Dokumenty i odprawa" }],
      "Dokumenty i odprawa",
    ).map((item) => item.name),
    ["Dokumenty i odprawa", "Bagaż"],
  );
  const topic = {
    topic: "Lotnisko",
    matchSource: "fuzzy",
    focusCategory: "Odprawa",
    categories: [
      { name: "Odprawa", items: [{ term: "check-in" }, { term: "passport" }] },
      { name: "Bagaż", items: [{ term: "luggage" }] },
    ],
  };
  assert.deepEqual(
    initialTopicSelections(topic, new Set(["passport"])),
    [],
  );
  assert.deepEqual(
    initialTopicSelections(
      { ...topic, focusCategory: undefined, matchSource: "alias" },
      new Set(),
    ),
    [],
    "an uncertain matched topic must not preselect the whole parent set",
  );
  assert.equal(practiceAudioAllowed(false), false);
  assert.equal(practiceAudioAllowed(true), true);
  assert.equal(dialectDescription("AmE"), "angielski amerykański");
  assert.equal(dialectDescription("BrE"), "angielski brytyjski");
  assert.equal(dialectDescription("Other"), null);
});

test("answer explanations start collapsed for correct answers and expanded for errors",async()=>{
 const {AnswerExplanation}=await vite.ssrLoadModule("/app/answer-explanation.tsx");
 const right=renderToStaticMarkup(React.createElement(AnswerExplanation,{correct:true},"Wyjaśnienie"));
 const wrong=renderToStaticMarkup(React.createElement(AnswerExplanation,{correct:false},"Wyjaśnienie"));
 assert.doesNotMatch(right,/<details[^>]* open/);
 assert.match(wrong,/<details[^>]* open/);
 assert.match(right,/<summary>/);
 const {initialTopicSelections}=await vite.ssrLoadModule("/app/tutor-ui.tsx");
 for(const matchSource of ["exact","alias","fuzzy","model",undefined])
  assert.deepEqual(initialTopicSelections({topic:"Lotnisko",matchSource,categories:[{name:"Odprawa",items:[{term:"passport"}]}]},new Set()),[]);
});

test("v35 preparation renders nothing and unavailable vocabulary modes have hourglasses",async()=>{
 const {VocabularyPreparation}=await vite.ssrLoadModule("/app/vocabulary-preparation.tsx");
 const {seed}=await vite.ssrLoadModule("/lib/learning.ts");
 const state=seed();state.words[0].meanings[0].enrichment={phase:"examples",groups:[],attempts:0,retryAt:0};
 assert.equal(renderToStaticMarkup(React.createElement(VocabularyPreparation,{state,onSave:()=>true,enabled:true})),"");
 const source=await readFile(path.join(root,"app/fluent.tsx"),"utf8");
 assert.match(source,/disabled=\{waitingForVocabulary\(m.id\)\}/);
 assert.match(source,/<Hourglass size=\{25\} aria-label="Zadania są aktualizowane"/);
 const queue=await readFile(path.join(root,"app/vocabulary-preparation.tsx"),"utf8");
 assert.match(queue,/toast.error[\s\S]*label:"Ponów"/);
 const css=await readFile(path.join(root,"app/globals.css"),"utf8");
 assert.match(css,/\.feedback.wrong\s*\{\s*background: #fff0f0;\s*color: #a52222;/);
 assert.match(css,/\.dark .feedback.wrong\s*\{\s*background: #49252b;\s*color: #ffd0d0;/);
});


test("exercise audio labels reflect checking state and vocabulary grading never calls AI", async () => {
 const {ExerciseAudio}=await vite.ssrLoadModule("/app/exercise-audio.tsx");
 const pending=renderToStaticMarkup(React.createElement(ExerciseAudio,{text:"I [[gap]] home.",solved:false,speak:()=>{}}));
 const checked=renderToStaticMarkup(React.createElement(ExerciseAudio,{text:"I went home.",solved:true,speak:()=>{}}));
 assert.match(pending,/luka pozostanie pusta/);assert.match(checked,/poprawną odpowiedzią/);
 const source=await readFile(path.join(root,"app/fluent.tsx"),"utf8");
 const check=source.slice(source.indexOf("async function check()"),source.indexOf("function advance("));
 assert.match(check,/localGrade/);assert.doesNotMatch(check,/tutorRequest|fetch|uncertain/);
 const reports=await readFile(path.join(root,"app/exercise-reports.tsx"),"utf8");
 assert.doesNotMatch(reports,/tutorRequest/);assert.match(reports,/saveExerciseReport\(localStorage/);assert.ok(reports.includes("fetch('/api/reports')"));
 assert.match(source,/<ExerciseReports\s*\//);
});


test("v39 written mixed tasks render an input without answer choices; reading words are accessible buttons",async()=>{
 const {SkillPractice,ReadingPractice}=await vite.ssrLoadModule("/app/tutor-ui.tsx");
 const {seed}=await vite.ssrLoadModule("/lib/learning.ts");
 const {starterPractice,starterReading}=await vite.ssrLoadModule("/lib/tutor-local.ts");
 const state=seed(),set=starterPractice("mixed","B1",0);
 state.practice={set,index:0,answers:set.items.map(()=>-1),writtenAnswers:set.items.map(()=>"")};
 const html=renderToStaticMarkup(React.createElement(SkillPractice,{state,kind:"mixed",onSave:()=>true,ai:true,speak:()=>{},onExit:()=>{}}));
 assert.match(html,/id="mixed-answer"/);assert.match(html,/Podpowiedź/);assert.doesNotMatch(html,/answer-options practice-options/);
 const {ReadingVocabulary}=await vite.ssrLoadModule("/app/reading-vocabulary.tsx");
 const words=renderToStaticMarkup(React.createElement(ReadingVocabulary,{text:"Can you lend me a pen?",words:state.words}));
 assert.match(words,/lend — słowo z Twojego słownika/);assert.match(words,/aria-haspopup="dialog"/);
 state.reading={reading:starterReading("C2"),answers:Array(6).fill(-1),submitted:false};
 const reading=renderToStaticMarkup(React.createElement(ReadingPractice,{state,onSave:()=>true,ai:true,speak:()=>{},onExit:()=>{}}));
 assert.match(reading,/6 pytań/);
 const source=await readFile(path.join(root,"app/tutor-ui.tsx"),"utf8");assert.doesNotMatch(source,/warmPrepared/);
});

test('v40 hints are closed by default, dictionary popovers use click, and combined sessions render one task',async()=>{
 const {HintDisclosure}=await vite.ssrLoadModule('/app/hint-disclosure.tsx');
 const hint=renderToStaticMarkup(React.createElement(HintDisclosure,{text:'sadzić'}));
 assert.match(hint,/<details class="exercise-hint">/);
 assert.doesNotMatch(hint,/<details[^>]*open/);
 assert.match(hint,/<summary>[\s\S]*Podpowiedź/);
 const source=await readFile(path.join(root,'app/reading-vocabulary.tsx'),'utf8');
 assert.doesNotMatch(source,/onPointerEnter|onMouseEnter|onPointerLeave/);
 const {CombinedPractice}=await vite.ssrLoadModule('/app/combined-practice.tsx');
 const {makeCombinedSession}=await vite.ssrLoadModule('/lib/combined-session.ts');
 const {seed}=await vite.ssrLoadModule('/lib/learning.ts');
 const state=seed();state.combined=makeCombinedSession(state,['language-mix','reading'],5,false);
 const html=renderToStaticMarkup(React.createElement(CombinedPractice,{state,onSave:()=>true,onExit:()=>{},speak:()=>{}}));
 assert.match(html,/Sesja łączona/);assert.match(html,/id="combined-answer"/);
 assert.equal((html.match(/class="card practice-card"/g)||[]).length,1);
 assert.doesNotMatch(html,/shuffle-session/,'randomization is unavailable during exercises');
 const app=await readFile(path.join(root,'app/fluent.tsx'),'utf8');
 assert.match(app,/Wyjść z ćwiczeń\?/);assert.match(app,/Zostań w ćwiczeniu/);assert.match(app,/useAnswerScroll\(!!feedback \|\| revealed\)/);
});

test('v41: combined exercises identify their actual skill and multi-selection has no enabling switch',async()=>{
 const {CombinedPractice}=await vite.ssrLoadModule('/app/combined-practice.tsx');
 const {makeCombinedSession}=await vite.ssrLoadModule('/lib/combined-session.ts');
 const {seed}=await vite.ssrLoadModule('/lib/learning.ts');
 for(const [modes,label] of [[['grammar','reading'],'Gramatyka'],[['idioms','reading'],'Idiomy'],[['mixed','reading'],'Słownictwo']]){
  const state=seed();state.combined=makeCombinedSession(state,modes,5,false);
  const html=renderToStaticMarkup(React.createElement(CombinedPractice,{state,onSave:()=>true,onExit:()=>{},speak:()=>{}}));
  assert.match(html,new RegExp(`exercise-kind-banner[\\s\\S]*<strong>${label}`));
 }
 const app=await readFile(path.join(root,'app/fluent.tsx'),'utf8');
 assert.doesNotMatch(app,/choose-many|Wybierz wiele|setChooseMany/);
 assert.match(app,/const chooseMany=selectedModes.length>1/);
 assert.match(app,/aria-pressed=\{selectedModes.includes/);
 const {withoutDialectLabel}=await vite.ssrLoadModule('/lib/answer-variants.ts');
 assert.equal(withoutDialectLabel('rachunek (AmE)'),'rachunek');
 const ui=await readFile(path.join(root,'app/tutor-ui.tsx'),'utf8');assert.doesNotMatch(ui,/topic-dialect-legend/);
});

test('v42: exercise kind is a visible responsive banner in every exercise surface',async()=>{
 const {ExerciseKind}=await vite.ssrLoadModule('/app/exercise-kind.tsx');
 for(const kind of ['Słownictwo','Gramatyka','Idiomy','Czytanie','Słuchanie']){
  const html=renderToStaticMarkup(React.createElement(ExerciseKind,{kind,detail:'Ćwiczenie'}));
  assert.match(html,/Rodzaj ćwiczenia/);assert.match(html,new RegExp(`<strong>${kind}`));
 }
 for(const file of ['fluent.tsx','combined-practice.tsx','production-practice.tsx','tutor-ui.tsx'])assert.match(await readFile(path.join(root,'app',file),'utf8'),/<ExerciseKind /);
 const css=await readFile(path.join(root,'app/globals.css'),'utf8');assert.match(css,/exercise-kind-banner strong[^}]*overflow-wrap:anywhere/);
});
