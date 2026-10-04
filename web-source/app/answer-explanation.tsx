import type { ReactNode } from "react";
export function AnswerExplanation({correct,children}:{correct:boolean;children:ReactNode}) {
  return <details className="answer-explanation" open={correct ? undefined : true}>
    <summary>{correct ? "Dlaczego ta odpowiedź jest poprawna?" : "Wyjaśnienie i poprawna odpowiedź"}</summary>
    <div className="answer-explanation-content">{children}</div>
  </details>;
}
