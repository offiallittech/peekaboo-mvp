import { handleOptions, jsonResponse } from "../_shared/common.ts";

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  const apiKey = Deno.env.get("OPENAI_API_KEY");
  const form = await req.formData().catch(() => null);
  const audio = form?.get("audio");
  const language = String(form?.get("language") ?? "en");
  const prompt = String(form?.get("prompt") ?? "Child reading practice audio");

  if (!(audio instanceof File)) {
    return jsonResponse({ error: "Expected multipart/form-data with an audio File field" }, 400);
  }

  if (!apiKey) {
    return jsonResponse({
      transcript: "Mock transcript: the quick brown fox jumps over the moon",
      language,
      duration_seconds: null,
      mock: true,
      note: "OPENAI_API_KEY is not configured; returning deterministic demo transcript.",
    });
  }

  const openAiForm = new FormData();
  openAiForm.append("file", audio, audio.name || "reading-audio.webm");
  openAiForm.append("model", Deno.env.get("OPENAI_TRANSCRIPTION_MODEL") ?? "whisper-1");
  openAiForm.append("language", language.slice(0, 2));
  openAiForm.append("prompt", prompt);
  openAiForm.append("response_format", "verbose_json");

  const resp = await fetch("https://api.openai.com/v1/audio/transcriptions", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}` },
    body: openAiForm,
  });

  if (!resp.ok) {
    return jsonResponse({
      transcript: "Mock transcript: the quick brown fox jumps over the moon",
      language,
      duration_seconds: null,
      mock: true,
      provider_error: "OpenAI transcription failed; returning deterministic demo transcript.",
      provider_status: resp.status,
    });
  }

  const data = await resp.json();
  return jsonResponse({
    transcript: data.text ?? "",
    language: data.language ?? language,
    duration_seconds: data.duration ?? null,
    segments: data.segments ?? [],
    mock: false,
  });
});
