import { NextResponse } from "next/server";
import { getOrCreateStudent, getProgress } from "@/lib/gamification";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const student = await getOrCreateStudent();
    return NextResponse.json(await getProgress(student.id));
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : "Failed" }, { status: 500 });
  }
}
