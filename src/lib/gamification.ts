import { db } from "@/db";
import { badges, dailyActivity, students, studySessions } from "@/db/schema";
import { and, desc, eq, gte, sql } from "drizzle-orm";
import { cookies } from "next/headers";
import type { BadgeDTO, ModuleKey, ProgressDTO } from "./types";

export const XP_PER_MODULE: Record<ModuleKey, number> = {
  text: 25,
  solver: 30,
  summary: 25,
  grammar: 20,
  dialect: 25,
};
export const XP_PER_QUIZ_CORRECT = 10;
export const XP_PERFECT_QUIZ_BONUS = 15;

/** Level curve: level n requires 100 * n * (n+1) / 2 cumulative XP (triangular). */
export function levelFromXp(xp: number): { level: number; xpIntoLevel: number; xpForNextLevel: number } {
  let level = 1;
  let remaining = xp;
  while (remaining >= 100 * level) {
    remaining -= 100 * level;
    level++;
  }
  return { level, xpIntoLevel: remaining, xpForNextLevel: 100 * level };
}

const BADGE_CATALOG: Record<string, Omit<BadgeDTO, "unlockedAt">> = {
  first_session: { code: "first_session", name: "First Spark", emoji: "✨", description: "Completed your first study session." },
  text_scholar: { code: "text_scholar", name: "Text Scholar", emoji: "📚", description: "Prepared 5 texts for class." },
  math_ninja: { code: "math_ninja", name: "Math Ninja", emoji: "🥷", description: "Solved 5 problems step by step." },
  summary_sage: { code: "summary_sage", name: "Summary Sage", emoji: "🧠", description: "Summarised 5 lessons." },
  word_smith: { code: "word_smith", name: "Wordsmith", emoji: "✒️", description: "Completed 5 grammar analyses." },
  dialect_fluent: { code: "dialect_fluent", name: "Darija Fluent", emoji: "🗣️", description: "Explained 3 lessons in dialect." },
  streak_3: { code: "streak_3", name: "On Fire", emoji: "🔥", description: "3-day study streak." },
  streak_7: { code: "streak_7", name: "Week Warrior", emoji: "🗓️", description: "7-day study streak." },
  streak_30: { code: "streak_30", name: "Iron Discipline", emoji: "🛡️", description: "30-day study streak." },
  level_5: { code: "level_5", name: "Rising Star", emoji: "⭐", description: "Reached level 5." },
  level_10: { code: "level_10", name: "Honour Roll", emoji: "🏆", description: "Reached level 10." },
  perfect_quiz: { code: "perfect_quiz", name: "Sharp Mind", emoji: "🎯", description: "Scored 3/3 on a micro-quiz." },
  polyglot: { code: "polyglot", name: "Polyglot", emoji: "🌍", description: "Studied in both Arabic and English." },
};

const COOKIE = "scholar_device_id";

function todayISO(): string {
  return new Date().toISOString().slice(0, 10);
}
function daysBetween(a: string, b: string): number {
  return Math.round((new Date(b).getTime() - new Date(a).getTime()) / 86_400_000);
}

/** Get-or-create the anonymous student bound to this browser. */
export async function getOrCreateStudent() {
  const jar = await cookies();
  let deviceId = jar.get(COOKIE)?.value;
  if (!deviceId) {
    deviceId = crypto.randomUUID();
    jar.set(COOKIE, deviceId, { httpOnly: true, sameSite: "lax", maxAge: 60 * 60 * 24 * 365 * 2, path: "/" });
  }
  const existing = await db.select().from(students).where(eq(students.deviceId, deviceId)).limit(1);
  if (existing[0]) return existing[0];
  const inserted = await db.insert(students).values({ deviceId }).returning();
  return inserted[0];
}

/**
 * Record a completed study action: updates XP, level, streak, daily activity
 * and evaluates badge unlocks. Returns the awarded XP and any new badges.
 */
