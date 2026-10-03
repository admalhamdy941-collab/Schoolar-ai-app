import { NextResponse } from "next/server";
import { extractPdfText } from "@/lib/pdfExtract";

export const dynamic = "force-dynamic";
export const maxDuration = 30;

/** Direct PDF / document import — extracts text for AI processing. */
export async function POST(req: Request) {
  try {
    const form = await req.formData();
    const file = form.get("file");
    if (!(file instanceof File)) return NextResponse.json({ error: "No file uploaded" }, { status: 400 });
    if (file.size > 12 * 1024 * 1024) return NextResponse.json({ error: "File too large (max 12 MB)" }, { status: 400 });

    const name = file.name.toLowerCase();
    const buf = Buffer.from(await file.arrayBuffer());

    if (name.endsWith(".txt") || file.type.startsWith("text/")) {
      return NextResponse.json({ text: buf.toString("utf8").slice(0, 20_000), status: "ok", filename: file.name });
    }

    const text = extractPdfText(buf).slice(0, 20_000);
    if (!text) {
      return NextResponse.json({
        text: "",
        status: "empty",
        filename: file.name,
        error: "Could not extract text (the PDF may be scanned). Try a photo of the page in the Solver tab.",
      });
    }
    return NextResponse.json({ text, status: "ok", filename: file.name });
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : "Parse failed", status: "error" }, { status: 500 });
  }
}
