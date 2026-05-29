# Peekaboo MVP Supabase Backend

This folder contains the Supabase-only backend deliverables for the Peekaboo MVP:

- Auth-backed `profiles` created from `auth.users`
- Parent/child data tables with row-level security (RLS)
- Book catalog and upload tracking
- Reading progress, sessions, word attempts, difficult words, vocabulary lookups, and dashboard metrics
- Private Storage buckets: `ebooks`, `word-images`, `audio-snippets`
- Deno TypeScript Edge Functions with mock fallback when secrets are missing

## Local setup

```bash
supabase start
supabase db reset
```

Required production secrets:

```bash
supabase secrets set OPENAI_API_KEY=...
supabase secrets set SUPABASE_URL=...
supabase secrets set SUPABASE_ANON_KEY=...
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...
```

Optional pronunciation provider secrets:

```bash
supabase secrets set PRONUNCIATION_SCORER_URL=...
supabase secrets set PRONUNCIATION_SCORER_KEY=...
```

## Edge Functions

Deploy with:

```bash
supabase functions deploy whisper-stt
supabase functions deploy vocabulary-explanation
supabase functions deploy pronunciation-score
supabase functions deploy reading-analytics
supabase functions deploy secure-api
```

Functions use `Deno.serve`; no Node.js backend is required. If `OPENAI_API_KEY` or optional provider secrets are absent, functions return deterministic mock/demo responses rather than failing.

## Storage path convention

Private bucket object names should start with the authenticated user ID (inside each bucket):

```text
ebooks bucket:          <auth.uid()>/<filename>
word-images bucket:     <auth.uid()>/<word>.webp
audio-snippets bucket:  <auth.uid()>/<child_id>/<session_id>.webm
```

RLS/storage policies enforce parent-owned access to child data and user-prefixed file paths.
