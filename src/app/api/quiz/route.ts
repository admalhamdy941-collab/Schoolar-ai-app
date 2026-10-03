import { NextResponse } from "next/server";
import { db } from "@/db";
import { studySessions } from "@/db/schema";
import { and, eq } from "drizzle-orm";
import { getOrCreateStudent, getProgress, recordActivity, XP_PER_QUIZ_CORRECT, XP_PERFECT_QUIZ_BONUS } from "@/lib/gamification";

export const dynamic = "force-dynamic";

/** Called when a student finishes the micro-quiz attached to a session. */
export async function POST(req: Request) {
  try {
    const { sessionId, correct, total } = (await req.json()) as { sessionId: number; correct: number; total: number };
    const student = await getOrCreateStudent();
    const [session] = await db
      .select()
      .from(studySessions)
      .where(and(eq(studySessions.id, Number(sessionId)), eq(studySessions.studentId, student.id)));
    if (!session) return NextResponse.json({ error: "Session not found" }, { status: 404 });
    if (session.quizScore !== null) {
      return NextResponse.json({ xpAwarded: 0, newBadges: [], progress: await getProgress(student.id), alreadyScored: true });
    }
    const safeCorrect = Math.max(0, Math.min(Number(correct) || 0, Number(total) || 0));
    const perfect = total > 0 && safeCorrect === total;
    const xp = safeCorrect * XP_PER_QUIZ_CORRECT + (perfect ? XP_PERFECT_QUIZ_BONUS : 0);
    await db.update(studySessions).set({ quizScore: safeCorrect }).where(eq(studySessions.id, session.id));
    const { newBadges } = await recordActivity(student.id, { xp, perfectQuiz: perfect });
    return NextResponse.json({ xpAwarded: xp, newBadges, progress: await getProgress(student.id) });
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : "Failed" }, { status: 500 });
  }
}
