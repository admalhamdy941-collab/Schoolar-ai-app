"use client";

import { useEffect, useRef, useState } from "react";
import type { Lang, ModuleKey } from "@/lib/types";
import { haptic, useStore } from "@/lib/store";
import { MODULE_META, t } from "@/lib/i18n";
import { ResultView } from "./ResultView";
import { Skeleton } from "./ui";

const EXAMPLES: Record<ModuleKey, Record<Lang, string>> = {
  text: {
    en: "The Road Not Taken by Robert Frost — Two roads diverged in a yellow wood, and sorry I could not travel both...",
    fr: "Le Dormeur du val, Arthur Rimbaud — C'est un trou de verdure où chante une rivière...",
    ar: "قصيدة «أراك عصي الدمع» لأبي فراس الحمداني: أراكَ عصيَّ الدمعِ شيمتُكَ الصبرُ...",
  },
  solver: {
    en: "A ball is thrown upward at 20 m/s. How high does it go? (g = 9.8 m/s²)",
    fr: "Résoudre l'équation : 3x − 7 = 11",
    ar: "أوجد قيمة x في المعادلة: 3x − 7 = 11",
  },
  summary: {
    en: "Photosynthesis notes: light reactions in thylakoid, Calvin cycle in stroma, 6CO2 + 6H2O → C6H12O6 + 6O2 ...",
    fr: "Notes sur la Révolution française : 1789, États généraux, prise de la Bastille, Déclaration des droits de l'homme...",
    ar: "ملاحظات درس الخلية: الغشاء البلازمي، النواة، الميتوكوندريا، الريبوسومات...",
  },
  grammar: {
    en: "Me and him goes to the libary every days to studying.",
    fr: "Les enfants a mangé leur goûter avant de partirent à l'école.",
    ar: "ذهب الطلاب الى المدرسه و هم يحملون كتبهم",
  },
  dialect: {
    en: "Explain supply and demand in simple Darija with everyday examples.",
    fr: "Explique l'offre et la demande en darija simple avec des exemples du quotidien.",
    ar: "اشرح لي قانون العرض والطلب بالدارجة مع أمثلة من الواقع.",
  },
};

