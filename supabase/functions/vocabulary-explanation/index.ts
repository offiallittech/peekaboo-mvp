import { getAuthUserId, handleOptions, jsonResponse, readJson, supabaseRest } from "../_shared/common.ts";

type VocabRequest = {
  word?: string;
  child_id?: string;
  reading_level?: string;
  context?: string;
};

function mockExplanation(word: string, readingLevel: string) {
  return {
    word,
    definition: `${word} means something you can understand from the story.`,
    kid_friendly_definition: `A simple ${readingLevel} explanation for “${word}”.`,
    example_sentence: `Can you find ${word} in your book?`,
    image_prompt: `Friendly storybook illustration of the word ${word}, safe for children`,
    syllables: word.split(/(?=[aeiouy])/i).filter(Boolean),
    mock: true,
  };
}

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  // The MVP Android client currently calls with the public anon key before a
  // parent auth session exists. Treat auth as optional for vocabulary demo mode:
  // authenticated requests are persisted; anon requests return a child-safe
  // explanation without writing user data.
  const userId = await getAuthUserId(req);

  const body = await readJson<VocabRequest>(req);
  const word = String(body.word ?? "").trim();
  const readingLevel = body.reading_level ?? "beginner";
  if (!word) return jsonResponse({ error: "word is required" }, 400);

  const apiKey = Deno.env.get("OPENAI_API_KEY");
  let explanation: Record<string, unknown>;

  if (!apiKey) {
    explanation = mockExplanation(word, readingLevel);
  } else {
    const prompt = `Explain the word "${word}" for a child reading at ${readingLevel} level. Context: ${body.context ?? "none"}. Return JSON with definition, kid_friendly_definition, example_sentence, image_prompt, syllables.`;
    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: Deno.env.get("OPENAI_VOCAB_MODEL") ?? "gpt-4o-mini",
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: "You create safe, concise vocabulary explanations for children. Return strict JSON only." },
          { role: "user", content: prompt },
        ],
      }),
    });
    if (!resp.ok) {
      explanation = {
        ...mockExplanation(word, readingLevel),
        provider_error: "OpenAI vocabulary generation failed; returning demo fallback.",
        provider_status: resp.status,
      };
    } else {
      const data = await resp.json();
      explanation = JSON.parse(data.choices?.[0]?.message?.content ?? "{}");
      explanation.word = word;
      explanation.mock = false;
    }
  }

  if (userId) {
    // Best-effort persistence. Service role bypasses RLS, but child ownership is enforced by DB FK/RLS for client writes elsewhere.
    try {
      await supabaseRest("vocabulary_lookups", {
        method: "POST",
        body: JSON.stringify({
          requester_id: userId,
          child_id: body.child_id ?? null,
          word,
          definition: String(explanation.kid_friendly_definition ?? explanation.definition ?? ""),
          example_sentence: explanation.example_sentence ?? null,
          image_prompt: explanation.image_prompt ?? null,
          source: explanation.mock ? "mock" : "openai",
          metadata: explanation,
        }),
      });
    } catch (_err) {
      // Keep function useful in local/demo mode even if database env is absent.
    }
  }

  return jsonResponse(explanation);
});
