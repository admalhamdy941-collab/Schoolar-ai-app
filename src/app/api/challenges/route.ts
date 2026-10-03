import { NextResponse } from "next/server";
import { db } from "@/db";
import { challenges, studySessions } from "@/db/schema";
import { and, eq } from "drizzle-orm";
import { getOrCreateStudent } from "@/lib/gamification";
import type { ActiveRecall } from "@/lib/types";

export const dynamic = "force-dynamic";

function shortCode(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let s = "";
  for (let i = 0; i < 6; i++) s += alphabet[Math.floor(Math.random() * alphabet.length)];
  return s;
}

/** Create a shareable peer-quiz challenge from an existing study session. */
export async function POST(req: Request) {
  try {
    const { sessionId } = (await req.json()) as { sessionId: number };
    const student = await getOrCreateStudent();
    const [session] = await db
      .select()
      .from(studySessions)
      .where(and(eq(studySessions.id, Number(sessionId)), eq(studySessions.studentId, student.id)));
    if (!session) return NextResponse.json({ error: "Session not found" }, { status: 404 });
    const recall = (session.result as { recall?: ActiveRecall }).recall;
    if (!recall?.quiz?.length) return NextResponse.json({ error: "This lesson has no quiz to challenge with." }, { status: 400 });

    let code = shortCode();
    for (let i = 0; i < 5; i++) {
      const clash = await db.select({ id: challenges.id }).from(challenges).where(eq(challenges.code, code)).limit(1);
      if (!clash[0]) break;
      code = shortCode();
    }

    const [row] = await db
      .insert(challenges)
      .values({
        code,
        studentId: student.id,
        sessionId: session.id,
        title: session.title,
        quiz: recall.quiz,
        language: session.language,
      })
      .returning();

    return NextResponse.json({ code: row.code, title: row.title, url: `/challenge/${row.code}` });
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : "Failed" }, { status: 500 });
  }
}
