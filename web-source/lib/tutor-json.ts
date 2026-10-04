const str = { type: "string" };
const arr = (items: unknown) => ({ type: "array", items });
const obj = (properties: Record<string, unknown>) => ({
  type: "object",
  properties,
  required: Object.keys(properties),
  additionalProperties: false,
});
export const pairJSON = obj({ en: str, pl: str, focusEn: str, focusPl: str });
export const exampleBatchJSON = obj({examples:arr(pairJSON)});
export const lookupJSON = obj({
  exists: { type: "boolean" },
  term: str,
  ipa: str,
  forms: str,
  collocations: str,
  synonyms: str,
  antonyms: str,
  note: str,
  alternatives: arr(str),
  meanings: arr(
    obj({
      translation: str,
      definition: str,
      pos: str,
      level: str,
      levelConfidence: {
        type: "string",
        enum: ["high", "medium", "low"],
      },
      levelReason: str,
      spokenFrequency: {
        type: "string",
        enum: ["very_common", "common", "less_common", "rare"],
      },
      context: str,
      register: str,
      natural: str,
      collection: str,
      examples: arr(pairJSON),
      acceptedAnswers: arr(str),
      acceptedTranslations: arr(str),
    }),
  ),
});
export const gradeJSON = obj({
  verdict: { type: "string", enum: ["correct", "incorrect", "uncertain"] },
  explanation: str,
  spellingCorrect: { type: "boolean" },
});
export const readingJSON = obj({
  title: str,
  level: str,
  paragraphs: arr(str),
  questions: arr(
    obj({
      question: str,
      options: arr(str),
      answer: { type: "integer" },
      explanation: str,
      evidence: str,
      meaningId: str,
    }),
  ),
});
export const recommendationJSON = obj({
  items: arr(
    obj({
      known: str,
      term: str,
      level: str,
      translation: str,
      difference: str,
      example: str,
      examplePl: str,
    }),
  ),
});
export const topicListJSON = obj({
  topic: str,
  categories: arr(
    obj({
      name: str,
      items: arr(
        obj({
          term: str,
          pl: str,
          pos: str,
          level: {
            type: "string",
            enum: ["A1", "A2", "B1", "B2", "C1", "C2"],
          },
          spokenFrequency: {
            type: "string",
            enum: ["very_common", "common", "less_common", "rare"],
          },
        }),
      ),
    }),
  ),
});
export const topicHydrateJSON = obj({
  items: arr(lookupJSON),
});
export const recontextualizeJSON = obj({
  examples: arr(pairJSON),
});
export const cefrAuditJSON = obj({
  assessments: arr(
    obj({
      itemIndex: { type: "integer" },
      meaningIndex: { type: "integer" },
      level: {
        type: "string",
        enum: ["A1", "A2", "B1", "B2", "C1", "C2"],
      },
      confidence: {
        type: "string",
        enum: ["high", "medium", "low"],
      },
      spokenFrequency: {
        type: "string",
        enum: ["very_common", "common", "less_common", "rare"],
      },
      reason: str,
    }),
  ),
});
export const practiceJSON = obj({
  title: str,
  level: str,
  kind: { type: "string", enum: ["grammar", "idioms", "mixed"] },
  items: arr(
    obj({
      category: { type: "string", enum: ["grammar", "idiom"] },
      prompt: str,
      context: str,
      options: arr(str),
      answer: { type: "integer" },
      explanation: str,
      translation: str,
    }),
  ),
});
export const productionJSON = obj({
  title: str,
  level: {type:"string",enum:["A1","A2","B1","B2","C1","C2"]},
  items: {...arr(obj({
    context: str, hintPl: str, answer: str, acceptedAnswers: arr(str),
    distractors: {...arr(obj({form:str,diagnosis:{type:"string",enum:["wrong_tense","wrong_aspect","wrong_voice","wrong_agreement","wrong_word"]},explanation:str})),minItems:2,maxItems:4},
    rule:str,explanation:str,translation:str,
  })),minItems:4,maxItems:10},
});
