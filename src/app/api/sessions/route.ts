import { NextResponse } from "next/server";
import { db } from "@/db";
import { studySessions } from "@/db/schema";
import { desc, eq } from "drizzle-orm";
import { getOrCreateStudent } from "@/lib/gamification";

export const dynamic = "force-dynamic";

/** Recent sessions — the client mirrors these into local storage for offline study. */
export async function GET() {
  try {
    const student = await getOrCreateStudent();
    const rows = await db
      .select()
      .from(studySessions)
      .where(eq(studySessions.studentId, student.id))
      .orderBy(desc(studySessions.createdAt))
      .limit(40);
    return NextResponse.json(rows.map((r) => ({ ...r, createdAt: r.createdAt.toISOString() })));
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : "Failed" }, { status: 500 });
  }
}