export function ModuleScreen({ module }: { module: ModuleKey }) {
  const { lang, loading, error, generate, sessions, activeSessionId, openSession, online, cameraUnlocked, dialectUnlocked, unlockCamera, unlockDialect, draftInput, setDraftInput } = useStore();
  const s = t(lang);
  const meta = MODULE_META[module];
  const [input, setInput] = useState("");
  const [targetLanguage, setTargetLanguage] = useState(lang === "en" ? "Arabic" : "English");
  const [image, setImage] = useState<{ mimeType: string; data: string; preview: string } | null>(null);
  const [unlockOpen, setUnlockOpen] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);
  const cameraRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!draftInput) return;
    setInput(draftInput);
    setDraftInput("");
  }, [draftInput, setDraftInput]);

  const active = sessions.find((x) => x.id === activeSessionId && x.module === module) ?? null;
  const history = sessions.filter((x) => x.module === module);

  const onPick = (file: File | undefined) => {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      const url = String(reader.result);
      setImage({ mimeType: file.type || "image/jpeg", data: url.split(",")[1] ?? "", preview: url });
      haptic(8);
    };
    reader.readAsDataURL(file);
  };

  const submit = async () => {
    const session = await generate({ module, input, image: image ? { mimeType: image.mimeType, data: image.data } : null, options: module === "grammar" ? { targetLanguage } : undefined });
    if (session) {
      setInput("");
      setImage(null);
      window.scrollTo({ top: 0, behavior: "smooth" });
    }
  };

  const placeholder = { text: s.textPh, solver: s.solverPh, summary: s.summaryPh, grammar: s.grammarPh, dialect: s.dialectPh }[module];

  if (active) {
    return (
      <div className="space-y-3">
        <button type="button" onClick={() => openSession(null)} className="btn-ghost -ms-2">
          ← {s.back}
        </button>
        <ResultView session={active} />
      </div>
    );
  }

  return (
    <div className="space-y-5">
      {/* Banner */}
      <header className={`glow-card animate-rise flex items-center gap-4 bg-gradient-to-br ${meta.accent} p-5 shadow-xl ${meta.glow}`}>
        <span className="relative grid h-14 w-14 shrink-0 place-items-center rounded-2xl border border-white/30 bg-white/20 text-3xl backdrop-blur">{meta.emoji}</span>
        <div className="relative min-w-0">
          <h1 className="text-xl font-black leading-tight">{s[module]}</h1>
          <p className="text-xs text-white/80">{s.moduleDesc[module]}</p>
        </div>
      </header>

      {/* Input panel */}
      <div className="neu animate-rise space-y-3 p-4" style={{ animationDelay: "80ms" }}>
        <textarea value={input} onChange={(e) => setInput(e.target.value)} placeholder={placeholder} rows={6} className="neu-lo w-full resize-y p-4 text-sm leading-relaxed text-slate-100 outline-none transition placeholder:text-slate-500 focus:ring-2" style={{ ["--tw-ring-color" as string]: `${meta.hex}99` }} />

        {module === "grammar" && (
          <label className="flex items-center gap-2 text-sm">
            <span className="text-slate-400">{s.targetLang}</span>
            <select value={targetLanguage} onChange={(e) => setTargetLanguage(e.target.value)} className="neu-lo px-3 py-1.5 text-slate-100">
              {["English", "French", "Arabic", "Spanish", "German", "Turkish"].map((l) => (
                <option key={l} className="bg-slate-900">
                  {l}
                </option>
              ))}
            </select>
          </label>
        )}

        {module === "dialect" && !dialectUnlocked && (
          <button
            type="button"
            className="flex h-12 w-full items-center justify-center gap-2 rounded-2xl border border-green-400/50 bg-green-500/15 text-sm font-extrabold text-green-300 transition active:scale-95"
            onClick={() => setUnlockOpen(true)}
          >
            🔒 {s.dialectLockedTitle}
          </button>
        )}

        {module === "solver" && (
          <div className="space-y-2">
            <div className="grid grid-cols-2 gap-2">
              <input ref={cameraRef} type="file" accept="image/*" capture="environment" hidden onChange={(e) => onPick(e.target.files?.[0])} />
              <input ref={fileRef} type="file" accept="image/*" hidden onChange={(e) => onPick(e.target.files?.[0])} />
              <ToolBtn
                hex={meta.hex}
                onClick={() => {
                  if (!cameraUnlocked) {
                    setUnlockOpen(true);
                    return;
                  }
                  cameraRef.current?.click();
                }}
              >
                {cameraUnlocked ? "📷" : "🔒"} {s.camera}
              </ToolBtn>
              <ToolBtn hex={meta.hex} onClick={() => fileRef.current?.click()}>
                🖼️ {s.upload}
              </ToolBtn>
            </div>
            {image && (
              <div className="relative">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={image.preview} alt="homework" className="max-h-56 w-full rounded-2xl border border-white/10 object-contain" />
                <button type="button" onClick={() => setImage(null)} className="absolute end-2 top-2 grid h-8 w-8 place-items-center rounded-full bg-black/60 text-sm">
                  ✕
                </button>
              </div>
            )}
          </div>
        )}

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={submit}
            disabled={loading || !online || (!input.trim() && !image) || (module === "dialect" && !dialectUnlocked)}
            className="flex h-14 flex-1 items-center justify-center gap-2 rounded-2xl border border-white/20 text-base font-black text-white transition hover:brightness-110 active:scale-[0.98] disabled:opacity-40"
            style={{ background: loading ? "var(--surface-hi)" : `linear-gradient(90deg, ${meta.hex}, ${meta.hex}bb)`, boxShadow: loading ? undefined : `0 12px 36px ${meta.hex}66` }}
          >
            {loading ? <span className="h-5 w-5 animate-spin rounded-full border-2 border-white/30 border-t-white" /> : "✨"} {loading ? s.generating : s.generate}
          </button>
          <button
            type="button"
            className="btn-action"
            onClick={() => {
              haptic(5);
              setInput(EXAMPLES[module][lang]);
            }}
          >
            {s.example}
          </button>
        </div>
        {error && <p className="rounded-2xl border border-rose-400/40 bg-rose-500/10 p-3 text-sm text-rose-300">{error}</p>}
      </div>

      {loading && <Skeleton hex={meta.hex} label={s.generating} />}

      {history.length > 0 && !loading && (
        <section>
          <h2 className="mb-3 flex items-center gap-2 text-base font-black">
            <span className="h-5 w-1 rounded-full" style={{ background: meta.hex }} /> {s.library}
          </h2>
          <ul className="space-y-2.5">
            {history.map((h) => (
              <li key={h.id}>
                <button type="button" onClick={() => openSession(h.id)} className="neu flex w-full items-center gap-3 p-3.5 text-start transition hover:border-white/20 active:scale-[0.99]">
                  <span className={`grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-gradient-to-br ${meta.accent} text-xl shadow-lg ${meta.glow}`}>{meta.emoji}</span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate font-extrabold">{h.title}</span>
                    <span className="block truncate text-xs text-slate-400">
                      {new Date(h.createdAt).toLocaleString()} · {h.language.toUpperCase()}
                    </span>
                  </span>
                  {h.quizScore !== null ? <span className="pill border-emerald-400/50 bg-emerald-500/15 text-emerald-300">✓ {h.quizScore}/3</span> : <span className="text-slate-500">›</span>}
                </button>
              </li>
            ))}
          </ul>
        </section>
      )}

      {unlockOpen && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-black/70 p-4" onClick={() => setUnlockOpen(false)}>
          <div className="neu w-full max-w-sm p-5" onClick={(e) => e.stopPropagation()}>
            <h3 className="flex items-center gap-2 text-lg font-black">
              <span className="grid h-10 w-10 place-items-center rounded-xl bg-gradient-to-br from-amber-400 to-orange-500">🔓</span>
              {s.unlockTitle}
            </h3>
            <p className="mt-3 text-sm leading-relaxed text-slate-300">{s.unlockBody}</p>
            <div className="mt-5 flex items-center justify-between gap-2">
              <button type="button" className="btn-ghost" onClick={() => setUnlockOpen(false)}>
                {s.unlockLater}
              </button>
              <button
                type="button"
                className="btn-primary px-5"
                onClick={async () => {
                  const text = `${s.unlockMessage} ${window.location.origin}`;
                  try {
                    if (navigator.share) await navigator.share({ title: s.appName, text, url: window.location.origin });
                    else await navigator.clipboard.writeText(text);
                    if (module === "dialect") unlockDialect();
                    else unlockCamera();
                    setUnlockOpen(false);
                    haptic([10, 30, 10]);
                  } catch {
                    /* cancelled */
                  }
                }}
              >
                📤 {s.unlockShare}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function ToolBtn({ children, hex, onClick }: { children: React.ReactNode; hex: string; onClick: () => void }) {
  return (
    <button type="button" onClick={onClick} className="flex h-12 items-center justify-center gap-2 rounded-2xl border text-sm font-extrabold transition active:scale-95" style={{ borderColor: `${hex}66`, background: `${hex}1f`, color: hex }}>
      {children}
    </button>
  );
}
