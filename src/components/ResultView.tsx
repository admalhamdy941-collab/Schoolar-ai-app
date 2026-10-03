"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";
import type { DialectResult, GrammarResult, SessionDTO, SolverResult, SummaryResult, TextPrepResult, AIResult } from "@/lib/types";
import { ActiveRecallWidget } from "./ActiveRecall";
import { haptic, useStore } from "@/lib/store";
import { LANGS, MODULE_META, t, type Dict } from "@/lib/i18n";
import { renderStoryPng, shareOrDownload } from "@/lib/storyCard";

/* ──────────────────────────────────────────────────────────────
   AI Output Box: gradient banner → action bar → accordion sections
   → Active Recall. Mirrors flutter/lib/widgets/ai_output_box.dart
   ────────────────────────────────────────────────────────────── */
export function ResultView({ session }: { session: SessionDTO }) {
  const { lang, progress } = useStore();
  const s = t(lang);
  const meta = MODULE_META[session.module];
  const r = session.result;
  const recallRef = useRef<HTMLDivElement>(null);
  const [copied, setCopied] = useState(false);
  const [speaking, setSpeaking] = useState(false);
  const plain = toPlainText(r, s);

  useEffect(() => () => window.speechSynthesis?.cancel(), []);

  const copy = async () => {
    await navigator.clipboard.writeText(plain);
    haptic(12);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };
  const share = async () => {
    haptic(8);
    if (navigator.share) await navigator.share({ title: r.title, text: plain }).catch(() => undefined);
    else await copy();
  };
  const listen = () => {
    haptic(8);
    const synth = window.speechSynthesis;
    if (!synth) return;
    if (speaking) {
      synth.cancel();
      setSpeaking(false);
      return;
    }
    const u = new SpeechSynthesisUtterance(plain);
    u.lang = LANGS.find((l) => l.code === lang)?.tts ?? "en-US";
    u.rate = 0.95;
    u.onend = () => setSpeaking(false);
    setSpeaking(true);
    synth.speak(u);
  };
  const toQuiz = () => {
    haptic(12);
    recallRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  const sections = buildSections(r, s);

  return (
    <article className="space-y-3">
      {/* Banner */}
      <header className={`glow-card animate-rise bg-gradient-to-br ${meta.accent} p-5 shadow-xl ${meta.glow}`}>
        <div className="relative">
          <p className="text-[11px] font-extrabold uppercase tracking-[0.2em] text-white/75">
            {meta.emoji} {s[session.module]} · +{session.xpAwarded} XP
          </p>
          <h2 className="mt-1.5 text-2xl font-black leading-tight">{r.title}</h2>
        </div>
      </header>

      {/* Action bar */}
      <div className="animate-rise flex gap-2" style={{ animationDelay: "80ms" }}>
        <ActionBtn title={s.copy} onClick={copy}>
          {copied ? "✅" : "📋"}
        </ActionBtn>
        <ActionBtn title={s.share} onClick={share}>
          📤
        </ActionBtn>
        <ActionBtn title={speaking ? s.stop : s.listen} onClick={listen} active={speaking}>
          {speaking ? "⏹️" : "🔊"}
        </ActionBtn>
        <button type="button" onClick={toQuiz} className={`flex h-12 flex-1 items-center justify-center gap-2 rounded-2xl border border-white/20 bg-gradient-to-r ${meta.accent} px-4 text-sm font-extrabold text-white shadow-lg ${meta.glow} transition hover:brightness-110 active:scale-95`}>
          🎯 <span className="truncate">{s.takeQuiz}</span>
        </button>
      </div>
      <div className="flex gap-2">
        {r.kind === "dialect" && (
          <button
            type="button"
            className="btn-action flex-1 text-xs"
            onClick={async () => {
              const blob = await renderStoryPng({
                title: r.title,
                bullets: [r.dialectSummary, ...r.quickSteps],
                streak: progress?.currentStreak ?? 0,
                level: progress?.level ?? 1,
                xp: progress?.xp ?? 0,
                kicker: s.storyKicker,
                appName: s.appName,
              });
              await shareOrDownload(blob, "scholar-story.png", s.storyCaption);
            }}
          >
            ⚡ {s.storyExport}
          </button>
        )}
        {(r.kind === "summary" || r.kind === "text") && (
          <button
            type="button"
            className="btn-action flex-1 text-xs"
            onClick={async () => {
              const bullets = r.kind === "summary" ? r.bullets.map((x) => x.replace(/^\s*-+\s*/, "").trim()) : [...r.coreIdeas, ...r.takeaways];
              const blob = await renderStoryPng({
                title: r.title,
                bullets,
                streak: progress?.currentStreak ?? 0,
                level: progress?.level ?? 1,
                xp: progress?.xp ?? 0,
                kicker: s.storyKicker,
                appName: s.appName,
              });
              await shareOrDownload(blob, "scholar-story.png", s.storyCaption);
            }}
          >
            ⚡ {s.storyExport}
          </button>
        )}
        {r.recall.quiz.length > 0 && (
          <button
            type="button"
            className="btn-action flex-1 text-xs"
            onClick={async () => {
              const res = await fetch("/api/challenges", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ sessionId: session.id }) });
              const data = (await res.json()) as { url?: string; error?: string };
              if (!res.ok) return;
              const url = `${window.location.origin}${data.url}`;
              const text = `${s.peerMessage} “${r.title}”! ${url}`;
              if (navigator.share) await navigator.share({ title: s.peerTitle, text, url }).catch(() => navigator.clipboard.writeText(text));
              else await navigator.clipboard.writeText(text);
              haptic([10, 20, 10]);
            }}
          >
            🎮 {s.peerTitle}
          </button>
        )}
      </div>

      {/* Accordion sections */}
      {sections.map((sec, i) => (
        <Accordion key={i} index={i} title={sec.title} icon={sec.icon} hex={meta.hex} defaultOpen={i === 0}>
          {sec.body}
        </Accordion>
      ))}

      <div ref={recallRef} className="scroll-mt-20">
        <ActiveRecallWidget recall={r.recall} sessionId={session.id} savedScore={session.quizScore} />
      </div>
    </article>
  );
}

