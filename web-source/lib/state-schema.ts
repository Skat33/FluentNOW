import {combinedSessionSchema} from "./combined-schema";
import {
  practiceKindSchema,
  practiceQuestionSchema,
  readingSessionSchema,
  productionSessionSchema,
} from "./tutor-schema";
import { z } from "zod";
const score = z.object({
  value: z.number().min(0).max(100),
  interval: z.number().min(0),
  due: z.number(),
  correct: z.number().int().min(0),
  wrong: z.number().int().min(0),
  hinted: z.number().int().min(0).optional(),
  last: z.number(),
  slow: z.number().int().min(0),
});
const short = z.string().max(500),
  long = z.string().max(10000);
export const stateSchema = z
  .object({
    combined: combinedSessionSchema.nullable().optional(),
    grammarSeen: z.record(z.string().max(120),z.number().min(0)).refine(value=>Object.keys(value).length<=5000,"Too many grammar records").optional(),
    words: z
      .array(
        z.object({
          id: short,
          en: short.min(1),
          ipa: short,
          pos: short,
          level: short,
          collection: short,
          tags: z.array(short).max(100),
          source: short,
          note: long,
          forms: short,
          collocations: long,
          synonyms: long,
          antonyms: long,
          important: z.boolean(),
          hard: z.boolean(),
          archived: z.boolean(),
          created: z.number(),
          updatedAt: z.number().optional(),
          meanings: z
            .array(
              z.object({
                id: short,
                topic: short.optional(),
                scene: long.optional(),
                usedExamples: z.array(z.number().int().min(0).max(89)).max(90).optional(),
                enrichment: z.object({round:z.number().int().min(0).max(5).optional(),phase:z.enum(["details","examples","ready"]),detailsPending:z.boolean().optional(),groups:z.array(z.enum(["affirmative","negative","question"])).max(3),attempts:z.number().int().min(0).max(1000),retryAt:z.number().min(0),error:short.optional()}).optional(),
                exampleTranslations: z.array(long).max(90).optional(),
                exampleFocusEn: z.array(short).max(90).optional(),
                exampleFocusPl: z.array(short).max(90).optional(),
                acceptedAnswers: z.array(short).max(30).optional(),
                acceptedTranslations: z.array(short).max(30).optional(),
                level: short.optional(),
                levelConfidence: z.enum(["high", "medium", "low"]).optional(),
                levelReason: short.optional(),
                spokenFrequency: z
                  .enum(["very_common", "common", "less_common", "rare"])
                  .optional(),
                pos: short.optional(),
                translation: short.min(1),
                definition: long,
                examples: z.array(long).max(90),
                context: long,
                register: short,
                natural: long,
                scores: z.object({
                  recognition: score.optional(),
                  recall: score.optional(),
                  spelling: score.optional(),
                  listening: score.optional(),
                  usage: score.optional(),
                  pronunciation: score.optional(),
                }),
              }),
            )
            .min(1)
            .max(100),
        }),
      )
      .max(10000),
    collections: z.array(short).max(1000),
    reviews: z
      .array(
        z.object({
          id: short,
          wordId: short,
          meaningId: short,
          skill: z.enum([
            "recognition",
            "recall",
            "spelling",
            "listening",
            "usage",
            "pronunciation",
          ]),
          correct: z.boolean(),
          at: z.number(),
          seconds: z.number().min(0),
          confidence: z.number().min(1).max(3),
          hint: z.boolean(),
          error: short,
          before: z.number(),
          after: z.number(),
          masteryVersion: z.literal(2).optional(),
          weight: z.number().min(0).max(1).optional(),
          source: z.enum(["exercise", "reading"]).optional(),
          demo: z.boolean().optional(),
        }),
      )
      .max(100000),
    reviewSummaries: z
      .array(
        z.object({
          day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
          count: z.number().int().min(0),
          correct: z.number().int().min(0),
        }),
      )
      .max(10000)
      .optional(),
    settings: z.object({
      goal: z.number().int().min(5).max(100),
      reminder: z.string().regex(/^\d{2}:\d{2}$/),
      accent: z.enum(["en-GB", "en-US"]),
      slow: z.boolean(),
      voice: short.optional(),
      voiceRevision: z.number().optional(),
    }),
    session: z
      .object({
        tasks: z
          .array(
            z.object({
              wordId: short,
              meaningId: short,
              type: z.number().int().min(0).max(4),
              example: z.number().int().min(0),
            }),
          )
          .max(100),
        index: z.number().int().min(0),
        correct: z.number().int().min(0),
        minutes: z.number(),
        mode: short,
      })
      .nullable(),
    reading: readingSessionSchema.nullable().optional(),
    readingHistory: z
      .array(
        z.object({
          id: short,
          at: z.number(),
          level: short,
          correct: z.number(),
          total: z.number(),
          title: short.optional(),
        }),
      )
      .max(10000)
      .optional(),
    practice: z
      .object({
        set: z.object({
          id: short,
          title: short,
          level: short,
          kind: practiceKindSchema,
          items: z.array(practiceQuestionSchema).min(4).max(10),
          source: z.enum(["ai", "starter"]),
        }),
        answers: z.array(z.number().int().min(-1).max(3)).max(10),
        writtenAnswers: z.array(z.string().max(500)).max(10).optional(),
        index: z.number().int().min(0).max(10),
        completedAt: z.number().optional(),
      })
      .nullable()
      .optional(),
    practiceHistory: z
      .array(
        z.object({
          id: short,
          at: z.number(),
          kind: practiceKindSchema,
          level: short,
          correct: z.number().int().min(0),
          total: z.number().int().min(1),
          title: short,
        }),
      )
      .max(10000)
      .optional(),
    production: productionSessionSchema.nullable().optional(),
    productionHistory: z.array(z.object({id:short,at:z.number(),level:short,correct:z.number().int().min(0),total:z.number().int().min(4).max(10),title:short})).max(10000).optional(),
    demo: z.boolean(),
  })
  .superRefine((s, ctx) => {
    const wordIds = new Set<string>();
    const meaningIds = new Set<string>();
    for (const w of s.words) {
      if (wordIds.has(w.id)) {
        ctx.addIssue({ code: "custom", message: "Duplicate word ID" });
        return;
      }
      wordIds.add(w.id);
      for (const m of w.meanings) {
        if (meaningIds.has(m.id)) {
          ctx.addIssue({ code: "custom", message: "Duplicate meaning ID" });
          return;
        }
        meaningIds.add(m.id);
      }
    }
    if (new Set(s.collections).size !== s.collections.length) {
      ctx.addIssue({ code: "custom", message: "Duplicate collection" });
      return;
    }
    if (s.session) {
      if (
        s.session.index > s.session.tasks.length ||
        s.session.correct > s.session.index
      ) {
        ctx.addIssue({ code: "custom", message: "Invalid session position" });
        return;
      }
      for (const t of s.session.tasks) {
        if (
          !s.words
            .find((w) => w.id === t.wordId)
            ?.meanings.some((m) => m.id === t.meaningId)
        ) {
          ctx.addIssue({ code: "custom", message: "Missing task meaning" });
          return;
        }
      }
    }
    if (
      s.practice &&
      (s.practice.answers.length !== s.practice.set.items.length ||
        (s.practice.writtenAnswers !== undefined && s.practice.writtenAnswers.length !== s.practice.set.items.length) ||
        s.practice.index >= s.practice.set.items.length)
    )
      ctx.addIssue({ code: "custom", message: "Invalid practice session" });
  });
