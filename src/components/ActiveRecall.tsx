"use client";

import { useState } from "react";
import type { ActiveRecall as RecallData } from "@/lib/types";
import { haptic, useStore } from "@/lib/store";
import { t } from "@/lib/i18n";

/**
 * Active Recall Widget — rendered after EVERY AI response.
 * 1) 3-question interactive micro-quiz with instant feedback + explanations.
 * 2) 3 Anki-style flip flashcards.
 */
export function ActiveRecallWidget({ recall, sessionId, savedScore }: { recall: RecallData; sessionId: number; savedScore: number | null }) {
  const { lang } = useStore();
  const s = t(lang);
  return (
    <section className="mt-6 space-y-5">
      <div className="flex items-center gap-2">
        <span className="h-px flex-1 bg-gradient-to-r from-transparent via-indigo-400/40 to-transparent" />
        <span className="text-xs font-black uppercase tracking-[0.25em] text-indigo-300">Active Recall</span>
        <span className="h-px flex-1 bg-gradient-to-r from-transparent via-indigo-400/40 to-transparent" />
      </div>
      {recall.quiz.length > 0 && <Quiz quiz={recall.quiz} sessionId={sessionId} savedScore={savedScore} title={s.quiz} checkLabel={s.check} scoreLabel={s.score} />}
      {recall.flashcards.length > 0 && <Flashcards cards={recall.flashcards} title={s.flashcards} flipLabel={s.flip} nextLabel={s.next} prevLabel={s.prev} />}
    </section>
  );
}

function Quiz({ quiz, sessionId, savedScore, title, checkLabel, scoreLabel }: { quiz: RecallData["quiz"]; sessionId: number; savedScore: number | null; title: string; checkLabel: string; scoreLabel: string }) {
  const { submitQuiz } = useStore();
  const [answers, setAnswers] = useState<(number | null)[]>(() => quiz.map(() => null));
  const [checked, setChecked] = useState(savedScore !== null);
  const correct = answers.filter((a, i) => a === quiz[i].answerIndex).length;
  const allAnswered = answers.every((a) => a !== null);

  const onCheck = () => {
    setChecked(true);
    haptic(correct === quiz.length ? [10, 30, 10, 30, 60] : 20);
    void submitQuiz(sessionId, correct, quiz.length);
  };

  return (
    <div className="neu p-4">
      <div className="mb-3 flex items-center justify-between">
        <h3 className="flex items-center gap-2 text-base font-black">
          <span>🎯</span> {title}
        </h3>
        {(checked || savedScore !== null) && (
          <span className="pill border-emerald-400/50 bg-emerald-500/15 text-emerald-300">
            {scoreLabel}: {savedScore ?? correct}/{quiz.length}
          </span>
        )}
      </div>
      <ol className="space-y-4">
        {quiz.map((q, qi) => (
          <li key={qi} className="neu-lo p-4">
            <p className="mb-3 font-medium">
              <span className="me-2 inline-flex h-6 w-6 items-center justify-center rounded-full bg-indigo-500/25 text-xs font-black text-indigo-300">{qi + 1}</span>
              {q.question}
            </p>
            <div className="grid gap-2 sm:grid-cols-2">
              {q.options.map((opt, oi) => {
                const selected = answers[qi] === oi;
                const isAnswer = q.answerIndex === oi;
                let cls = "border-white/10 bg-[var(--surface)] hover:border-indigo-400/60";
                if (checked && isAnswer) cls = "border-emerald-400 bg-emerald-500/15 shadow-[0_0_14px_rgba(52,211,153,0.4)]";
                else if (checked && selected && !isAnswer) cls = "border-rose-400 bg-rose-500/15";
                else if (selected) cls = "border-indigo-400 bg-indigo-500/20 shadow-[0_0_14px_rgba(129,140,248,0.4)]";
                return (
                  <button
                    key={oi}
                    type="button"
                    disabled={checked}
                    onClick={() => {
                      haptic(5);
                      setAnswers((p) => p.map((a, i) => (i === qi ? oi : a)));
                    }}
                    className={`rounded-xl border px-3 py-2 text-start text-sm transition active:scale-[0.98] ${cls}`}
                  >
                    <span className="me-2 font-mono text-xs opacity-60">{String.fromCharCode(65 + oi)}</span>
                    {opt}
                  </button>
                );
              })}
            </div>
            {checked && <p className="mt-3 rounded-xl bg-black/20 p-2.5 text-xs text-slate-300">💡 {q.explanation}</p>}
          </li>
        ))}
      </ol>
      {!checked && (
        <button type="button" disabled={!allAnswered} onClick={onCheck} className="btn-primary mt-4 w-full">
          {checkLabel}
        </button>
      )}
    </div>
  );
}

function Flashcards({ cards, title, flipLabel, nextLabel, prevLabel }: { cards: RecallData["flashcards"]; title: string; flipLabel: string; nextLabel: string; prevLabel: string }) {
  const [i, setI] = useState(0);
  const [flipped, setFlipped] = useState(false);
  const go = (d: number) => {
    haptic(6);
    setFlipped(false);
    setI((p) => (p + d + cards.length) % cards.length);
  };
  const card = cards[i];
  return (
    <div className="neu p-4">
      <h3 className="mb-3 flex items-center gap-2 text-base font-black">
        <span>🃏</span> {title}
        <span className="ms-auto text-xs font-normal text-slate-400">
          {i + 1} / {cards.length}
        </span>
      </h3>
      <div className="[perspective:1200px]">
        <button
          type="button"
          onClick={() => {
            haptic(8);
            setFlipped((f) => !f);
          }}
          className={`relative h-44 w-full rounded-2xl text-start transition-transform duration-500 [transform-style:preserve-3d] ${flipped ? "[transform:rotateY(180deg)]" : ""}`}
        >
          <div className="absolute inset-0 flex flex-col justify-between rounded-2xl bg-gradient-to-br from-indigo-500 to-violet-600 p-5 text-white shadow-[0_16px_40px_rgba(99,102,241,0.45)] [backface-visibility:hidden]">
            <span className="text-[10px] uppercase tracking-widest opacity-70">Front</span>
            <p className="text-lg font-semibold leading-snug">{card.front}</p>
            <span className="text-xs opacity-70">{flipLabel}</span>
          </div>
          <div className="absolute inset-0 flex flex-col justify-between rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-600 p-5 text-white shadow-[0_16px_40px_rgba(16,185,129,0.45)] [backface-visibility:hidden] [transform:rotateY(180deg)]">
            <span className="text-[10px] uppercase tracking-widest opacity-70">Back</span>
            <p className="text-base leading-snug">{card.back}</p>
            <span className="text-xs opacity-70">{flipLabel}</span>
          </div>
        </button>
      </div>
      <div className="mt-3 flex items-center justify-between">
        <button type="button" onClick={() => go(-1)} className="btn-ghost">
          ← {prevLabel}
        </button>
        <div className="flex gap-1">
          {cards.map((_, k) => (
            <span key={k} className={`h-1.5 w-5 rounded-full ${k === i ? "bg-indigo-400 shadow-[0_0_8px_rgba(129,140,248,0.8)]" : "bg-white/10"}`} />
          ))}
        </div>
        <button type="button" onClick={() => go(1)} className="btn-ghost">
          {nextLabel} →
        </button>
      </div>
    </div>
  );
}
