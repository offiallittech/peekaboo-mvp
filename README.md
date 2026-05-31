# Peekaboo MVP

Peekaboo is an Android tablet-first reading companion for children. The MVP combines an E Ink-inspired Flutter interface, an EPUB reading flow, read-aloud pronunciation feedback powered by Whisper, tap-word vocabulary support, a basic parent dashboard, and a Supabase backend for auth, storage, reading telemetry, vocabulary, and pronunciation attempts.

This repository is intended to contain only the Flutter tablet app and Supabase project assets. The MVP intentionally does **not** include a Node.js backend; server-side behavior should live in Supabase Postgres, Storage, Row Level Security (RLS), and Edge Functions.

## MVP deliverables

- Android tablet Flutter app source.
- E Ink-style UI theme with low-glare palette, limited motion, large touch targets, and page-refresh abstraction.
- EPUB import/open/read flow.
- Read-aloud pronunciation feedback demo using Whisper transcription.
- Tap-word vocabulary popup with simple definitions and parent-visible saved words.
- Basic parent dashboard showing reading sessions, pronunciation attempts, vocabulary, and progress summaries.
- Supabase schema, RLS policies, storage buckets, and Edge Functions.
- E Ink refresh abstraction documented and isolated from reading logic.
- Setup, architecture notes, and verification scripts.

## Expected repository layout

```text
peekaboo_mvp/
├── README.md
├── pubspec.yaml                 # Flutter app may live at repo root
├── android/
├── lib/
│   ├── main.dart
│   ├── theme/                   # E Ink visual tokens and widgets
│   ├── reading/                 # EPUB reader, pagination, tap-word flow
│   ├── aloud/                   # Recording + Whisper feedback demo
│   ├── vocabulary/              # Vocabulary popup and saved words
│   ├── parent/                  # Parent dashboard
│   ├── eink/                    # Refresh abstraction
│   └── supabase/                # Client/repository integrations
├── test/
├── supabase/
│   ├── migrations/              # SQL schema, RLS, functions, storage policies
│   ├── functions/
│   │   ├── whisper-stt/ and whisper-feedback/ alias
│   │   ├── pronunciation-score/
│   │   ├── vocabulary-explanation/ and vocabulary-lookup/ alias
│   │   ├── secure-api/
│   │   └── parent-summary/
│   └── seed.sql                 # Optional local demo seed data
├── docs/
│   ├── architecture.md
│   └── eink.md
└── scripts/
    └── verify_project.py
```

If the Flutter app is nested under `app/` instead, keep the same Flutter substructure under `app/`. The verification script auto-detects either `pubspec.yaml` at the repository root or `app/pubspec.yaml`.

## Setup

### Prerequisites

- Flutter stable channel with Android toolchain installed.
- Android Studio or Android SDK command-line tools.
- Supabase CLI.
- A Supabase project for deployed testing, or local Supabase for development.
- OpenAI-compatible Whisper transcription API key for the read-aloud demo Edge Function.

### 1. Configure Supabase

1. Create a Supabase project.
2. Apply migrations from `supabase/migrations/`.
3. Create Storage buckets documented by the migrations/policies. The current MVP schema may use these names:
   - `ebooks` (or `epubs`) for parent-uploaded EPUB/book files.
   - `audio-snippets` (or `audio-attempts`) for short read-aloud recordings.
   - `word-images` (or `book-assets`) for generated vocabulary/book assets when needed.
4. Deploy Edge Functions:

```bash
supabase functions deploy whisper-stt
supabase functions deploy pronunciation-score
supabase functions deploy vocabulary-explanation
supabase functions deploy secure-api
supabase functions deploy parent-summary
# Optional compatibility aliases used by the verifier/docs:
supabase functions deploy whisper-feedback
supabase functions deploy vocabulary-lookup
```

5. Configure function secrets:

```bash
supabase secrets set OPENAI_API_KEY=...
supabase secrets set OPENAI_TRANSCRIPTION_MODEL=whisper-1 # optional
supabase secrets set VOCABULARY_PROVIDER_KEY=... # optional if using an external dictionary
```

### 2. Configure Flutter app

Create the app environment file expected by the implementation, for example:

```text
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

The app should use the public anon key only. Privileged writes, transcription calls, and parent summaries should be mediated by RLS and Edge Functions.

### 3. Run locally

```bash
flutter pub get
flutter test
flutter run -d <android-tablet-device-id>
```

For an Android debug APK configured with `SUPABASE_URL` and `SUPABASE_ANON_KEY` from `.env`, run:

```bash
scripts/build_android_configured.sh
```

### 4. Verify repository completeness

From the repository root:

```bash
python3 scripts/verify_project.py
```

The verifier checks for required documentation, Flutter app files, Supabase schema/function assets, expected schema tables, E Ink abstractions, and absence of a Node.js backend.

## Core user flows

### Child reading flow

1. Child opens an assigned book.
2. EPUB content is parsed and displayed as paginated high-contrast pages.
3. Child turns pages using tap zones or simple controls.
4. Progress is saved to Supabase.
5. Tapping a word opens a vocabulary popup with child-safe definition and save option.

### Read-aloud feedback demo

1. Child taps read-aloud mode for a short passage.
2. App records a brief audio attempt.
3. Audio is uploaded to `audio-attempts` or sent through a Supabase Edge Function.
4. `whisper-stt` calls Whisper; `pronunciation-score` aligns transcript with the expected passage and returns simple feedback. `whisper-feedback` remains as a compatibility alias.
5. App displays encouraging, non-punitive pronunciation hints.

### Parent dashboard

1. Parent signs in with a parent role/profile.
2. Dashboard displays child reading sessions, active books, saved words, and recent pronunciation attempts.
3. Parent can assign books and review progress summaries.

## Performance targets

- Cold start to usable library screen: under 3 seconds on a mid-range Android tablet.
- Page turn response: under 150 ms for cached pages; under 500 ms when layout must be recalculated.
- Vocabulary popup display after tapping a word: under 300 ms with cached lookup; under 1.5 seconds with network lookup.
- Read-aloud recording upload and feedback: under 10 seconds for short demo passages on typical Wi-Fi.
- Offline reading: already-downloaded EPUB text and last-known progress remain available without network.
- Battery/display comfort: minimal animations, no auto-playing media, and no rapid full-screen flashing.

## Child safety and privacy decisions

- Child accounts should expose only minimal profile data.
- RLS must prevent one family from seeing another family's books, recordings, vocabulary, or progress.
- Audio recordings should be short, purpose-limited, and deleted or retained according to an explicit retention policy.
- Feedback copy should be encouraging and should not rank, shame, or diagnose children.
- Parent dashboard is for supportive progress visibility, not surveillance-style detailed behavioral tracking.
- External AI/dictionary providers should receive the minimum text/audio required for the feature.
- EPUB uploads should be parent-controlled; child browsing of arbitrary external catalogs is out of scope for MVP.

## Documentation

- [`docs/architecture.md`](docs/architecture.md) explains app/backend architecture, data model, flows, and verification expectations.
- [`docs/eink.md`](docs/eink.md) documents the E Ink-style UI approach and refresh abstraction.

## Verification status

Run `python3 scripts/verify_project.py` after implementing the app and Supabase assets. The script exits non-zero when required MVP assets are missing or when a Node.js backend is detected.