function ActionBtn({ children, title, onClick, active }: { children: ReactNode; title: string; onClick: () => void; active?: boolean }) {
  return (
    <button type="button" title={title} aria-label={title} onClick={onClick} className={`btn-action w-12 px-0 text-lg ${active ? "border-indigo-400 bg-indigo-500/20 shadow-[0_0_18px_rgba(129,140,248,0.5)]" : ""}`}>
      {children}
    </button>
  );
}

function Accordion({ title, icon, hex, children, defaultOpen, index }: { title: string; icon: string; hex: string; children: ReactNode; defaultOpen: boolean; index: number }) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div className="neu animate-rise overflow-hidden transition" style={{ animationDelay: `${140 + index * 70}ms`, borderColor: open ? `${hex}55` : undefined, boxShadow: open ? `10px 10px 28px rgba(0,0,0,.55), 0 0 24px ${hex}22` : undefined }}>
      <button
        type="button"
        onClick={() => {
          haptic(5);
          setOpen((o) => !o);
        }}
        className="flex w-full items-center gap-3 px-4 py-3.5 text-start"
      >
        <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl text-lg" style={{ background: `${hex}2e` }}>
          {icon}
        </span>
        <span className="flex-1 text-[15px] font-extrabold">{title}</span>
        <span className={`text-slate-400 transition-transform duration-300 ${open ? "rotate-180" : ""}`}>⌄</span>
      </button>
      <div className={`grid transition-[grid-template-rows] duration-300 ease-out ${open ? "grid-rows-[1fr]" : "grid-rows-[0fr]"}`}>
        <div className="overflow-hidden">
          <div className="px-4 pb-4">{children}</div>
        </div>
      </div>
    </div>
  );
}

/* ───────────── Section builders ───────────── */
type Section = { title: string; icon: string; body: ReactNode };

function Bullets({ items, dot }: { items: string[]; dot: string }) {
  return (
    <ul className="space-y-2">
      {items.map((x, i) => {
        const sub = /^\s{2,}-\s*/.test(x);
        return (
          <li key={i} className={`flex gap-2.5 text-sm leading-relaxed ${sub ? "ms-5 text-slate-400" : ""}`}>
            <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full" style={{ background: dot, boxShadow: `0 0 8px ${dot}` }} />
            <span>{x.replace(/^\s*-\s*/, "")}</span>
          </li>
        );
      })}
    </ul>
  );
}
function KV({ k, v, sub, hex, ltr }: { k: string; v: string; sub?: string; hex: string; ltr?: boolean }) {
  return (
    <div className="neu-lo mb-2 p-3" dir={ltr ? "ltr" : undefined}>
      <p className="font-extrabold" style={{ color: hex }}>
        {k}
      </p>
      <p className="text-sm leading-relaxed">{v}</p>
      {sub && <p className="mt-1 text-xs italic text-slate-400">{sub}</p>}
    </div>
  );
}

