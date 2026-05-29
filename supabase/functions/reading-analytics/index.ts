import { getAuthUserId, handleOptions, jsonResponse, readJson, supabaseRest } from "../_shared/common.ts";

type AnalyticsRequest = {
  session_id?: string;
  child_id?: string;
  book_id?: string;
  duration_seconds?: number;
  words_read?: number;
  correct_words?: number;
  difficult_words?: string[];
  ended_at?: string;
};

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  const userId = await getAuthUserId(req);
  if (!userId) return jsonResponse({ error: "Unauthorized" }, 401);

  const body = await readJson<AnalyticsRequest>(req);
  if (!body.child_id) return jsonResponse({ error: "child_id is required" }, 400);

  const duration = Math.max(0, Math.round(Number(body.duration_seconds ?? 0)));
  const wordsRead = Math.max(0, Math.round(Number(body.words_read ?? 0)));
  const correctWords = Math.min(wordsRead, Math.max(0, Math.round(Number(body.correct_words ?? 0))));
  const accuracy = wordsRead > 0 ? Math.round((correctWords / wordsRead) * 10000) / 100 : null;
  const minutesRead = Math.ceil(duration / 60);
  const metricDate = new Date(body.ended_at ?? Date.now()).toISOString().slice(0, 10);

  const analytics = {
    minutes_read: minutesRead,
    words_read: wordsRead,
    correct_words: correctWords,
    average_accuracy: accuracy,
    difficult_words_count: body.difficult_words?.length ?? 0,
  };

  try {
    if (body.session_id) {
      await supabaseRest(`reading_sessions?id=eq.${encodeURIComponent(body.session_id)}`, {
        method: "PATCH",
        body: JSON.stringify({
          status: "completed",
          ended_at: body.ended_at ?? new Date().toISOString(),
          duration_seconds: duration,
          words_read: wordsRead,
          correct_words: correctWords,
          analytics,
        }),
      });
    }

    await supabaseRest("parent_dashboard_metrics?on_conflict=parent_id,child_id,metric_date", {
      method: "POST",
      headers: { Prefer: "resolution=merge-duplicates,return=representation" },
      body: JSON.stringify({
        parent_id: userId,
        child_id: body.child_id,
        metric_date: metricDate,
        minutes_read: minutesRead,
        sessions_count: 1,
        words_read: wordsRead,
        average_accuracy: accuracy,
        difficult_words_count: body.difficult_words?.length ?? 0,
        metadata: { last_session_id: body.session_id ?? null },
      }),
    });

    for (const word of body.difficult_words ?? []) {
      await supabaseRest("difficult_words?on_conflict=child_id,normalized_word", {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
        body: JSON.stringify({
          child_id: body.child_id,
          word,
          attempts: 1,
          misses: 1,
          last_attempt_at: new Date().toISOString(),
        }),
      });
    }
  } catch (err) {
    return jsonResponse({ ...analytics, persisted: false, warning: String(err) });
  }

  return jsonResponse({ ...analytics, persisted: true });
});
