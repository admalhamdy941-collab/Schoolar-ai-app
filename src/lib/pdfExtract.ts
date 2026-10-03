import { inflateRawSync, inflateSync } from "zlib";

/**
 * Lightweight PDF text extractor (no extra npm deps).
 * Handles uncompressed streams and FlateDecode, then pulls Tj / TJ / ' / " strings.
 * Good enough for school notes shared from WhatsApp / Telegram.
 */
export function extractPdfText(bytes: Buffer | Uint8Array): string {
  const buf = Buffer.isBuffer(bytes) ? bytes : Buffer.from(bytes);
  const latin = buf.toString("latin1");
  const chunks: string[] = [];

  const streamRe = /stream\r?\n([\s\S]*?)endstream/g;
  let m: RegExpExecArray | null;
  while ((m = streamRe.exec(latin))) {
    const headerSlice = latin.slice(Math.max(0, m.index - 400), m.index);
    const isFlate = /\/Filter\s*(?:\[[^\]]*FlateDecode[^\]]*\]|\/FlateDecode)/.test(headerSlice);
    const raw = Buffer.from(m[1], "latin1");
    let decoded = raw;
    if (isFlate) {
      try {
        decoded = inflateSync(raw);
      } catch {
        try {
          decoded = inflateRawSync(raw);
        } catch {
          continue;
        }
      }
    }
    chunks.push(stringsFromContent(decoded.toString("latin1")));
  }

  // Fallback: scan the whole file for literal Tj operators (uncompressed PDFs).
  if (chunks.join("").trim().length < 20) {
    chunks.push(stringsFromContent(latin));
  }

  return chunks
    .join("\n")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function stringsFromContent(content: string): string {
  const out: string[] = [];
  const re = /(?:\((?:\\.|[^\\)])*\)|\<(?:[0-9A-Fa-f]{2})+\>)\s*(?:Tj|TJ|'|")/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(content))) {
    const token = m[0];
    if (token.startsWith("(")) {
      const inner = token.slice(1, token.lastIndexOf(")"));
      out.push(unescapePdf(inner));
    } else if (token.startsWith("<")) {
      const hex = token.slice(1, token.indexOf(">"));
      out.push(hexToUtf16(hex));
    }
  }
  // TJ arrays: [(Hello) 10 (World)] TJ
  const tjArr = /\[((?:[^\[\]]|\[[^\]]*\])*)\]\s*TJ/g;
  while ((m = tjArr.exec(content))) {
    const parts = [...m[1].matchAll(/\((?:\\.|[^\\)])*\)/g)].map((x) => unescapePdf(x[0].slice(1, -1)));
    if (parts.length) out.push(parts.join(""));
  }
  return out.join(" ").replace(/\s+/g, " ").trim();
}

function unescapePdf(s: string): string {
  return s
    .replace(/\\n/g, "\n")
    .replace(/\\r/g, "\r")
    .replace(/\\t/g, "\t")
    .replace(/\\([()\\])/g, "$1")
    .replace(/\\(\d{1,3})/g, (_, n) => String.fromCharCode(parseInt(n, 8)));
}

function hexToUtf16(hex: string): string {
  const clean = hex.replace(/\s+/g, "");
  const chars: string[] = [];
  for (let i = 0; i + 3 < clean.length; i += 4) {
    chars.push(String.fromCharCode(parseInt(clean.slice(i, i + 4), 16)));
  }
  return chars.join("");
}
