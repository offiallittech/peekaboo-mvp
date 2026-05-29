
import { corsHeaders, jsonResponse } from '../_shared/common.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  return jsonResponse({
    duration_seconds: 842,
    words_read: 186,
    pronunciation_accuracy: 0.82,
    reading_streak: 4,
    difficult_words: ['silver', 'garden', 'whispered'],
    message: 'Demo parent summary. Production reads parent_dashboard_metrics with RLS.'
  });
});

export default {};
