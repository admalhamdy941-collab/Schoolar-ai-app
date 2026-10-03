import {
  pgTable,
  serial,
  text,
  integer,
  timestamp,
  jsonb,
  date,
  uniqueIndex,
} from "drizzle-orm/pg-core";

/**
 * Students are identified by an anonymous device id stored in a cookie.
 * This keeps onboarding frictionless (no sign-up) while still persisting
 * XP, streaks and study history server-side.
 */
export const students = pgTable("students", {
  id: serial("id").primaryKey(),
  deviceId: text("device_id").notNull().unique(),
  displayName: text("display_name").notNull().default("Student"),
  xp: integer("xp").notNull().default(0),
  level: integer("level").notNull().default(1),
  currentStreak: integer("current_streak").notNull().default(0),
  longestStreak: integer("longest_streak").notNull().default(0),
  lastStudyDate: date("last_study_date"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

/** Every AI generation is stored so it can be re-opened and synced for offline use. */
export const studySessions = pgTable("study_sessions", {
  id: serial("id").primaryKey(),
  studentId: integer("student_id")
    .notNull()
    .references(() => students.id, { onDelete: "cascade" }),
  module: text("module").notNull(), // text | solver | summary | grammar
  language: text("language").notNull().default("en"),
  title: text("title").notNull(),
  inputText: text("input_text").notNull(),
  result: jsonb("result").notNull(),
  xpAwarded: integer("xp_awarded").notNull().default(0),
  quizScore: integer("quiz_score"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

/** Badges unlocked by the gamification engine. */
export const badges = pgTable(
  "badges",
  {
    id: serial("id").primaryKey(),
    studentId: integer("student_id")
      .notNull()
      .references(() => students.id, { onDelete: "cascade" }),
    code: text("code").notNull(),
    name: text("name").notNull(),
    emoji: text("emoji").notNull(),
    description: text("description").notNull(),
    unlockedAt: timestamp("unlocked_at").notNull().defaultNow(),
  },
  (t) => [uniqueIndex("badges_student_code_idx").on(t.studentId, t.code)],
);

/** Per-day activity log used for the streak heat-map on the dashboard. */
export const dailyActivity = pgTable(
  "daily_activity",
  {
    id: serial("id").primaryKey(),
    studentId: integer("student_id")
      .notNull()
      .references(() => students.id, { onDelete: "cascade" }),
    day: date("day").notNull(),
    sessions: integer("sessions").notNull().default(0),
    xp: integer("xp").notNull().default(0),
  },
  (t) => [uniqueIndex("daily_activity_student_day_idx").on(t.studentId, t.day)],
);

/** Shareable peer-quiz challenges (viral loop #3). */
export const challenges = pgTable("challenges", {
  id: serial("id").primaryKey(),
  code: text("code").notNull().unique(),
  studentId: integer("student_id")
    .notNull()
    .references(() => students.id, { onDelete: "cascade" }),
  sessionId: integer("session_id").references(() => studySessions.id, { onDelete: "set null" }),
  title: text("title").notNull(),
  quiz: jsonb("quiz").notNull(),
  language: text("language").notNull().default("en"),
  plays: integer("plays").notNull().default(0),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export const challengePlays = pgTable("challenge_plays", {
  id: serial("id").primaryKey(),
  challengeId: integer("challenge_id")
    .notNull()
    .references(() => challenges.id, { onDelete: "cascade" }),
  nickname: text("nickname").notNull(),
  score: integer("score").notNull(),
  total: integer("total").notNull(),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export type Student = typeof students.$inferSelect;
export type StudySession = typeof studySessions.$inferSelect;
export type Badge = typeof badges.$inferSelect;
