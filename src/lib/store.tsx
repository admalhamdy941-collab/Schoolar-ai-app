"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useReducer, type ReactNode } from "react";
import type { BadgeDTO, GenerateRequest, GenerateResponse, Lang, ModuleKey, ProgressDTO, SessionDTO } from "./types";

/* ----------------------------- Haptics helper ----------------------------- */
export function haptic(pattern: number | number[] = 12) {
  if (typeof navigator !== "undefined" && "vibrate" in navigator) {
    try {
      navigator.vibrate(pattern);
    } catch {
      /* unsupported */
    }
  }
}

/* --------------------------- Offline cache layer -------------------------- */
const CACHE_KEY = "scholar.sessions.v1";
const PROGRESS_KEY = "scholar.progress.v1";
const PREFS_KEY = "scholar.prefs.v1";
const UNLOCK_KEY = "scholar.cameraUnlocked.v1";
const DIALECT_KEY = "scholar.dialectUnlocked.v1";

function loadJSON<T>(key: string, fallback: T): T {
  if (typeof window === "undefined") return fallback;
  try {
    const raw = localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch {
    return fallback;
  }
}
function saveJSON(key: string, value: unknown) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    /* quota exceeded — ignore */
  }
}

/* --------------------------------- State ---------------------------------- */
export type Tab = "home" | ModuleKey;

interface State {
  tab: Tab;
  lang: Lang;
  dark: boolean;
  online: boolean;
  hydrated: boolean;
  progress: ProgressDTO | null;
  sessions: SessionDTO[]; // newest first, mirrored to localStorage
  loading: boolean;
  error: string | null;
  toast: { text: string; badges?: BadgeDTO[] } | null;
  activeSessionId: number | null;
  cameraUnlocked: boolean;
  dialectUnlocked: boolean;
  draftInput: string;
}

type Action =
  | { type: "hydrate"; payload: Partial<State> }
  | { type: "tab"; tab: Tab }
  | { type: "lang"; lang: Lang }
  | { type: "dark"; dark: boolean }
  | { type: "online"; online: boolean }
  | { type: "progress"; progress: ProgressDTO }
  | { type: "sessions"; sessions: SessionDTO[] }
  | { type: "addSession"; session: SessionDTO }
  | { type: "patchSession"; id: number; patch: Partial<SessionDTO> }
  | { type: "loading"; loading: boolean }
  | { type: "error"; error: string | null }
  | { type: "toast"; toast: State["toast"] }
  | { type: "active"; id: number | null }
  | { type: "unlock" }
  | { type: "unlockDialect" }
  | { type: "draft"; draftInput: string };

const initial: State = {
  tab: "home",
  lang: "en",
  dark: false,
  online: true,
  hydrated: false,
  progress: null,
  sessions: [],
  loading: false,
  error: null,
  toast: null,
  activeSessionId: null,
  cameraUnlocked: false,
  dialectUnlocked: false,
  draftInput: "",
};

function reducer(s: State, a: Action): State {
  switch (a.type) {
    case "hydrate":
      return { ...s, ...a.payload, hydrated: true };
    case "tab":
      return { ...s, tab: a.tab, error: null };
    case "lang":
      return { ...s, lang: a.lang };
    case "dark":
      return { ...s, dark: a.dark };
    case "online":
      return { ...s, online: a.online };
    case "progress":
      return { ...s, progress: a.progress };
    case "sessions":
      return { ...s, sessions: a.sessions };
    case "addSession":
      return { ...s, sessions: [a.session, ...s.sessions.filter((x) => x.id !== a.session.id)].slice(0, 60) };
    case "patchSession":
      return { ...s, sessions: s.sessions.map((x) => (x.id === a.id ? { ...x, ...a.patch } : x)) };
    case "loading":
      return { ...s, loading: a.loading };
    case "error":
      return { ...s, error: a.error };
    case "toast":
      return { ...s, toast: a.toast };
    case "active":
      return { ...s, activeSessionId: a.id };
    case "unlock":
      return { ...s, cameraUnlocked: true };
    case "unlockDialect":
      return { ...s, dialectUnlocked: true };
    case "draft":
      return { ...s, draftInput: a.draftInput };
  }
}

interface Ctx extends State {
  setTab: (t: Tab) => void;
  setLang: (l: Lang) => void;
  toggleDark: () => void;
  generate: (req: Omit<GenerateRequest, "lang">) => Promise<SessionDTO | null>;
  submitQuiz: (sessionId: number, correct: number, total: number) => Promise<void>;
  openSession: (id: number | null) => void;
  refresh: () => Promise<void>;
  dismissToast: () => void;
  unlockCamera: () => void;
  unlockDialect: () => void;
  setDraftInput: (v: string) => void;
}

const StoreContext = createContext<Ctx | null>(null);

