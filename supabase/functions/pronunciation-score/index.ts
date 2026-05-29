import { handleOptions, jsonResponse, readJson, tokenize } from "../_shared/common.ts";

type ScoreRequest = {
  expected_text?: string;
  spoken_text?: string;
  word?: string;
  child_id?: string;
  session_id?: string;
};

function levenshtein(a: string, b: string): number {
  const dp = Array.from({ length: a.length + 1 }, () => Array(b.length + 1).fill(0));
  for (let i = 0; i <= a.length; i++) dp[i][0] = i;
  for (let j = 0; j <= b.length; j++) dp[0][j] = j;
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      dp[i][j] = Math.min(
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
      );
    }
  }
  return dp[a.length][b.length];
}

function localScore(expected: string, spoken: string) {
  const expectedWords = tokenize(expected);
  const spokenWords = tokenize(spoken);
  const expectedJoined = expectedWords.join(" ");
  const spokenJoined = spokenWords.join(" ");
  const distance = levenshtein(expectedJoined, spokenJoined);
  const maxLen = Math.max(expectedJoined.length, spokenJoined.length, 1);
  const similarity = Math.max(0, 1 - distance / maxLen);
  const correctWords = expectedWords.filter((w, i) => w === spokenWords[i]).length;
  return {
    score: Math.round(similarity * 10000) / 100,
    is_correct: similarity >= 0.82,
    expected_words: expectedWords.length,
    spoken_words: spokenWords.length,
    correct_words: correctWords,
    difficult_words: expectedWords.filter((w, i) => w !== spokenWords[i]),
    mock: true,
  };
}

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  const body = await readJson<ScoreRequest>(req);
  const expected = String(body.expected_text ?? body.word ?? "").trim();
  const spoken = String(body.spoken_text ?? "").trim();
  if (!expected || !spoken) return jsonResponse({ error: "expected_text and spoken_text are required" }, 400);

  // MVP orchestration: deterministic local scoring plus a hook for future specialist scoring providers.
  // Keep secrets server-side; clients never call external AI services directly.
  const providerUrl = Deno.env.get("PRONUNCIATION_SCORER_URL");
  const providerKey = Deno.env.get("PRONUNCIATION_SCORER_KEY");
  if (providerUrl && providerKey) {
    const resp = await fetch(providerUrl, {
      method: "POST",
      headers: { Authorization: `Bearer ${providerKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ expected_text: expected, spoken_text: spoken, child_id: body.child_id, session_id: body.session_id }),
    });
    if (resp.ok) return jsonResponse({ ...(await resp.json()), mock: false });
  }

  return jsonResponse(localScore(expected, spoken));
});
