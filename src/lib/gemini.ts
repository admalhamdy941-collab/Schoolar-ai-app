import { buildSystemPrompt, buildUserPrompt } from "./prompts";
import type { AIResult, GenerateRequest } from "./types";
import { demoResult } from "./demo";

/**
 * Gemini API handler.
 * - Uses the REST `generateContent` endpoint (no SDK dependency).
 * - Forces `application/json` response MIME type for reliable parsing.
 * - Supports multimodal input (inline base64 images) for OCR homework solving.
 * - Falls back to a rich demo payload when GEMINI_API_KEY is not configured
 *   so the UI remains fully explorable.
 *
 * NOTE: gemini-1.5-flash has been retired by Google; the default is the
 * current fast/free-tier model. Override with GEMINI_MODEL in .env.
 */
const DEFAULT_MODEL = "gemini-2.0-flash";

export class GeminiError extends Error {
  constructor(message: string, public status = 502) {
    super(message);
  }
}

export async function generateWithGemini(
  req: GenerateRequest,
): Promise<{ result: AIResult; source: "gemini" | "demo" }> {
  const apiKey = process.env.GEMINI_API_KEY ?? process.env.GOOGLE_API_KEY;
  if (!apiKey) {
    return { result: demoResult(req), source: "demo" };
  }

  const model = process.env.GEMINI_MODEL ?? DEFAULT_MODEL;
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const parts: Record<string, unknown>[] = [
    { text: buildUserPrompt(req.module, req.input, Boolean(req.image)) },
  ];
  if (req.image) {
    parts.push({ inline_data: { mime_type: req.image.mimeType, data: req.image.data } });
  }

  const body = {
    system_instruction: {
      parts: [{ text: buildSystemPrompt(req.module, req.lang, req.options?.targetLanguage) }],
    },
    contents: [{ role: "user", parts }],
    generationConfig: {
      temperature: 0.4,
      topP: 0.95,
      maxOutputTokens: 8192,
      response_mime_type: "application/json",
    },
    safetySettings: [
      { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_ONLY_HIGH" },
      { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_ONLY_HIGH" },
      { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_ONLY_HIGH" },
    ],
  };

  let lastError: unknown;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 60_000);
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
      clearTimeout(timer);

      if (!res.ok) {
        const errText = await res.text();
        // 429 / 5xx are retryable; 4xx are not.
        if (res.status === 429 || res.status >= 500) throw new GeminiError(`Gemini ${res.status}: ${errText.slice(0, 300)}`, 502);
        throw new GeminiError(`Gemini rejected the request (${res.status}): ${errText.slice(0, 300)}`, 400);
      }

      const json = (await res.json()) as {
        candidates?: { content?: { parts?: { text?: string }[] }; finishReason?: string }[];
        promptFeedback?: { blockReason?: string };
      };
      if (json.promptFeedback?.blockReason) {
        throw new GeminiError(`Request blocked by safety filter: ${json.promptFeedback.blockReason}`, 400);
      }
      const text = json.candidates?.[0]?.content?.parts?.map((p) => p.text ?? "").join("") ?? "";
      const parsed = extractJSON(text);
      return { result: normalise(parsed, req) , source: "gemini" };
    } catch (err) {
      lastError = err;
      if (err instanceof GeminiError && err.status === 400) break;
    }
  }
  throw lastError instanceof Error ? lastError : new GeminiError("Unknown Gemini failure");
}

/** Robustly pull a JSON object out of model text (handles stray fences / prose). */
export function extractJSON(text: string): Record<string, unknown> {
  const cleaned = text.replace(/```(?:json)?/gi, "").trim();
  try {
    return JSON.parse(cleaned);
  } catch {
    const start = cleaned.indexOf("{");
    const end = cleaned.lastIndexOf("}");
    if (start === -1 || end === -1) throw new GeminiError("Model returned non-JSON output");
    return JSON.parse(cleaned.slice(start, end + 1));
  }
}

/** Guarantee required arrays exist so the UI never crashes on partial output. */
function normalise(raw: Record<string, unknown>, req: GenerateRequest): AIResult {
  const r = raw as unknown as AIResult & Record<string, unknown>;
  const recall = (r.recall ?? { quiz: [], flashcards: [] }) as AIResult["recall"];
  recall.quiz = Array.isArray(recall.quiz) ? recall.quiz.slice(0, 3) : [];
  recall.flashcards = Array.isArray(recall.flashcards) ? recall.flashcards.slice(0, 3) : [];
  const arr = (k: string) => (Array.isArray(r[k]) ? (r[k] as unknown[]) : []);
  const base = { title: String(r.title ?? "Study Result"), recall };
  switch (req.module) {
    case "text":
      return { kind: "text", ...base, coreIdeas: arr("coreIdeas") as string[], subThemes: arr("subThemes") as never, vocabulary: arr("vocabulary") as never, takeaways: arr("takeaways") as string[] };
    case "solver":
      return { kind: "solver", ...base, problemRestatement: String(r.problemRestatement ?? ""), concepts: arr("concepts") as string[], steps: arr("steps") as never, finalAnswer: String(r.finalAnswer ?? ""), commonMistakes: arr("commonMistakes") as string[] };
    case "summary":
      return { kind: "summary", ...base, bullets: arr("bullets") as string[], keyEquations: arr("keyEquations") as never, slideOutline: arr("slideOutline") as never };
    case "grammar":
      return { kind: "grammar", ...base, correctedText: String(r.correctedText ?? ""), issues: arr("issues") as never, sentenceAnalysis: arr("sentenceAnalysis") as never, translation: (r.translation ?? { targetLanguage: "", text: "", notes: "" }) as never };
    case "dialect":
      return { kind: "dialect", ...base, dialectSummary: String(r.dialectSummary ?? ""), everydayExamples: arr("everydayExamples") as never, examTermGlossary: arr("examTermGlossary") as never, quickSteps: arr("quickSteps") as string[] };
  }
}
