# Peekaboo MVP architecture

## Goals

Peekaboo MVP is a tablet-first reading app for children with a calm E Ink-inspired experience. The architecture keeps the child-facing app simple, uses Supabase as the managed backend, and avoids a custom Node.js server.

Primary goals:

- Render EPUB books in a child-friendly reading interface.
- Support tap-word vocabulary help.
- Demonstrate read-aloud pronunciation feedback using Whisper.
- Give parents a basic dashboard for progress and assignments.
- Keep privacy, RLS, and family isolation central to the data model.
- Isolate E Ink refresh behavior behind an app-level abstraction.

Non-goals for MVP:

- General web browsing or open book marketplace.
- Complex learning analytics or diagnosis.
- Real-time multiplayer/collaboration.
- A separate Node.js/Express backend.

## System overview

```text
Android tablet Flutter app
  ├─ Reading UI and EPUB rendering
  ├─ E Ink-style theme and refresh controller
  ├─ Audio recording for read-aloud attempts
  ├─ Vocabulary popup and saved-word UI
  └─ Parent dashboard
        │
        ▼
Supabase
  ├─ Auth
  ├─ Postgres schema + RLS
  ├─ Storage: epubs, audio-attempts, book-assets
  └─ Edge Functions
      ├─ whisper-feedback
      ├─ vocabulary-lookup
      └─ parent-summary
        │
        ▼
External providers where needed
  ├─ Whisper transcription API
  └─ Dictionary/vocabulary source, optional
```

## Flutter app architecture

Expected app root: the repository root when `pubspec.yaml` is at the top level, or `app/` when the Flutter project is nested. The verification script auto-detects both layouts.

Recommended module boundaries:

- `lib/main.dart` initializes configuration, Supabase client, routing, and theme.
- `lib/theme/` contains typography, colors, spacing, and low-motion widget defaults.
- `lib/eink/` contains display refresh abstractions such as `EinkRefreshController`, `RefreshMode`, and platform adapters.
- `lib/reading/` contains EPUB parsing, document model, pagination, page controls, and reading progress persistence.
- `lib/aloud/` contains recording, upload, transcript alignment, and feedback display.
- `lib/vocabulary/` contains word selection, popup UI, lookup repository, and saved-word state.
- `lib/parent/` contains parent dashboard screens and repository methods.
- `lib/supabase/` contains typed client wrappers and DTO mapping.

Recommended dependency direction:

```text
screens/widgets -> feature controllers -> repositories -> Supabase/Edge Functions
              \-> E Ink refresh interface
```

Feature code should depend on an E Ink interface, not on direct platform calls. This keeps the app usable on ordinary Android tablets while allowing future device-specific refresh behavior.

## Supabase architecture

Supabase is the only backend for MVP.

Expected directories:

- `supabase/migrations/` for schema, RLS, helper functions, and storage policies.
- `supabase/functions/whisper-feedback/` for read-aloud transcription and feedback.
- `supabase/functions/vocabulary-lookup/` for dictionary lookup and child-safe simplification.
- `supabase/functions/parent-summary/` for aggregated parent dashboard data.

### Suggested tables

The verification script looks for these table names in SQL migrations because they represent the MVP data model:

- `families` - parent/child family boundary.
- `profiles` - user profile rows tied to Supabase Auth users.
- `children` - child reader records, owned by a family.
- `books` - metadata for uploaded/assigned books.
- `book_assignments` - parent assignment of books to children.
- `reading_sessions` - session-level reading activity.
- `reading_progress` - latest location/progress per child/book.
- `vocabulary_words` - saved or looked-up words.
- `pronunciation_attempts` - read-aloud attempts and feedback summaries.

Optional supporting tables:

- `book_assets` for covers/images/extracted resources.
- `epub_locations` for normalized EPUB CFI/page map records.
- `parent_events` for coarse audit trail of parent actions.

### RLS expectations

All family-scoped tables should enable RLS. Policies should enforce:

- A parent can access records for their own family only.
- A child can access their own assigned books, progress, vocabulary, and attempts only.
- Service-role operations are limited to Edge Functions and administrative migrations.
- Storage object paths include family and/or child IDs where possible.

### Storage expectations

Recommended buckets (or current migration equivalents):

- `ebooks`/`epubs`: parent-uploaded EPUB/book files.
- `audio-snippets`/`audio-attempts`: short recordings used for pronunciation feedback.
- `word-images`/`book-assets`: generated vocabulary images, covers, or extracted assets.

Storage policies should mirror table-level family isolation. Audio should have an explicit retention strategy.

## Feature flows

### EPUB reading

1. Parent uploads or assigns a book.
2. App downloads the EPUB if needed.
3. Reading module parses spine/chapters and builds a page model.
4. Reader screen displays pages using E Ink theme tokens.
5. Page turns update local state immediately and persist progress asynchronously.
6. Progress is visible in the parent dashboard.

### Tap-word vocabulary

1. Reader text spans expose word tap targets.
2. App normalizes selected word and surrounding sentence.
3. App first checks cached/saved vocabulary.
4. If missing, app calls `vocabulary-lookup`.
5. Popup displays definition, simple example, pronunciation if available, and save action.
6. Saved words are written to `vocabulary_words`.

Child-safety rule: definitions should be age-appropriate and should avoid unrestricted web content.

### Read-aloud pronunciation feedback

1. App selects a short passage already visible to the child.
2. Child records audio for that passage.
3. App uploads audio or sends it to `whisper-feedback`.
4. Function transcribes with Whisper and compares transcript to expected text.
5. Function stores a `pronunciation_attempts` row with transcript, score/flags, and feedback summary.
6. App displays encouraging feedback such as “Great effort — try the word ‘forest’ again.”

The MVP should avoid clinical language. It should not claim to diagnose speech or reading ability.

### Parent dashboard

1. Parent opens dashboard.
2. App calls read repositories and/or `parent-summary`.
3. Dashboard shows active books, reading streak/session summaries, saved vocabulary, and recent read-aloud attempts.
4. Parent can review progress and assign books.

## Performance targets

- App cold start to library: < 3 seconds on a mid-range Android tablet.
- Cached page turn: < 150 ms.
- Uncached page layout: < 500 ms for typical chapter pages.
- Tap-word popup: < 300 ms cached, < 1.5 seconds network lookup.
- Read-aloud feedback: < 10 seconds for a short passage over typical Wi-Fi.
- Dashboard load: < 2 seconds for a single family with typical MVP data volume.

Implementation recommendations:

- Cache parsed EPUB spine and page maps locally.
- Persist reading progress optimistically and retry on network failure.
- Keep vocabulary lookup cancellable and debounced.
- Limit audio clip length for the demo.
- Avoid frequent full-screen rebuilds during page turns.

## Security and privacy

- Use Supabase anon key in the app; never ship service-role keys.
- Enforce RLS on all user/family data.
- Store only the minimum audio/text required for read-aloud feedback.
- Prefer signed URLs for private Storage access.
- Keep child-facing content constrained to parent-provided books and vetted definitions.
- Make retention/deletion behavior explicit for audio attempts.

## Verification

Run:

```bash
python3 scripts/verify_project.py
```

The verifier checks documentation, expected Flutter paths, Supabase migrations, Edge Function directories, key schema tables, storage references, E Ink abstraction files, and absence of common Node.js backend markers.
