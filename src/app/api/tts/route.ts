import { MsEdgeTTS, OUTPUT_FORMAT } from "msedge-tts";
import type { Readable } from "stream";
import { ApiError, handleApiError, readJson, requireUser, str } from "@/lib/api";
import { prepareForEngine } from "@/lib/tts/diacritize";

export const runtime = "nodejs";
export const maxDuration = 60;

const ALLOWED_VOICES = new Set(["fa-IR-FaridNeural", "fa-IR-DilaraNeural"]);
const CHUNK_CHARS = 1000;

function escapeXml(text: string) {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&apos;");
}

function chunkText(text: string): string[] {
  if (text.length <= CHUNK_CHARS) return [text];
  const sentences = text.match(/[^.!?؟…\n]+(?:[.!?؟…]+|\n+|$)/g) ?? [text];
  const chunks: string[] = [];
  let buffer = "";
  for (const sentence of sentences) {
    if ((buffer + sentence).length > CHUNK_CHARS && buffer.trim()) {
      chunks.push(buffer.trim());
      buffer = sentence;
    } else {
      buffer += sentence;
    }
  }
  if (buffer.trim()) chunks.push(buffer.trim());
  return chunks.flatMap((c) => {
    if (c.length <= CHUNK_CHARS * 1.5) return [c];
    const out: string[] = [];
    for (let i = 0; i < c.length; i += CHUNK_CHARS) out.push(c.slice(i, i + CHUNK_CHARS));
    return out;
  });
}

function streamToBuffer(stream: Readable, timeoutMs: number): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    const timer = setTimeout(() => reject(new Error("TTS timeout")), timeoutMs);
    stream.on("data", (c: Buffer) => chunks.push(c));
    stream.on("end", () => {
      clearTimeout(timer);
      resolve(Buffer.concat(chunks));
    });
    stream.on("error", (err) => {
      clearTimeout(timer);
      reject(err);
    });
  });
}

async function synthesizeChunk(text: string, voice: string, rate: string, pitch: string): Promise<Buffer> {
  const tts = new MsEdgeTTS();
  try {
    await tts.setMetadata(voice, OUTPUT_FORMAT.AUDIO_24KHZ_48KBITRATE_MONO_MP3);
    const { audioStream } = tts.toStream(escapeXml(text), { rate, pitch });
    return await streamToBuffer(audioStream, 45000);
  } finally {
    try {
      tts.close();
    } catch {
      /* ignore */
    }
  }
}

export async function POST(req: Request) {
  try {
    await requireUser();
    const body = await readJson<{ text?: string; voice?: string; rate?: string; pitch?: string }>(req);
    const text = prepareForEngine(str(body.text, 60000));
    if (!text) throw new ApiError(400, "متنی برای خواندن وجود ندارد.");

    const voice = ALLOWED_VOICES.has(body.voice ?? "") ? (body.voice as string) : "fa-IR-FaridNeural";
    const rate = /^[+-]\d{1,3}%$/.test(body.rate ?? "") ? (body.rate as string) : "+0%";
    const pitch = /^[+-]\d{1,3}Hz$/.test(body.pitch ?? "") ? (body.pitch as string) : "+0Hz";

    const buffers: Buffer[] = [];
    for (const chunk of chunkText(text)) {
      let lastError: unknown;
      for (let attempt = 0; attempt < 2; attempt++) {
        try {
          buffers.push(await synthesizeChunk(chunk, voice, rate, pitch));
          lastError = null;
          break;
        } catch (err) {
          lastError = err;
        }
      }
      if (lastError) throw lastError;
    }

    const audio = Buffer.concat(buffers);
    if (!audio.length) throw new ApiError(502, "موتور صدا پاسخی برنگرداند.");

    return new Response(new Uint8Array(audio), {
      headers: {
        "Content-Type": "audio/mpeg",
        "Content-Length": String(audio.length),
        "Cache-Control": "private, max-age=3600",
      },
    });
  } catch (error) {
    if (error instanceof ApiError) return handleApiError(error);
    console.error("TTS error:", error);
    return Response.json(
      { error: "موتور صدای آنلاین در دسترس نیست. از صدای دستگاه استفاده می‌شود." },
      { status: 502 },
    );
  }
}
