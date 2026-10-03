"use client";

import { useStore } from "@/lib/store";
import { MODULE_META, t } from "@/lib/i18n";
import type { ModuleKey } from "@/lib/types";
import { ViralHub } from "./ViralHub";

const MODULES: ModuleKey[] = ["text", "solver", "summary", "grammar", "dialect"];

export function Dashboard() {
  const { lang, progress, sessions, setTab, openSession, online } = useStore();
  const s = t(lang);
  const p = progress;
  const pct = p ? Math.max(2, Math.round((p.xpIntoLevel / p.xpForNextLevel) * 100)) : 2;
  const recent = sessions.slice(0, 4);

  return (
    <div className="space-y-6">
      {!online && <p className="rounded-2xl border border-amber-400/30 bg-amber-500/10 p-3 text-sm text-amber-300">📴 {s.offline}</p>}

      {/* ───── Hero header ───── */}
      <section className="animate-rise relative overflow-hidden rounded-[28px] border border-white/10 bg-gradient-to-br from-[#1e1b4b] via-[#312e81] to-[#1e293b] p-5 shadow-[0_20px_60px_rgba(0,0,0,0.5),0_0_40px_rgba(129,140,248,0.2)]">
        <div className="pointer-events-none absolute -end-10 -top-10 h-40 w-40 rounded-full bg-indigo-400/20 blur-2xl" />
        <div className="flex items-center gap-4">
          {/* Avatar + level ring */}
          <div className="relative grid h-16 w-16 shrink-0 place-items-center">
            <svg className="absolute inset-0 -rotate-90" viewBox="0 0 64 64">
              <circle cx="32" cy="32" r="28" stroke="rgba(255,255,255,0.12)" strokeWidth="4" fill="none" />
              <circle cx="32" cy="32" r="28" stroke="#818cf8" strokeWidth="4" fill="none" strokeLinecap="round" strokeDasharray={`${(pct / 100) * 176} 176`} className="transition-all duration-1000" />
            </svg>
            <div className="grid h-12 w-12 place-items-center rounded-full bg-gradient-to-br from-indigo-400 to-fuchsia-400 text-2xl shadow-lg shadow-indigo-500/50">🎓</div>
            <span className="absolute -bottom-1 -end-1 rounded-full border border-indigo-400 bg-[#0f172a] px-2 text-[11px] font-black text-indigo-300">{p?.level ?? 1}</span>
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-xs text-slate-400">
              {s.hello}, {s.student} 👋
            </p>
            <h1 className="text-xl font-black leading-tight">
              {s.level} {p?.level ?? 1} {s.rank}
            </h1>
            <p className="text-xs font-bold text-indigo-300">
              {p?.xpIntoLevel ?? 0} / {p?.xpForNextLevel ?? 100} {s.xp}
            </p>
          </div>
          {/* Glowing streak */}
          <div className="flex flex-col items-center rounded-2xl bg-gradient-to-b from-orange-500 to-red-500 px-4 py-2 shadow-[0_0_30px_rgba(251,146,60,0.55)]">
            <span className="animate-flame text-2xl">🔥</span>
            <span className="text-xs font-black">
              {p?.currentStreak ?? 0} {s.days}
            </span>
          </div>
        </div>
        {/* XP bar */}
        <div className="relative mt-4 h-3 overflow-hidden rounded-full bg-white/10">
          <div className="h-full rounded-full bg-gradient-to-r from-indigo-400 via-violet-400 to-cyan-400 shadow-[0_0_16px_rgba(129,140,248,0.8)] transition-all duration-1000" style={{ width: `${pct}%` }} />
          <div className="animate-xpshine absolute inset-y-0 w-1/4 bg-gradient-to-r from-transparent via-white/40 to-transparent" />
        </div>
        <div className="mt-2 flex items-center justify-between text-xs text-slate-400">
          <span>{p?.studiedToday ? `✅ ${s.today}` : `⚡ ${s.notToday}`}</span>
          <span>
            {s.best}: {p?.longestStreak ?? 0}
          </span>
        </div>
      </section>

      {/* ───── Quick start grid ───── */}
      <section>
        <SectionTitle>{s.quickStart}</SectionTitle>
        <div className="grid grid-cols-2 gap-3.5 sm:grid-cols-3">
          {MODULES.map((m, i) => {
            const meta = MODULE_META[m];
            return (
              <button
                key={m}
                type="button"
                onClick={() => setTab(m)}
                style={{ animationDelay: `${i * 90}ms` }}
                className={`glow-card animate-pop group aspect-[0.98] bg-gradient-to-br ${meta.accent} p-4 text-start shadow-xl ${meta.glow} hover:-translate-y-1 hover:shadow-2xl active:scale-[0.96]`}
              >
                <div className="relative flex h-full flex-col">
                  <div className="flex items-start justify-between">
                    <span className="grid h-11 w-11 place-items-center rounded-2xl border border-white/30 bg-white/20 text-2xl backdrop-blur">{meta.emoji}</span>
                    <span className="rounded-full bg-black/25 px-2 py-0.5 text-[10px] font-bold">
                      {p?.moduleCounts[m] ?? 0} {s.sessions}
                    </span>
                  </div>
                  <div className="mt-auto">
                    <p className="text-base font-black leading-tight">{s[m]}</p>
                    <p className="mt-1 line-clamp-2 text-[11px] text-white/80">{s.moduleDesc[m]}</p>
                  </div>
                  <span className="mt-3 text-sm font-bold opacity-80 transition group-hover:translate-x-1 rtl:group-hover:-translate-x-1">→</span>
                </div>
              </button>
            );
          })}
        </div>
      </section>

      {/* ───── Stats ───── */}
      <section className="neu grid grid-cols-3 divide-x divide-white/10 p-4 rtl:divide-x-reverse">
        <Stat label={s.sessions} value={p?.totalSessions ?? 0} color="text-indigo-300" glow="rgba(129,140,248,0.7)" />
        <Stat label={s.best} value={p?.longestStreak ?? 0} color="text-orange-300" glow="rgba(251,146,60,0.7)" />
        <Stat label={s.totalXp} value={p?.xp ?? 0} color="text-emerald-300" glow="rgba(52,211,153,0.7)" />
      </section>

      {/* ───── Heatmap ───── */}
      <section className="neu p-4">
        <p className="mb-2 text-xs font-bold uppercase tracking-widest text-slate-400">{s.last14}</p>
        <div className="grid grid-cols-14 gap-1.5" dir="ltr">
          {(p?.last14Days ?? Array.from({ length: 14 }, (_, i) => ({ day: String(i), sessions: 0, xp: 0 }))).map((d) => {
            const lvl = d.sessions === 0 ? 0 : d.sessions < 2 ? 1 : d.sessions < 4 ? 2 : 3;
            const cls = ["bg-white/5", "bg-emerald-700 shadow-[0_0_8px_rgba(52,211,153,0.4)]", "bg-emerald-500 shadow-[0_0_10px_rgba(52,211,153,0.6)]", "bg-emerald-300 shadow-[0_0_14px_rgba(52,211,153,0.9)]"][lvl];
            return <span key={d.day} title={`${d.day}: ${d.sessions} · ${d.xp} XP`} className={`aspect-square rounded-md ${cls}`} />;
          })}
        </div>
      </section>

      {/* ───── Badges ───── */}
      <section>
        <SectionTitle>{s.badges}</SectionTitle>
        {p && p.badges.length > 0 ? (
          <div className="flex flex-wrap gap-2.5">
            {p.badges.map((b) => (
              <div key={b.code} title={b.description} className="flex items-center gap-2 rounded-full border border-indigo-400/40 bg-[var(--surface)] py-1 pe-3.5 ps-1 text-sm shadow-[0_0_18px_rgba(129,140,248,0.25)]">
                <span className="grid h-8 w-8 place-items-center rounded-full bg-gradient-to-br from-amber-200 to-amber-500 text-base">{b.emoji}</span>
                <span className="font-extrabold">{b.name}</span>
              </div>
            ))}
          </div>
        ) : (
          <p className="neu flex items-center gap-3 p-4 text-sm text-slate-400">
            <span className="text-2xl">🔒</span> {s.noBadges}
          </p>
        )}
      </section>

      <ViralHub />

      {/* ───── Recent ───── */}
      <section>
        <SectionTitle>{s.recent}</SectionTitle>
        {recent.length === 0 ? (
          <p className="neu p-4 text-sm text-slate-400">{s.noLibrary}</p>
        ) : (
          <ul className="space-y-2.5">
            {recent.map((h) => {
              const meta = MODULE_META[h.module];
              return (
                <li key={h.id}>
                  <button
                    type="button"
                    onClick={() => {
                      setTab(h.module);
                      openSession(h.id);
                    }}
                    className="neu flex w-full items-center gap-3 p-3.5 text-start transition hover:border-white/20 active:scale-[0.99]"
                  >
                    <span className={`grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-gradient-to-br ${meta.accent} text-xl shadow-lg ${meta.glow}`}>{meta.emoji}</span>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate font-extrabold">{h.title}</span>
                      <span className="block text-xs text-slate-400">
                        {new Date(h.createdAt).toLocaleDateString()} · +{h.xpAwarded} XP
                      </span>
                    </span>
                    <span className="text-slate-500">›</span>
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </div>
  );
}

function SectionTitle({ children }: { children: React.ReactNode }) {
  return (
    <h2 className="mb-3 flex items-center gap-2.5 text-base font-black">
      <span className="h-5 w-1 rounded-full bg-gradient-to-b from-indigo-400 to-cyan-400" />
      {children}
    </h2>
  );
}

function Stat({ label, value, color, glow }: { label: string; value: number; color: string; glow: string }) {
  return (
    <div className="px-2 text-center">
      <p className={`text-2xl font-black ${color}`} style={{ textShadow: `0 0 16px ${glow}` }}>
        {value}
      </p>
      <p className="text-[11px] text-slate-400">{label}</p>
    </div>
  );
}
