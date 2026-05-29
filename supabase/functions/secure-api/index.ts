import { handleOptions, jsonResponse, readJson } from "../_shared/common.ts";

type SecureApiRequest = {
  provider?: "openai" | "health";
  operation?: string;
  action?: string;
  payload?: Record<string, unknown>;
};

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  const body = await readJson<SecureApiRequest>(req);
  const action = body.action ?? body.operation;

  if (body.provider === "health" || action === "health") {
    return jsonResponse({ ok: true, service: "peekaboo-secure-api", mock_openai: !Deno.env.get("OPENAI_API_KEY") });
  }

  // MVP data-write orchestration placeholders. Production deployments should replace
  // these with authenticated Supabase service-role inserts after validating parent/child ownership.
  if (["save_position", "register_book_upload", "save_vocabulary_lookup"].includes(action ?? "")) {
    return jsonResponse({ ok: true, action, accepted: true, payload: body.payload ?? {}, note: "Validated secure action placeholder for MVP demo." });
  }

  if (body.provider !== "openai") {
    return jsonResponse({ error: "Unsupported provider/action. Allowed actions: health, save_position, register_book_upload, save_vocabulary_lookup, moderate-text" }, 400);
  }

  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    return jsonResponse({ mock: true, operation: action ?? "unknown", result: "OPENAI_API_KEY missing; secure-api returned a demo response without external network calls." });
  }

  if (action === "moderate-text") {
    const input = String(body.payload?.input ?? "");
    const resp = await fetch("https://api.openai.com/v1/moderations", {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model: "omni-moderation-latest", input }),
    });
    if (!resp.ok) return jsonResponse({ error: "OpenAI moderation failed", detail: await resp.text() }, 502);
    return jsonResponse({ mock: false, result: await resp.json() });
  }

  return jsonResponse({ error: "Unsupported operation. Allowed: health, save_position, register_book_upload, save_vocabulary_lookup, moderate-text" }, 400);
});
