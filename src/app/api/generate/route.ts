import { NextResponse } from "next/server";
import { db } from "@/db";
import { studySessions } from "@/db/schema";
import { generateWithGemini, GeminiError } from "@/lib/gemini";
import { getOrCreateStudent, getProgress, recordActivity, XP_PER_MODULE } from "@/lib/gamification";
import type { GenerateRequest, GenerateResponse, ModuleKey } from "@/lib/types";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

const MODULES: ModuleKey[] = ["text", "solver", "summary", "grammar", "dialect"];

export async function POST(req: Request) {
  let body: GenerateRequest;
  try {
    body = (await req.json()) as GenerateRequest;
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  if (!MODULES.includes(body.module)) return NextResponse.json({ error: "Unknown module" }, { status: 400 });
  const lang = body.lang === "ar" || body.lang === "fr" ? body.lang : "en";
  const input = (body.input ?? "").toString().slice(0, 12_000);
  if (!input.trim() && !body.image) return NextResponse.json({ error: "Please provide text or an image." }, { status: 400 });
  if (body.image && !/^image\/(png|jpe?g|webp|heic|heif)$/i.test(body.image.mimeType)) {
    return NextResponse.json({ error: "Unsupported image type" }, { status: 400 });
  }

  try {
    const student = await getOrCreateStudent();
    const { result, source } = await generateWithGemini({ ...body, lang, input });

    const xp = XP_PER_MODULE[body.module];
    const [session] = await db
      .insert(studySessions)
      .values({
        studentId: student.id,
        module: body.module,
        language: lang,
        title: result.title,
        inputText: input || "[image]",
        result,
        xpAwarded: xp,
      })
      .returning();

    const { newBadges } = await recordActivity(student.id, { xp, module: body.module, lang, countsAsSession: true });
    const progress = await getProgress(student.id);

    const payload: GenerateResponse = { sessionId: session.id, result, xpAwarded: xp, newBadges, progress, source };
    return NextResponse.json(payload);
  } catch (err) {
    const status = err instanceof GeminiError ? err.status : 500;
    const message = err instanceof Error ? err.message : "Generation failed";
    console.error("[generate]", message);
    return NextResponse.json({ error: message }, { status });
  }
}