export async function recordActivity(
  studentId: number,
  opts: { xp: number; module?: ModuleKey; lang?: string; perfectQuiz?: boolean; countsAsSession?: boolean },
): Promise<{ newBadges: BadgeDTO[] }> {
  const [s] = await db.select().from(students).where(eq(students.id, studentId));
  const today = todayISO();

  // --- Streak logic ---
  let streak = s.currentStreak;
  if (!s.lastStudyDate) streak = 1;
  else {
    const gap = daysBetween(s.lastStudyDate, today);
    if (gap === 1) streak += 1;
    else if (gap > 1) streak = 1;
    // gap === 0 → same day, streak unchanged
  }
  const longest = Math.max(s.longestStreak, streak);
  const xp = s.xp + opts.xp;
  const { level } = levelFromXp(xp);

  await db
    .update(students)
    .set({ xp, level, currentStreak: streak, longestStreak: longest, lastStudyDate: today })
    .where(eq(students.id, studentId));

  await db
    .insert(dailyActivity)
    .values({ studentId, day: today, sessions: opts.countsAsSession ? 1 : 0, xp: opts.xp })
    .onConflictDoUpdate({
      target: [dailyActivity.studentId, dailyActivity.day],
      set: {
        sessions: sql`${dailyActivity.sessions} + ${opts.countsAsSession ? 1 : 0}`,
        xp: sql`${dailyActivity.xp} + ${opts.xp}`,
      },
    });

  // --- Badge evaluation ---
  const counts = await moduleCounts(studentId);
  const total = Object.values(counts).reduce((a, b) => a + b, 0);
  const langs = await db
    .selectDistinct({ language: studySessions.language })
    .from(studySessions)
    .where(eq(studySessions.studentId, studentId));

  const candidates: string[] = [];
  if (total >= 1) candidates.push("first_session");
  if (counts.text >= 5) candidates.push("text_scholar");
  if (counts.solver >= 5) candidates.push("math_ninja");
  if (counts.summary >= 5) candidates.push("summary_sage");
  if (counts.grammar >= 5) candidates.push("word_smith");
  if (counts.dialect >= 3) candidates.push("dialect_fluent");
  if (streak >= 3) candidates.push("streak_3");
  if (streak >= 7) candidates.push("streak_7");
  if (streak >= 30) candidates.push("streak_30");
  if (level >= 5) candidates.push("level_5");
  if (level >= 10) candidates.push("level_10");
  if (opts.perfectQuiz) candidates.push("perfect_quiz");
  if (langs.length >= 2) candidates.push("polyglot");

  const newBadges: BadgeDTO[] = [];
  for (const code of candidates) {
    const meta = BADGE_CATALOG[code];
    const inserted = await db
      .insert(badges)
      .values({ studentId, ...meta })
      .onConflictDoNothing()
      .returning();
    if (inserted[0]) newBadges.push({ ...meta, unlockedAt: inserted[0].unlockedAt.toISOString() });
  }
  return { newBadges };
}

async function moduleCounts(studentId: number): Promise<Record<ModuleKey, number>> {
  const rows = await db
    .select({ module: studySessions.module, c: sql<number>`count(*)::int` })
    .from(studySessions)
    .where(eq(studySessions.studentId, studentId))
    .groupBy(studySessions.module);
  const out: Record<ModuleKey, number> = { text: 0, solver: 0, summary: 0, grammar: 0, dialect: 0 };
  for (const r of rows) out[r.module as ModuleKey] = r.c;
  return out;
}

export async function getProgress(studentId: number): Promise<ProgressDTO> {
  const [s] = await db.select().from(students).where(eq(students.id, studentId));
  const counts = await moduleCounts(studentId);
  const badgeRows = await db.select().from(badges).where(eq(badges.studentId, studentId)).orderBy(desc(badges.unlockedAt));
  const since = new Date(Date.now() - 13 * 86_400_000).toISOString().slice(0, 10);
  const activity = await db
    .select()
    .from(dailyActivity)
    .where(and(eq(dailyActivity.studentId, studentId), gte(dailyActivity.day, since)));
  const byDay = new Map(activity.map((a) => [a.day, a]));
  const last14Days = Array.from({ length: 14 }, (_, i) => {
    const day = new Date(Date.now() - (13 - i) * 86_400_000).toISOString().slice(0, 10);
    const a = byDay.get(day);
    return { day, sessions: a?.sessions ?? 0, xp: a?.xp ?? 0 };
  });

  // A streak is "live" only if the last study day is today or yesterday.
  const today = todayISO();
  const gap = s.lastStudyDate ? daysBetween(s.lastStudyDate, today) : Infinity;
  const currentStreak = gap <= 1 ? s.currentStreak : 0;

  return {
    displayName: s.displayName,
    xp: s.xp,
    ...levelFromXp(s.xp),
    currentStreak,
    longestStreak: s.longestStreak,
    studiedToday: gap === 0,
    totalSessions: Object.values(counts).reduce((a, b) => a + b, 0),
    moduleCounts: counts,
    badges: badgeRows.map((b) => ({ code: b.code, name: b.name, emoji: b.emoji, description: b.description, unlockedAt: b.unlockedAt.toISOString() })),
    last14Days,
  };
}
