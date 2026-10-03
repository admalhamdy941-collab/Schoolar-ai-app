"use client";

import { useEffect } from "react";
import { useStore } from "@/lib/store";

/** Animated loading skeleton shown while Gemini is thinking. */
export function Skeleton({ hex, label }: { hex: string; label: string }) {
  return (
    <div className="animate-rise space-y-2.5" aria-busy>
      <div className="skeleton h-24 w-full" />
      <div className="flex gap-2">
        {[0, 1, 2].map((i) => (
          <div key={i} className="skeleton h-12 w-12" />
        ))}
        <div className="skeleton h-12 flex-1" />
      </div>
      <div className="skeleton h-5 w-56" />
      <div className="skeleton h-4 w-full" />
      <div className="skeleton h-4 w-full" />
      <div className="skeleton h-4 w-2/3" />
      <div className="skeleton mt-3 h-16 w-full" />
      <div className="skeleton h-16 w-full" />
      <p className="pt-2 text-center text-sm font-bold" style={{ color: hex, textShadow: `0 0 14px ${hex}` }}>
        {label}
      </p>
    </div>
  );
}

/** XP / badge toast. */
export function Toast() {
  const { toast, dismissToast } = useStore();
  useEffect(() => {
    if (!toast) return;
    const id = setTimeout(dismissToast, toast.badges?.length ? 6000 : 3000);
    return () => clearTimeout(id);
  }, [toast, dismissToast]);
  if (!toast) return null;
  return (
    <div className="animate-pop fixed inset-x-0 top-4 z-50 mx-auto w-[min(92vw,26rem)]">
      <div className="rounded-3xl border border-indigo-400/40 bg-[var(--surface-hi)]/95 p-4 shadow-[0_20px_60px_rgba(0,0,0,0.6),0_0_30px_rgba(129,140,248,0.35)] backdrop-blur-xl">
        <p className="font-black text-indigo-300">⚡ {toast.text}</p>
        {toast.badges?.map((b) => (
          <p key={b.code} className="mt-1.5 flex items-center gap-2 text-sm">
            <span className="grid h-8 w-8 place-items-center rounded-full bg-gradient-to-br from-amber-200 to-amber-500 text-base">{b.emoji}</span>
            <span>
              <strong>{b.name}</strong> — {b.description}
            </span>
          </p>
        ))}
      </div>
    </div>
  );
}
