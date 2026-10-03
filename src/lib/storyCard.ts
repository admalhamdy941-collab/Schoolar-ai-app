/** Draw a branded 9:16 story PNG on a canvas — no extra dependencies. */
export async function renderStoryPng(opts: {
  title: string;
  bullets: string[];
  streak: number;
  level: number;
  xp: number;
  kicker: string;
  appName: string;
}): Promise<Blob> {
  const W = 1080;
  const H = 1920;
  const canvas = document.createElement("canvas");
  canvas.width = W;
  canvas.height = H;
  const ctx = canvas.getContext("2d")!;

  const g = ctx.createLinearGradient(0, 0, W, H);
  g.addColorStop(0, "#1e1b4b");
  g.addColorStop(0.45, "#0f172a");
  g.addColorStop(1, "#134e4a");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, W, H);

  // glow orbs
  orb(ctx, 180, 220, 320, "rgba(129,140,248,0.28)");
  orb(ctx, 900, 1600, 380, "rgba(16,185,129,0.22)");

  ctx.fillStyle = "#fff";
  ctx.font = "800 42px Plus Jakarta Sans, system-ui, sans-serif";
  ctx.fillText("🎓  " + opts.appName, 80, 140);
  ctx.fillStyle = "#fbbf24";
  ctx.font = "800 32px Plus Jakarta Sans, system-ui, sans-serif";
  ctx.fillText(`🔥 ${opts.streak}   ·   Lv.${opts.level}   ·   ${opts.xp} XP`, 80, 200);

  ctx.fillStyle = "#fbbf24";
  ctx.font = "800 28px Plus Jakarta Sans, system-ui, sans-serif";
  ctx.fillText(opts.kicker, 80, 340);

  ctx.fillStyle = "#fff";
  ctx.font = "900 64px Plus Jakarta Sans, system-ui, sans-serif";
  wrap(ctx, opts.title, 80, 430, W - 160, 74);

  ctx.font = "600 36px Plus Jakarta Sans, system-ui, sans-serif";
  let y = 700;
  for (const b of opts.bullets.slice(0, 6)) {
    ctx.fillStyle = "#fbbf24";
    ctx.fillText("⚡", 80, y);
    ctx.fillStyle = "rgba(248,250,252,0.88)";
    y = wrap(ctx, b.replace(/^\s*-+\s*/, ""), 150, y, W - 240, 48) + 28;
    if (y > H - 280) break;
  }

  roundRect(ctx, 80, H - 180, W - 160, 80, 40, "rgba(255,255,255,0.08)");
  ctx.fillStyle = "rgba(248,250,252,0.7)";
  ctx.font = "700 28px Plus Jakarta Sans, system-ui, sans-serif";
  ctx.fillText(`${opts.appName}  ·  scholar-ai.app`, 120, H - 128);

  const blob = await new Promise<Blob>((res, rej) => canvas.toBlob((b) => (b ? res(b) : rej(new Error("toBlob failed"))), "image/png"));
  return blob;
}

function orb(ctx: CanvasRenderingContext2D, x: number, y: number, r: number, c: string) {
  const g = ctx.createRadialGradient(x, y, 10, x, y, r);
  g.addColorStop(0, c);
  g.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.fill();
}

function wrap(ctx: CanvasRenderingContext2D, text: string, x: number, y: number, maxW: number, lh: number): number {
  const words = text.split(/\s+/);
  let line = "";
  for (const w of words) {
    const test = line ? line + " " + w : w;
    if (ctx.measureText(test).width > maxW && line) {
      ctx.fillText(line, x, y);
      y += lh;
      line = w;
    } else line = test;
  }
  if (line) ctx.fillText(line, x, y);
  return y;
}

function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number, fill: string) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
  ctx.fillStyle = fill;
  ctx.fill();
}

export async function shareOrDownload(blob: Blob, filename: string, caption: string) {
  const file = new File([blob], filename, { type: "image/png" });
  const nav = navigator as Navigator & { canShare?: (d: ShareData) => boolean };
  if (nav.share && (!nav.canShare || nav.canShare({ files: [file] }))) {
    try {
      await nav.share({ files: [file], title: caption, text: caption });
      return;
    } catch {
      /* user cancelled or unsupported */
    }
  }
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