function buildSections(r: AIResult, s: Dict): Section[] {
  const hex = MODULE_META[r.kind].hex;
  switch (r.kind) {
    case "text":
      return textSections(r, s, hex);
    case "solver":
      return [
        {
          title: s.problem,
          icon: "📌",
          body: (
            <>
              <p className="text-sm leading-relaxed">{r.problemRestatement}</p>
              <div className="mt-3 flex flex-wrap gap-1.5">
                {r.concepts.map((c, i) => (
                  <span key={i} className="pill" style={{ borderColor: `${hex}66`, color: hex, background: `${hex}22` }}>
                    {c}
                  </span>
                ))}
              </div>
            </>
          ),
        },
        { title: s.steps, icon: "🪜", body: <Steps r={r} s={s} hex={hex} /> },
        { title: s.mistakes, icon: "⚠️", body: <Bullets items={r.commonMistakes} dot="#fb7185" /> },
      ];
    case "summary":
      return [
        { title: s.notes, icon: "🗒️", body: <Bullets items={r.bullets} dot={hex} /> },
        { title: s.equations, icon: "∑", body: <>{r.keyEquations.map((e, i) => <KV key={i} k={e.name} v={e.formula} sub={e.meaning} hex={hex} ltr />)}</> },
        { title: s.slides, icon: "🎞️", body: <>{r.slideOutline.map((sl, i) => <KV key={i} k={`${i + 1}. ${sl.slideTitle}`} v={sl.points.map((p) => `• ${p}`).join("\n")} hex={hex} />)}</> },
      ];
    case "grammar":
      return grammarSections(r, s, hex);
    case "dialect":
      return dialectSections(r, s, hex);
  }
}

function textSections(r: TextPrepResult, s: Dict, hex: string): Section[] {
  return [
    { title: s.coreIdeas, icon: "💡", body: <Bullets items={r.coreIdeas} dot={hex} /> },
    { title: s.themes, icon: "🧵", body: <>{r.subThemes.map((x, i) => <KV key={i} k={x.theme} v={x.explanation} hex={hex} />)}</> },
    { title: s.vocab, icon: "🔎", body: <>{r.vocabulary.map((v, i) => <KV key={i} k={v.word} v={v.definition} sub={`“${v.contextSentence}”`} hex={hex} />)}</> },
    { title: s.takeaways, icon: "🌱", body: <Bullets items={r.takeaways} dot={hex} /> },
  ];
}

function grammarSections(r: GrammarResult, s: Dict, hex: string): Section[] {
  return [
    { title: s.corrected, icon: "✅", body: <p className="rounded-2xl border border-emerald-400/40 bg-emerald-500/10 p-3.5 leading-relaxed">{r.correctedText}</p> },
    {
      title: s.issues,
      icon: "🩹",
      body: (
        <div className="space-y-2">
          {r.issues.map((x, i) => (
            <div key={i} className="neu-lo p-3 text-sm">
              <p>
                <span className="rounded bg-rose-500/20 px-1 text-rose-300 line-through">{x.original}</span> → <span className="rounded bg-emerald-500/20 px-1 font-bold text-emerald-300">{x.fix}</span>
              </p>
              <p className="mt-1 text-xs text-slate-400">📐 {x.rule}</p>
            </div>
          ))}
        </div>
      ),
    },
    {
      title: s.analysis,
      icon: "🧩",
      body: (
        <table className="w-full text-sm">
          <tbody>
            {r.sentenceAnalysis.map((p, i) => (
              <tr key={i} className="border-b border-white/5 last:border-0">
                <td className="py-2 pe-3 font-extrabold">{p.part}</td>
                <td className="py-2 pe-3" style={{ color: hex }}>
                  {p.role}
                </td>
                <td className="py-2 text-xs text-slate-400">{p.note}</td>
              </tr>
            ))}
          </tbody>
        </table>
      ),
    },
    {
      title: `${s.translation} → ${r.translation.targetLanguage}`,
      icon: "🌐",
      body: (
        <>
          <p className="text-base leading-relaxed">{r.translation.text}</p>
          {r.translation.notes && <p className="mt-2 text-xs text-slate-400">📝 {r.translation.notes}</p>}
        </>
      ),
    },
  ];
}

/* ───────────── Dialect explainer ───────────── */
function dialectSections(r: DialectResult, s: Dict, hex: string): Section[] {
  return [
    { title: s.dialectSummary, icon: "🗣️", body: <p className="rounded-2xl border p-3.5 leading-relaxed" style={{ borderColor: `${hex}55`, background: `${hex}14` }}>{r.dialectSummary}</p> },
    { title: s.everydayExamples, icon: "🔥", body: <>{r.everydayExamples.map((x, i) => <KV key={i} k={x.example} v={x.linkToConcept} hex={hex} />)}</> },
    { title: s.termGlossary, icon: "🔁", body: <>{r.examTermGlossary.map((x, i) => <KV key={i} k={`${x.dialectTerm} → ${x.formalTerm}`} v={x.meaning} hex={hex} />)}</> },
    { title: s.quickSteps, icon: "✅", body: <Bullets items={r.quickSteps} dot={hex} /> },
  ];
}

