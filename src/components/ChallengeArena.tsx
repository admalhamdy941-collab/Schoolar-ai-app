"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { haptic } from "@/lib/store";

interface Payload {
  code: string;
  title: string;
  language: string;
  plays: number;
  total: number;
  quiz: { question: string; options: string[] }[];
  leaderboard: { nickname: string; score: number; total: number }[];
}

export function ChallengeArena({ code }: { code: string }) {
  const [data, setData] = useState<Payload | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [answers, setAnswers] = useState<(number | null)[]>([]);
  const [nick, setNick] = useState("Challenger");
  const [result, setResult] = useState<{ score: number; total: number; explanations: { correct: boolean; answerIndex: number; explanation: string }[] } | null>(null);

  useEffect(() => {
    void (async () => {
      const res = await fetch(`/api/challenges/${code}`);
      const json = await res.json();
      if (!res.ok) setError(json.error ?? "Not found");
      else {
        setData(json);
        setAnswers(json.quiz.map(() => null));
      }
    })();
  }, [code]);

  const submit = async () => {
    if (!data || answers.some((a) => a === null)) return;
    haptic(12);
    const res = await fetch(`/api/challenges/${code}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ answers, nickname: nick }),
    });
    const json = await res.json();
    setResult(json);
    haptic(json.score === json.total ? [10, 30, 10, 30, 60] : 20);
  };

  if (error) {
    return (
      <main className="mx-auto grid min-h-screen max-w-lg place-items-center p-6 text-center">
        <div>
          <p className="text-4xl">🎯</p>
          <p className="mt-3 font-black">{error}</p>
          <Link href="/" className="btn-primary mt-4 inline-block">
            Scholar AI
          </Link>
        </div>
      </main>
    );
  }
  if (!data) return <main className="grid min-h-screen place-items-center text-4xl animate-pulse">🎯</main>;

  return (
    <main className="mx-auto min-h-screen max-w-lg px-4 py-8">
      <Link href="/" className="text-sm font-bold text-indigo-300">
        ← Scholar AI
      </Link>
      <header className="glow-card mt-4 bg-gradient-to-br from-emerald-500 to-teal-600 p-5 shadow-xl shadow-emerald-500/30">
        <p className="relative text-[11px] font-black uppercase tracking-[0.2em] text-white/80">Peer Quiz Challenge · {data.code}</p>
        <h1 className="relative mt-1 text-2xl font-black leading-tight">{data.title}</h1>
        <p className="relative mt-1 text-xs text-white/80">
          {data.plays} plays · {data.total} questions
        </p>
      </header>

      <label className="mt-5 block text-xs font-bold uppercase tracking-widest text-slate-400">Nickname</label>
      <input value={nick} onChange={(e) => setNick(e.target.value)} className="neu-lo mt-1 w-full p-3 text-sm outline-none" maxLength={24} />

      <ol className="mt-5 space-y-4">
        {data.quiz.map((q, qi) => (
          <li key={qi} className="neu p-4">
            <p className="mb-3 font-bold">
              <span className="me-2 inline-flex h-6 w-6 items-center justify-center rounded-full bg-emerald-500/20 text-xs font-black text-emerald-300">{qi + 1}</span>
              {q.question}
            </p>
            <div className="grid gap-2">
              {q.options.map((opt, oi) => {
                const selected = answers[qi] === oi;
                const revealed = result !== null;
                const isAnswer = revealed && result.explanations[qi].answerIndex === oi;
                let cls = "border-white/10 bg-[var(--surface)]";
                if (revealed && isAnswer) cls = "border-emerald-400 bg-emerald-500/15";
                else if (revealed && selected && !isAnswer) cls = "border-rose-400 bg-rose-500/15";
                else if (selected) cls = "border-indigo-400 bg-indigo-500/20";
                return (
                  <button
                    key={oi}
                    type="button"
                    disabled={revealed}
                    onClick={() => {
                      haptic(5);
                      setAnswers((p) => p.map((a, i) => (i === qi ? oi : a)));
                    }}
                    className={`rounded-xl border px-3 py-2 text-start text-sm ${cls}`}
                  >
                    <span className="me-2 font-mono text-xs opacity-60">{String.fromCharCode(65 + oi)}</span>
                    {opt}
                  </button>
                );
              })}
            </div>
            {result && <p className="mt-2 text-xs text-slate-400">💡 {result.explanations[qi].explanation}</p>}
          </li>
        ))}
      </ol>

      {!result ? (
        <button type="button" disabled={answers.some((a) => a === null)} onClick={submit} className="btn-primary mt-5 w-full">
          Submit score
        </button>
      ) : (
        <div className="animate-pop mt-5 rounded-3xl border-2 border-emerald-400/50 bg-emerald-500/10 p-5 text-center">
          <p className="text-xs font-black uppercase tracking-widest text-emerald-300">You scored</p>
          <p className="text-5xl font-black text-emerald-300">
            {result.score}/{result.total}
          </p>
        </div>
      )}

      {data.leaderboard.length > 0 && (
        <section className="neu mt-6 p-4">
          <h2 className="mb-3 text-sm font-black uppercase tracking-widest text-slate-400">Leaderboard</h2>
          <ol className="space-y-2">
            {data.leaderboard.map((p, i) => (
              <li key={i} className="flex items-center justify-between text-sm">
                <span>
                  <span className="me-2 font-black text-indigo-300">#{i + 1}</span>
                  {p.nickname}
                </span>
                <span className="font-black">
                  {p.score}/{p.total}
                </span>
              </li>
            ))}
          </ol>
        </section>
      )}
    </main>
  );
}
