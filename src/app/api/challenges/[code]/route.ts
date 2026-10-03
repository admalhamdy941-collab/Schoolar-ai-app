import { NextResponse } from "next/server";
import { db } from "@/db";
import { challengePlays, challenges } from "@/db/schema";
import { desc, eq, sql } from "drizzle-orm";
import type { QuizQuestion } from "@/lib/types";

export const dynamic = "force-dynamic";

type Ctx = { params: Promise<{ code: string }> };

export async function GET(_req: Request, ctx: Ctx) {
  const { code } = await ctx.params;
  const [row] = await db.select().from(challenges).where(eq(challenges.code, code.toUpperCase()));
  if (!row) return NextResponse.json({ error: "Challenge not found" }, { status: 404 });
  const quiz = (row.quiz as QuizQuestion[]).map(({ question, options }) => ({ question, options }));
  const leaderboard = await db
    .select({ nickname: challengePlays.nickname, score: challengePlays.score, total: challengePlays.total, createdAt: challengePlays.createdAt })
    .from(challengePlays)
    .where(eq(challengePlays.challengeId, row.id))
    .orderBy(desc(challengePlays.score), desc(challengePlays.createdAt))
    .limit(10);
  return NextResponse.json({
    code: row.code,
    title: row.title,
    language: row.language,
    plays: row.plays,
    quiz,
    total: quiz.length,
    leaderboard: leaderboard.map((p) => ({ ...p, createdAt: p.createdAt.toISOString() })),
  });
}

export async function POST(req: Request, ctx: Ctx) {
  const { code } = await ctx.params;
  const body = (await req.json()) as { answers: number[]; nickname?: string };
  const [row] = await db.select().from(challenges).where(eq(challenges.code, code.toUpperCase()));
  if (!row) return NextResponse.json({ error: "Challenge not found" }, { status: 404 });
  const quiz = row.quiz as QuizQuestion[];
  const answers = Array.isArray(body.answers) ? body.answers : [];
  const correct = quiz.reduce((n, q, i) => n + (answers[i] === q.answerIndex ? 1 : 0), 0);
  const nickname = (body.nickname ?? "Challenger").toString().slice(0, 24) || "Challenger";
  await db.insert(challengePlays).values({ challengeId: row.id, nickname, score: correct, total: quiz.length });
  await db.update(challenges).set({ plays: sql`${challenges.plays} + 1` }).where(eq(challenges.id, row.id));
  return NextResponse.json({
    score: correct,
    total: quiz.length,
    explanations: quiz.map((q, i) => ({
      correct: answers[i] === q.answerIndex,
      answerIndex: q.answerIndex,
      explanation: q.explanation,
    })),
  });
}