export function StoreProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(reducer, initial);

  // Hydrate from offline cache first (instant), then sync from server.
  useEffect(() => {
    const prefs = loadJSON<{ lang: Lang; dark: boolean }>(PREFS_KEY, {
      lang: "en",
      dark: true,
    });
    dispatch({
      type: "hydrate",
      payload: {
        ...prefs,
        online: navigator.onLine,
        sessions: loadJSON<SessionDTO[]>(CACHE_KEY, []),
        progress: loadJSON<ProgressDTO | null>(PROGRESS_KEY, null),
        cameraUnlocked: loadJSON<boolean>(UNLOCK_KEY, false),
        dialectUnlocked: loadJSON<boolean>(DIALECT_KEY, false),
      },
    });
    const on = () => dispatch({ type: "online", online: true });
    const off = () => dispatch({ type: "online", online: false });
    window.addEventListener("online", on);
    window.addEventListener("offline", off);
    return () => {
      window.removeEventListener("online", on);
      window.removeEventListener("offline", off);
    };
  }, []);

  // Persist caches whenever they change.
  useEffect(() => {
    if (!state.hydrated) return;
    saveJSON(CACHE_KEY, state.sessions);
  }, [state.sessions, state.hydrated]);
  useEffect(() => {
    if (!state.hydrated) return;
    if (state.progress) saveJSON(PROGRESS_KEY, state.progress);
  }, [state.progress, state.hydrated]);
  useEffect(() => {
    if (!state.hydrated) return;
    saveJSON(PREFS_KEY, { lang: state.lang, dark: state.dark });
    document.documentElement.classList.add("dark");
    document.documentElement.lang = state.lang;
    document.documentElement.dir = state.lang === "ar" ? "rtl" : "ltr";
  }, [state.lang, state.dark, state.hydrated]);

  const refresh = useCallback(async () => {
    if (!navigator.onLine) return;
    try {
      const [p, s] = await Promise.all([fetch("/api/progress"), fetch("/api/sessions")]);
      if (p.ok) dispatch({ type: "progress", progress: await p.json() });
      if (s.ok) dispatch({ type: "sessions", sessions: await s.json() });
    } catch {
      /* offline — keep cache */
    }
  }, []);

  useEffect(() => {
    if (state.hydrated) void refresh();
  }, [state.hydrated, refresh]);

  const generate = useCallback<Ctx["generate"]>(
    async (req) => {
      dispatch({ type: "loading", loading: true });
      dispatch({ type: "error", error: null });
      try {
        if (!navigator.onLine) throw new Error("You are offline. Cached lessons are still available in your Library.");
        const res = await fetch("/api/generate", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ ...req, lang: state.lang }),
        });
        const data = (await res.json()) as GenerateResponse & { error?: string };
        if (!res.ok) throw new Error(data.error ?? "Generation failed");
        const session: SessionDTO = {
          id: data.sessionId,
          module: req.module,
          language: state.lang,
          title: data.result.title,
          inputText: req.input || "[image]",
          result: data.result,
          xpAwarded: data.xpAwarded,
          quizScore: null,
          createdAt: new Date().toISOString(),
        };
        dispatch({ type: "addSession", session });
        dispatch({ type: "progress", progress: data.progress });
        dispatch({ type: "active", id: session.id });
        haptic([10, 30, 10]);
        dispatch({
          type: "toast",
          toast: {
            text: `+${data.xpAwarded} XP${data.source === "demo" ? " · demo mode (set GEMINI_API_KEY)" : ""}`,
            badges: data.newBadges,
          },
        });
        return session;
      } catch (e) {
        haptic([40, 40, 40]);
        dispatch({ type: "error", error: e instanceof Error ? e.message : "Something went wrong" });
        return null;
      } finally {
        dispatch({ type: "loading", loading: false });
      }
    },
    [state.lang],
  );

  const submitQuiz = useCallback<Ctx["submitQuiz"]>(async (sessionId, correct, total) => {
    dispatch({ type: "patchSession", id: sessionId, patch: { quizScore: correct } });
    if (!navigator.onLine) return;
    try {
      const res = await fetch("/api/quiz", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sessionId, correct, total }),
      });
      if (!res.ok) return;
      const data = (await res.json()) as { xpAwarded: number; newBadges: BadgeDTO[]; progress: ProgressDTO };
      dispatch({ type: "progress", progress: data.progress });
      if (data.xpAwarded > 0) {
        haptic([10, 20, 10, 20, 30]);
        dispatch({ type: "toast", toast: { text: `Quiz complete · +${data.xpAwarded} XP`, badges: data.newBadges } });
      }
    } catch {
      /* ignore */
    }
  }, []);

  const value = useMemo<Ctx>(
    () => ({
      ...state,
      setTab: (tab) => {
        haptic(6);
        dispatch({ type: "tab", tab });
        dispatch({ type: "active", id: null });
      },
      setLang: (lang) => dispatch({ type: "lang", lang }),
      toggleDark: () => {
        haptic(6);
        dispatch({ type: "dark", dark: !state.dark });
      },
      generate,
      submitQuiz,
      openSession: (id) => dispatch({ type: "active", id }),
      refresh,
      dismissToast: () => dispatch({ type: "toast", toast: null }),
      unlockCamera: () => {
        saveJSON(UNLOCK_KEY, true);
        dispatch({ type: "unlock" });
      },
      unlockDialect: () => {
        saveJSON(DIALECT_KEY, true);
        dispatch({ type: "unlockDialect" });
      },
      setDraftInput: (v) => dispatch({ type: "draft", draftInput: v }),
    }),
    [state, generate, submitQuiz, refresh],
  );

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
}

export function useStore(): Ctx {
  const ctx = useContext(StoreContext);
  if (!ctx) throw new Error("useStore must be used inside StoreProvider");
  return ctx;
}
