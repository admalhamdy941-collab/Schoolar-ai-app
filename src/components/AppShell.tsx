"use client";

import { useState } from "react";
import { StoreProvider, useStore, haptic, type Tab } from "@/lib/store";
import { t, MODULE_META, LANGS } from "@/lib/i18n";
import { Dashboard } from "./Dashboard";
import { ModuleScreen } from "./ModuleScreen";
import { Toast } from "./ui";

export function AppShell({ demoMode }: { demoMode: boolean }) {
  return (
    <StoreProvider>
      <Shell demoMode={demoMode} />
    </StoreProvider>
  );
}

const TABS: { key: Tab; emoji: string }[] = [
  { key: "home", emoji: "🏠" },
  { key: "text", emoji: MODULE_META.text.emoji },
  { key: "solver", emoji: MODULE_META.solver.emoji },
  { key: "summary", emoji: MODULE_META.summary.emoji },
  { key: "grammar", emoji: MODULE_META.grammar.emoji },
  { key: "dialect", emoji: MODULE_META.dialect.emoji },
];

function Shell({ demoMode }: { demoMode: boolean }) {
  const { tab, setTab, lang, setLang, hydrated, online } = useStore();
  const s = t(lang);
  const [pickerOpen, setPickerOpen] = useState(false);
  const current = LANGS.find((l) => l.code === lang)!;

  if (!hydrated) {
    return (
      <div className="grid min-h-screen place-items-center">
        <span className="animate-flame text-5xl">🎓</span>
      </div>
    );
  }

  const cycleLang = () => {
    haptic(6);
    const i = LANGS.findIndex((l) => l.code === lang);
    setLang(LANGS[(i + 1) % LANGS.length].code);
  };

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-2xl flex-col">
      <Toast />
      {/* ── Glass top bar ── */}
      <header className="sticky top-0 z-30 flex items-center justify-between border-b border-white/5 bg-[#0f172a]/70 px-4 py-3 backdrop-blur-xl">
        <div className="flex items-center gap-2.5">
          <span className="grid h-10 w-10 place-items-center rounded-2xl bg-gradient-to-br from-indigo-400 to-fuchsia-400 text-xl shadow-[0_0_24px_rgba(129,140,248,0.6)]">🎓</span>
          <div>
            <p className="text-base font-black leading-none">{s.appName}</p>
            <p className="mt-0.5 text-[10px] text-slate-400">
              <span className={online ? "text-emerald-400" : "text-rose-400"}>●</span> {s.tagline}
            </p>
          </div>
        </div>
        {/* Language toggle: click cycles, long-press / right-click opens picker */}
        <div className="relative">
          <button
            type="button"
            onClick={cycleLang}
            onContextMenu={(e) => {
              e.preventDefault();
              setPickerOpen((o) => !o);
            }}
            onDoubleClick={() => setPickerOpen(true)}
            title="Click to switch · double-click for list"
            className="flex items-center gap-1.5 rounded-full border border-indigo-400/50 bg-[var(--surface-hi)] px-3 py-2 text-sm font-black text-indigo-300 shadow-[0_0_18px_rgba(129,140,248,0.35)] transition hover:scale-105 active:scale-95"
          >
            <span key={lang} className="animate-pop text-base">
              {current.flag}
            </span>
            {current.short}
            <span className="text-xs opacity-70">⇄</span>
          </button>
          {pickerOpen && (
            <ul className="neu animate-pop absolute end-0 top-12 z-40 w-44 overflow-hidden p-1.5">
              {LANGS.map((l) => (
                <li key={l.code}>
                  <button
                    type="button"
                    onClick={() => {
                      setLang(l.code);
                      setPickerOpen(false);
                      haptic(6);
                    }}
                    className={`flex w-full items-center gap-2 rounded-xl px-3 py-2 text-sm font-bold transition hover:bg-white/5 ${l.code === lang ? "text-indigo-300" : "text-slate-200"}`}
                  >
                    <span className="text-lg">{l.flag}</span> {l.label}
                    {l.code === lang && <span className="ms-auto">✓</span>}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </header>

      {demoMode && <p className="mx-4 mt-3 rounded-2xl border border-indigo-400/30 bg-indigo-500/10 px-3 py-2 text-xs text-indigo-200">ℹ️ {s.demo}</p>}

      <main className="flex-1 px-4 pb-32 pt-4" onClick={() => pickerOpen && setPickerOpen(false)}>
        {tab === "home" ? <Dashboard /> : <ModuleScreen key={`${tab}-${lang}`} module={tab} />}
      </main>

      {/* ── Floating glowing bottom nav ── */}
      <nav className="fixed inset-x-0 bottom-0 z-30 mx-auto w-full max-w-2xl px-3 pb-[max(env(safe-area-inset-bottom),0.75rem)]">
        <ul className="neu grid grid-cols-6 bg-[#0b1222]/90 p-1.5 backdrop-blur-xl">
          {TABS.map(({ key, emoji }) => {
            const active = tab === key;
            const hex = key === "home" ? "#818cf8" : MODULE_META[key].hex;
            return (
              <li key={key}>
                <button type="button" onClick={() => setTab(key)} className="flex w-full flex-col items-center gap-0.5 rounded-2xl py-1.5 text-[10px] font-bold transition active:scale-95" style={active ? { background: `${hex}22`, boxShadow: `0 0 18px ${hex}44 inset` } : undefined}>
                  <span className={`text-xl transition ${active ? "scale-110" : "opacity-70 grayscale"}`}>{emoji}</span>
                  <span className="max-w-full truncate px-1" style={{ color: active ? hex : "#94a3b8" }}>
                    {s[key].split(" ")[0].replace("d'", "")}
                  </span>
                </button>
              </li>
            );
          })}
        </ul>
      </nav>
    </div>
  );
}
