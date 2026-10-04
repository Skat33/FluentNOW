import { z } from "zod";
const text = z.string().min(1).max(3000),
  short = z.string().max(500);
export const cefr = z.enum(["A1", "A2", "B1", "B2", "C1", "C2"]);
export const cefrConfidence = z.enum(["high", "medium", "low"]);
export const spokenFrequency = z.enum([
  "very_common",
  "common",
  "less_common",
  "rare",
]);
export const pairSchema = z.object({
  en: text,
  pl: text,
  focusEn: text,
  focusPl: text,
});
export const exampleBatchSchema = z.object({examples:z.array(pairSchema.extend({en:z.string().min(1).max(500)})).length(5)}).superRefine((data,ctx)=>{
  if (new Set(data.examples.map(e=>e.en.trim().toLowerCase())).size !== 5 || data.examples.some(e=>!e.en.includes(e.focusEn) || !e.pl.includes(e.focusPl)))
    ctx.addIssue({code:"custom",message:"Five distinct examples with exact highlights required"});
});
export const lookupSchema = z
  .object({
    exists: z.boolean(),
    term: short,
    ipa: short,
    forms: short,
    collocations: short,
    synonyms: short,
    antonyms: short,
    note: short,
    alternatives: z.array(short).max(5),
    meanings: z
      .array(
        z.object({
          translation: text,
          definition: text,
          pos: short,
          level: cefr,
          levelConfidence: cefrConfidence.optional(),
          levelReason: short.optional(),
          spokenFrequency: spokenFrequency.optional(),
          context: text,
          register: short,
          natural: short,
          collection: short.min(1),
          examples: z.array(pairSchema).min(1).max(4),
          acceptedAnswers: z.array(short).max(15),
          acceptedTranslations: z.array(short).max(30).optional(),
        }),
      )
      .max(10),
  })
  .superRefine((d, ctx) => {
    if ((d.exists && !d.meanings.length) || (!d.exists && d.meanings.length))
      ctx.addIssue({
        code: "custom",
        message: "Inconsistent existence result",
      });
    for (const m of d.meanings)
      for (const e of m.examples) {
        if (
          !e.en.toLowerCase().includes(e.focusEn.toLowerCase()) ||
          !e.pl.toLowerCase().includes(e.focusPl.toLowerCase())
        )
          ctx.addIssue({
            code: "custom",
            message: "Highlighted expression must occur in sentence",
          });
      }
  });
export const gradeSchema = z.object({
  verdict: z.enum(["correct", "incorrect", "uncertain"]),
  explanation: text,
  spellingCorrect: z.boolean(),
});
export const readingSchema = z
  .object({
    title: short.min(1),
    level: cefr,
    paragraphs: z.array(text).min(1).max(6),
    questions: z
      .array(
        z.object({
          question: text,
          options: z.array(text).length(4),
          answer: z.number().int().min(0).max(3),
          explanation: text,
          evidence: text,
          meaningId: short.optional(),
        }),
      )
      .min(3)
      .max(6),
  })
  .superRefine((r, ctx) => {
    for (const q of r.questions) {
      if (
        new Set(q.options).size !== 4 ||
        !r.paragraphs.join(" ").includes(q.evidence)
      )
        ctx.addIssue({
          code: "custom",
          message:
            "Question must have distinct answers and a supporting quotation from the passage.",
        });
    }
  });
export const readingSessionSchema = z
  .object({
    reading: readingSchema.and(
      z.object({ id: short, source: z.enum(["ai", "starter"]) }),
    ),
    answers: z.array(z.number().int().min(-1).max(3)).max(6),
    submitted: z.boolean(),
    completedAt: z.number().optional(),
  })
  .superRefine((s, ctx) => {
    if (
      s.answers.length !== s.reading.questions.length ||
      (s.submitted && s.answers.some((a) => a < 0))
    )
      ctx.addIssue({ code: "custom", message: "Invalid reading answers" });
  });
