export type View =
  | "today"
  | "words"
  | "collections"
  | "study"
  | "stats"
  | "settings";

export type NavigationState = { view: View; detail: string | null };
export type NavigationAction =
  | { type: "navigate"; view: View }
  | { type: "open-word"; id: string }
  | { type: "close-word" };

export const initialNavigation: NavigationState = {
  view: "today",
  detail: null,
};

export function navigationReducer(
  state: NavigationState,
  action: NavigationAction,
): NavigationState {
  if (action.type === "navigate") return { view: action.view, detail: null };
  if (action.type === "open-word") return { view: "words", detail: action.id };
  return { ...state, detail: null };
}