/* ───────────── Step-by-step pedagogy ───────────── */
function Steps({ r, s, hex }: { r: SolverResult; s: Dict; hex: string }) {
  const [revealed, setRevealed] = useState(1);
  const [open, setOpen] = useState<Record<number, boolean>>({ 0: true });
  const [why, setWhy] = useState<number | null>(null);
  const all = revealed >= r.steps.length;
  return (
    <>
      <ol className="relative space-y-3 border-s-2 border-dashed border-white/10 ps-5">
        {r.steps.slice(0, revealed).map((st, i) => (
          <li key={i} className="animate-rise relative">
            <span className="absolute -start-[1.7rem] top-2 grid h-5 w-5 place-items-center rounded-full text-[10px] font-black text-white" style={{ background: hex, boxShadow: `0 0 12px ${hex}` }}>
              {i + 1}
            </span>
            <div className="neu-lo overflow-hidden">
              <button
                type="button"
                onClick={() => {
                  haptic(5);
                  setOpen((o) => ({ ...o, [i]: !o[i] }));
                }}
                className="flex w-full items-center justify-between px-3 py-2.5 text-start font-extrabold"
              >
                {st.title}
                <span className={`text-slate-400 transition ${open[i] ? "rotate-180" : ""}`}>⌄</span>
              </button>
              {open[i] && (
                <div className="border-t border-white/5 px-3 py-3">
                  <p className="whitespace-pre-wrap text-sm leading-relaxed">{st.content}</p>
                  {st.why && (
                    <div className="relative mt-2 inline-block">
                      <button
                        type="button"
                        onMouseEnter={() => setWhy(i)}
                        onMouseLeave={() => setWhy((w) => (w === i ? null : w))}
                        onClick={() => {
                          haptic(5);
                          setWhy((w) => (w === i ? null : i));
                        }}
                        className="pill border-amber-400/50 bg-amber-500/15 text-amber-300"
                      >
                        ❓ {s.why}
                      </button>
                      {why === i && <div className="absolute start-0 top-full z-10 mt-1 w-72 max-w-[80vw] rounded-2xl border border-amber-300/40 bg-[var(--surface-hi)] p-3 text-xs leading-relaxed shadow-2xl">{st.why}</div>}
                    </div>
                  )}
                </div>
              )}
            </div>
          </li>
        ))}
      </ol>
      {!all ? (
        <button
          type="button"
          onClick={() => {
            haptic(8);
            setOpen((o) => ({ ...o, [revealed]: true }));
            setRevealed((n) => n + 1);
          }}
          className="mt-4 w-full rounded-2xl border border-white/15 py-3 text-sm font-extrabold text-white shadow-lg transition hover:brightness-110 active:scale-[0.98]"
          style={{ background: `linear-gradient(90deg, ${hex}, ${hex}aa)`, boxShadow: `0 10px 30px ${hex}55` }}
        >
          {s.reveal} {revealed + 1}/{r.steps.length} →
        </button>
      ) : (
        <div className="animate-pop mt-4 rounded-2xl border-2 border-emerald-400/60 bg-emerald-500/10 p-4 shadow-[0_0_30px_rgba(52,211,153,0.25)]">
          <p className="text-[11px] font-black uppercase tracking-widest text-emerald-300">{s.finalAnswer}</p>
          <p className="mt-1 font-mono text-lg font-bold" dir="ltr">
            {r.finalAnswer}
          </p>
        </div>
      )}
    </>
  );
}

/* ───────────── Plain text for copy / share / TTS ───────────── */
function toPlainText(r: AIResult, s: Dict): string {
  const lines: string[] = [r.title, ""];
  const list = (h: string, xs: string[]) => {
    if (!xs.length) return;
    lines.push(h, ...xs.map((x) => `• ${x.trim()}`), "");
  };
  switch (r.kind) {
    case "text":
      list(s.coreIdeas, r.coreIdeas);
      list(s.takeaways, r.takeaways);
      break;
    case "solver":
      lines.push(r.problemRestatement, "");
      r.steps.forEach((st) => lines.push(st.title, st.content, ""));
      lines.push(`${s.finalAnswer}: ${r.finalAnswer}`);
      break;
    case "summary":
      list(s.notes, r.bullets);
      break;
    case "grammar":
      lines.push(r.correctedText, "", r.translation.text);
      break;
  }
  return lines.join("\n");
}

export type { SummaryResult };