export const recommendationSchema = z.object({
  items: z
    .array(
      z.object({
        known: short,
        term: short,
        level: cefr,
        translation: short,
        difference: text,
        example: text,
        examplePl: text,
      }),
    )
    .max(3),
});
export const topicListItemSchema = z.object({
  term: short.min(1),
  pl: short.min(1),
  pos: short.min(1),
  level: cefr,
  spokenFrequency,
});
export const topicListSchema = z.object({
  topic: short.min(1),
  categories: z
    .array(
      z.object({
        name: short.min(1),
        items: z.array(topicListItemSchema),
      }),
    )
    .min(5)
    .max(9),
});
export const topicHydrateSchema = z.object({
  items: z.array(lookupSchema).min(1).max(10),
}).superRefine((result, ctx) => {
  for (const [itemIndex, item] of result.items.entries())
    if (
      !item.exists ||
      item.meanings.length !== 1 ||
      item.meanings[0]?.examples.length !== 2
    )
      ctx.addIssue({
        code: "custom",
        path: ["items", itemIndex],
        message: "Hydrated topic items need one meaning and two examples.",
      });
});
export const recontextualizeSchema = z.object({
  examples: z.array(pairSchema).length(2),
});
export const cefrAuditSchema = z.object({
  assessments: z
    .array(
      z.object({
        itemIndex: z.number().int().min(0),
        meaningIndex: z.number().int().min(0),
        level: cefr,
        confidence: cefrConfidence,
        spokenFrequency,
        reason: short.min(1),
      }),
    ),
});
export const practiceKindSchema = z.enum(["grammar", "idioms", "mixed"]);
export const productionDiagnosisSchema = z.enum(["wrong_tense", "wrong_aspect", "wrong_voice", "wrong_agreement", "wrong_word"]);
export const productionItemSchema = z.object({
  bankId:z.string().max(120).optional(),scenarioId:z.string().max(120).optional(),
  context: z.string().min(1).max(500),
  hintPl: z.string().min(1).max(80).regex(/^[a-ząćęłńóśźż ]*[ćc](?: się)?$/i, "Hint must be a Polish infinitive"),
  answer: z.string().min(1).max(160),
  acceptedAnswers: z.array(z.string().min(1).max(160)).max(6),
  distractors: z.array(z.object({form:z.string().min(1).max(160), diagnosis:productionDiagnosisSchema, explanation:z.string().min(1).max(400)})).min(2).max(4),
  rule: z.string().min(1).max(120),
  explanation: z.string().min(1).max(600),
  translation: z.string().min(1).max(500),
}).superRefine((item, ctx) => {
  if (item.context.split("________").length !== 2 || !item.context.includes(`(${item.hintPl})`))
    ctx.addIssue({code:"custom", message:"One gap and exact infinitive hint required"});
  if (new Set(item.distractors.map((d) => d.form.toLowerCase())).size !== item.distractors.length || item.distractors.some((d) => [item.answer,...item.acceptedAnswers].some((a) => a.toLowerCase() === d.form.toLowerCase())))
    ctx.addIssue({code:"custom", message:"Distractors must be distinct incorrect forms"});
});
export const productionSetSchema = z.object({title:short.min(1),level:cefr,items:z.array(productionItemSchema).min(4).max(10)});
export const productionResultSchema = z.object({correct:z.boolean(),spellingCorrect:z.boolean(),diagnosis:productionDiagnosisSchema.or(z.enum(["spelling","general"])).nullable(),explanation:text});
export const productionSessionSchema = z.object({
  id:short.min(1),set:productionSetSchema,source:z.enum(["ai","starter"]),index:z.number().int().min(0).max(10),
  answers:z.array(z.string().max(500)).min(4).max(10),results:z.array(productionResultSchema.nullable()).min(4).max(10),completedAt:z.number().optional(),
}).superRefine((session, ctx) => {
  if (session.answers.length !== session.set.items.length || session.results.length !== session.set.items.length || session.index >= session.set.items.length)
    ctx.addIssue({code:"custom",message:"Invalid production session"});
});
export const practiceQuestionSchema = z.object({
  format:z.enum(["choice","input"]).optional(),
  inputHint:short.optional(),
  acceptedAnswers:z.array(short).max(20).optional(),
  bankId:z.string().max(120).optional(),scenarioId:z.string().max(120).optional(),
  category: z.enum(["grammar", "idiom"]),
  prompt: text,
  context: text,
  options: z.array(text).length(4),
  answer: z.number().int().min(0).max(3),
  explanation: text,
  translation: text,
});
export const practiceSetSchema = z
  .object({
    title: short.min(1),
    level: cefr,
    kind: practiceKindSchema,
    items: z.array(practiceQuestionSchema).min(4).max(10),
  })
  .superRefine((set, ctx) => {
    for (const item of set.items)
      if (new Set(item.options).size !== 4)
        ctx.addIssue({ code: "custom", message: "Answers must be distinct" });
    if (
      set.kind === "grammar" &&
      set.items.some((item) => item.category !== "grammar")
    )
      ctx.addIssue({ code: "custom", message: "Invalid grammar category" });
    if (
      set.kind === "idioms" &&
      set.items.some((item) => item.category !== "idiom")
    )
      ctx.addIssue({ code: "custom", message: "Invalid idiom category" });
  });
