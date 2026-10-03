export type ModuleKey = "text" | "solver" | "summary" | "grammar" | "dialect";
export type Lang = "en" | "ar" | "fr";

export interface QuizQuestion {
  question: string;
  options: string[];
  answerIndex: number;
  explanation: string;
}

export interface Flashcard {
  front: string;
  back: string;
}

/** Appended to every response: Byte-Sized Micro-Quiz + Anki-style flashcards. */
export interface ActiveRecall {
  quiz: QuizQuestion[];
  flashcards: Flashcard[];
}

export interface SolutionStep {
  title: string;
  content: string;
  why?: string; // "Why this formula?" tooltip
}

export interface TextPrepResult {
  kind: "text";
  title: string;
  coreIdeas: string[];
  subThemes: { theme: string; explanation: string }[];
  vocabulary: { word: string; definition: string; contextSentence: string }[];
  takeaways: string[];
  recall: ActiveRecall;
}

export interface SolverResult {
  kind: "solver";
  title: string;
  problemRestatement: string;
  concepts: string[];
  steps: SolutionStep[];
  finalAnswer: string;
  commonMistakes: string[];
  recall: ActiveRecall;
}

export interface SummaryResult {
  kind: "summary";
  title: string;
  bullets: string[];
  keyEquations: { name: string; formula: string; meaning: string }[];
  slideOutline: { slideTitle: string; points: string[] }[];
  recall: ActiveRecall;
}

export interface GrammarResult {
  kind: "grammar";
  title: string;
  correctedText: string;
  issues: { original: string; fix: string; rule: string }[];
  sentenceAnalysis: { part: string; role: string; note: string }[];
  translation: { targetLanguage: string; text: string; notes: string };
  recall: ActiveRecall;
}

export interface DialectResult {
  kind: "dialect";
  title: string;
  dialectSummary: string;
  everydayExamples: { example: string; linkToConcept: string }[];
  examTermGlossary: { dialectTerm: string; formalTerm: string; meaning: string }[];
  quickSteps: string[];
  recall: ActiveRecall;
}

export type AIResult = TextPrepResult | SolverResult | SummaryResult | GrammarResult | DialectResult;

export interface GenerateRequest {
  module: ModuleKey;
  lang: Lang;
  input: string;
  image?: { mimeType: string; data: string } | null;
  options?: { targetLanguage?: string };
}

export interface GenerateResponse {
  sessionId: number;
  result: AIResult;
  xpAwarded: number;
  newBadges: BadgeDTO[];
  progress: ProgressDTO;
  source: "gemini" | "demo";
}

export interface BadgeDTO {
  code: string;
  name: string;
  emoji: string;
  description: string;
  unlockedAt?: string;
}

export interface ProgressDTO {
  displayName: string;
  xp: number;
  level: number;
  xpIntoLevel: number;
  xpForNextLevel: number;
  currentStreak: number;
  longestStreak: number;
  studiedToday: boolean;
  totalSessions: number;
  moduleCounts: Record<ModuleKey, number>;
  badges: BadgeDTO[];
  last14Days: { day: string; sessions: number; xp: number }[];
}

export interface SessionDTO {
  id: number;
  module: ModuleKey;
  language: Lang;
  title: string;
  inputText: string;
  result: AIResult;
  xpAwarded: number;
  quizScore: number | null;
  createdAt: string;
}
