"use client";

import { useRef, useState } from "react";
import { haptic, useStore } from "@/lib/store";
import { t } from "@/lib/i18n";
import { renderStoryPng, shareOrDownload } from "@/lib/storyCard";
import type { SessionDTO, SummaryResult, TextPrepResult } from "@/lib/types";

export function ViralHub() {
  const { lang, sessions, progress, setTab, cameraUnlocked, dialectUnlocked, unlockCamera, unlockDialect, setDraftInput } = useStore();
  const s = t(lang);
  const [busy, setBusy] = useState<string | null>(null);
  const [pdfMsg, setPdfMsg] = useState<string | null>(null);
  const [dialog, setDialog] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  const latestSummary = sessions.find((x) => x.module === "summary" || x.module === "text") ?? sessions[0] ?? null;
  const latestQuiz = sessions.find((x) => x.result.recall.quiz.length > 0) ?? null;

  const shareUnlock = async () => {
    haptic(10);
    const text = `${s.unlockMessage} ${window.location.origin}`;
    try {
      if (navigator.share) await navigator.share({ title: s.appName, text, url: window.location.origin });
      else await navigator.clipboard.writeText(text);
      unlockCamera();
      unlockDialect();
      setDialog(false);
      haptic([10, 30, 10]);
    } catch {
      /* cancelled */
    }
  };

  const exportStory = async () => {
    if (!latestSummary) return;
    setBusy("story");
    try {
      const bullets = storyBullets(latestSummary);
      const blob = await renderStoryPng({
        title: latestSummary.title,
        bullets,
        streak: progress?.currentStreak ?? 0,
        level: progress?.level ?? 1,
        xp: progress?.xp ?? 0,
        kicker: s.storyKicker,
        appName: s.appName,
      });
      await shareOrDownload(blob, "scholar-story.png", s.storyCaption);
    } finally {
      setBusy(null);
    }
  };

  const createChallenge = async () => {
    if (!latestQuiz) {
      haptic(20);
      setPdfMsg(s.peerNeedQuiz);
      return;
    }
    setBusy("peer");
    try {
      const res = await fetch("/api/challenges", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ sessionId: latestQuiz.id }) });
      const data = (await res.json()) as { code?: string; url?: string; error?: string };
      if (!res.ok) throw new Error(data.error);
      const url = `${window.location.origin}${data.url}`;
      const text = `${s.peerMessage} “${latestQuiz.title}”! ${url}`;
      if (navigator.share) await navigator.share({ title: s.peerTitle, text, url }).catch(() => navigator.clipboard.writeText(text));
      else await navigator.clipboard.writeText(text);
      haptic([10, 20, 10]);
      setPdfMsg(url);
    } catch (e) {
      setPdfMsg(e instanceof Error ? e.message : s.peerNeedQuiz);
    } finally {
      setBusy(null);
    }
  };

  const onPdf = async (file: File | undefined) => {
    if (!file) return;
    setBusy("pdf");
    try {
      const fd = new FormData();
      fd.set("file", file);
      const res = await fetch("/api/pdf", { method: "POST", body: fd });
      const data = (await res.json()) as { text?: string; status?: string; error?: string };
      if (data.status === "ok" && data.text) {
        setDraftInput(data.text);
        setPdfMsg(`${s.pdfOk} (${file.name})`);
        setTab("summary");
        haptic([10, 30, 10]);
      } else {
        setPdfMsg(data.error ?? s.pdfEmpty);
      }
    } catch {
      setPdfMsg(s.pdfFailed);
    } finally {
      setBusy(null);
    }
  };

  return (
    <section className="space-y-3">
      <h2 className="flex items-center gap-2.5 text-base font-black">
        <span className="h-5 w-1 rounded-full bg-gradient-to-b from-indigo-400 to-cyan-400" />
        {s.viral}
      </h2>

      <ViralCard
        title={cameraUnlocked ? s.cameraUnlockedTitle : s.cameraLockedTitle}
        subtitle={cameraUnlocked ? s.cameraUnlockedSub : s.cameraLockedSub}
        icon={cameraUnlocked ? "🔓" : "🔒"}
        gradient="from-cyan-500 to-blue-600"
        onClick={() => {
          if (cameraUnlocked) setTab("solver");
          else setDialog(true);
        }}
      />
      <ViralCard
        title={dialectUnlocked ? "🇩🇿 " + s.dialect : `${s.dialectLockedTitle}`}
        subtitle={dialectUnlocked ? s.moduleDesc.dialect : s.dialectLockedSub}
        icon={dialectUnlocked ? "🔓" : "🔒"}
        gradient="from-green-500 to-yellow-500"
        onClick={() => {
          if (dialectUnlocked) {
            setTab("dialect");
            return;
          }
          setDialog(true);
        }}
      />
      <ViralCard title={s.peerTitle} subtitle={s.peerSub} icon="🎮" gradient="from-emerald-500 to-teal-600" onClick={createChallenge} busy={busy === "peer"} />
      <ViralCard
        title={s.pdfTitle}
        subtitle={s.pdfSub}
        icon="📄"
        gradient="from-indigo-500 to-violet-600"
        onClick={() => fileRef.current?.click()}
        busy={busy === "pdf"}
      />
      <input
        ref={fileRef}
        type="file"
        accept="application/pdf,.pdf,text/plain,.txt"
        hidden
        onChange={(e) => {
          void onPdf(e.target.files?.[0]);
          e.target.value = "";
        }}
      />

      {pdfMsg && <p className="rounded-2xl border border-indigo-400/30 bg-indigo-500/10 p-3 text-xs font-bold text-indigo-200">{pdfMsg}</p>}

      <h2 className="mt-4 flex items-center gap-2.5 text-base font-black">
        <span className="h-5 w-1 rounded-full bg-gradient-to-b from-amber-400 to-orange-500" />
        {s.storyTitle}
      </h2>
      {latestSummary ? (
        <div className="neu space-y-3 p-4">
          <p className="text-xs font-black uppercase tracking-widest text-amber-300">{s.storyKicker}</p>
          <p className="font-black leading-tight">{latestSummary.title}</p>
          <ul className="space-y-1 text-sm text-slate-300">
            {storyBullets(latestSummary)
              .slice(0, 4)
              .map((b, i) => (
                <li key={i}>⚡ {b}</li>
              ))}
          </ul>
          <button type="button" onClick={exportStory} disabled={busy === "story"} className="btn-primary w-full">
            {busy === "story" ? "…" : `📤 ${s.storyExport}`}
          </button>
        </div>
      ) : (
        <p className="neu p-4 text-sm text-slate-400">{s.storyEmpty}</p>
      )}

      {dialog && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-black/70 p-4" onClick={() => setDialog(false)}>
          <div className="neu w-full max-w-sm p-5" onClick={(e) => e.stopPropagation()}>
            <h3 className="flex items-center gap-2 text-lg font-black">
              <span className="grid h-10 w-10 place-items-center rounded-xl bg-gradient-to-br from-amber-400 to-orange-500">🔓</span>
              {s.unlockTitle}
            </h3>
            <p className="mt-3 text-sm leading-relaxed text-slate-300">{s.unlockBody}</p>
            <div className="mt-5 flex items-center justify-between gap-2">
              <button type="button" className="btn-ghost" onClick={() => setDialog(false)}>
                {s.unlockLater}
              </button>
              <button type="button" className="btn-primary px-5" onClick={shareUnlock}>
                📤 {s.unlockShare}
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}

function ViralCard({ title, subtitle, icon, gradient, onClick, busy }: { title: string; subtitle: string; icon: string; gradient: string; onClick: () => void; busy?: boolean }) {
  return (
    <button type="button" onClick={onClick} disabled={busy} className={`glow-card flex w-full items-center gap-3.5 bg-gradient-to-br ${gradient} p-4 text-start shadow-lg hover:-translate-y-0.5 active:scale-[0.98]`}>
      <span className="relative grid h-11 w-11 shrink-0 place-items-center rounded-full bg-white/20 text-xl">{busy ? "…" : icon}</span>
      <span className="relative min-w-0 flex-1">
        <span className="block font-black leading-tight">{title}</span>
        <span className="block text-[11px] text-white/80">{subtitle}</span>
      </span>
      <span className="relative text-white/70">›</span>
    </button>
  );
}

function storyBullets(session: SessionDTO): string[] {
  const r = session.result;
  if (r.kind === "summary") return (r as SummaryResult).bullets.map((x) => x.replace(/^\s*-+\s*/, "").trim()).filter(Boolean);
  if (r.kind === "text") {
    const t = r as TextPrepResult;
    return [...t.coreIdeas, ...t.takeaways];
  }
  if (r.kind === "solver") return [r.problemRestatement, r.finalAnswer].filter(Boolean);
  if (r.kind === "dialect") return [r.dialectSummary, ...r.quickSteps].filter(Boolean);
  return [r.correctedText];
}
