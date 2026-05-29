-- Peekaboo MVP Supabase schema, row-level security, and storage setup.
-- Backend is Supabase-only: Auth + Postgres + Storage + Deno Edge Functions.

create extension if not exists pgcrypto;
create extension if not exists citext;

-- ---------- Types ----------
do $$ begin
  create type public.user_role as enum ('parent', 'educator', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.book_visibility as enum ('public', 'private');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.upload_status as enum ('pending', 'processing', 'ready', 'failed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.session_status as enum ('started', 'completed', 'abandoned');
exception when duplicate_object then null; end $$;

-- ---------- Utility functions ----------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  );
$$;

-- ---------- Core identity ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email citext,
  display_name text not null default 'Peekaboo Parent',
  avatar_url text,
  role public.user_role not null default 'parent',
  onboarding_complete boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1), 'Peekaboo Parent')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ---------- Children ----------
create table if not exists public.children (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid not null references public.profiles(id) on delete cascade,
  display_name text not null,
  avatar_url text,
  birth_year int check (birth_year between 2000 and extract(year from now())::int),
  reading_level text default 'beginner',
  locale text not null default 'en-US',
  daily_goal_minutes int not null default 10 check (daily_goal_minutes between 1 and 240),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists children_parent_id_idx on public.children(parent_id);
create trigger children_set_updated_at
before update on public.children
for each row execute function public.set_updated_at();

create or replace function public.is_parent_of_child(child_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.children c
    where c.id = child_uuid and c.parent_id = auth.uid()
  ) or public.is_admin();
$$;

-- ---------- Books and uploads ----------
create table if not exists public.books (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete set null,
  title text not null,
  author text,
  description text,
  cover_image_url text,
  storage_path text,
  visibility public.book_visibility not null default 'private',
  language text not null default 'en',
  reading_level text default 'beginner',
  word_count int not null default 0 check (word_count >= 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint books_owner_required_for_private check (visibility = 'public' or owner_id is not null)
);

create index if not exists books_owner_id_idx on public.books(owner_id);
create index if not exists books_visibility_idx on public.books(visibility);
create trigger books_set_updated_at
before update on public.books
for each row execute function public.set_updated_at();

create table if not exists public.book_uploads (
  id uuid primary key default gen_random_uuid(),
  uploader_id uuid not null references public.profiles(id) on delete cascade,
  book_id uuid references public.books(id) on delete set null,
  original_filename text not null,
  storage_path text not null,
  mime_type text,
  size_bytes bigint check (size_bytes is null or size_bytes >= 0),
  status public.upload_status not null default 'pending',
  error_message text,
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists book_uploads_uploader_id_idx on public.book_uploads(uploader_id);
create trigger book_uploads_set_updated_at
before update on public.book_uploads
for each row execute function public.set_updated_at();

create or replace function public.can_access_book(book_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.books b
    where b.id = book_uuid
      and (b.visibility = 'public' or b.owner_id = auth.uid() or public.is_admin())
  );
$$;

-- ---------- Reading activity ----------
create table if not exists public.reading_progress (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  current_location text,
  current_page int check (current_page is null or current_page >= 0),
  percent_complete numeric(5,2) not null default 0 check (percent_complete between 0 and 100),
  last_read_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(child_id, book_id)
);

create index if not exists reading_progress_child_id_idx on public.reading_progress(child_id);
create trigger reading_progress_set_updated_at
before update on public.reading_progress
for each row execute function public.set_updated_at();

create table if not exists public.reading_sessions (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  status public.session_status not null default 'started',
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  duration_seconds int check (duration_seconds is null or duration_seconds >= 0),
  words_read int not null default 0 check (words_read >= 0),
  correct_words int not null default 0 check (correct_words >= 0),
  accuracy numeric(5,2) generated always as (
    case when words_read > 0 then round((correct_words::numeric / words_read::numeric) * 100, 2) else null end
  ) stored,
  transcript text,
  audio_storage_path text,
  analytics jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint correct_words_lte_words_read check (correct_words <= words_read)
);

create index if not exists reading_sessions_child_id_idx on public.reading_sessions(child_id);
create index if not exists reading_sessions_book_id_idx on public.reading_sessions(book_id);
create trigger reading_sessions_set_updated_at
before update on public.reading_sessions
for each row execute function public.set_updated_at();

create table if not exists public.word_attempts (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.reading_sessions(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  book_id uuid references public.books(id) on delete set null,
  word text not null,
  expected_text text,
  spoken_text text,
  is_correct boolean,
  confidence numeric(4,3) check (confidence is null or confidence between 0 and 1),
  pronunciation_score numeric(5,2) check (pronunciation_score is null or pronunciation_score between 0 and 100),
  audio_storage_path text,
  position_index int check (position_index is null or position_index >= 0),
  attempted_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists word_attempts_child_word_idx on public.word_attempts(child_id, lower(word));
create index if not exists word_attempts_session_id_idx on public.word_attempts(session_id);

create table if not exists public.difficult_words (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  word text not null,
  normalized_word text generated always as (lower(regexp_replace(word, '[^[:alnum:]]', '', 'g'))) stored,
  attempts int not null default 0 check (attempts >= 0),
  misses int not null default 0 check (misses >= 0),
  last_attempt_at timestamptz,
  mastered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(child_id, normalized_word),
  constraint misses_lte_attempts check (misses <= attempts)
);

create index if not exists difficult_words_child_id_idx on public.difficult_words(child_id);
create trigger difficult_words_set_updated_at
before update on public.difficult_words
for each row execute function public.set_updated_at();

create table if not exists public.vocabulary_lookups (
  id uuid primary key default gen_random_uuid(),
  child_id uuid references public.children(id) on delete cascade,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  word text not null,
  normalized_word text generated always as (lower(regexp_replace(word, '[^[:alnum:]]', '', 'g'))) stored,
  definition text not null,
  example_sentence text,
  image_prompt text,
  source text not null default 'openai-or-mock',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists vocabulary_lookups_requester_id_idx on public.vocabulary_lookups(requester_id);
create index if not exists vocabulary_lookups_child_id_idx on public.vocabulary_lookups(child_id);

create table if not exists public.parent_dashboard_metrics (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid not null references public.profiles(id) on delete cascade,
  child_id uuid references public.children(id) on delete cascade,
  metric_date date not null default current_date,
  minutes_read int not null default 0 check (minutes_read >= 0),
  sessions_count int not null default 0 check (sessions_count >= 0),
  words_read int not null default 0 check (words_read >= 0),
  average_accuracy numeric(5,2) check (average_accuracy is null or average_accuracy between 0 and 100),
  difficult_words_count int not null default 0 check (difficult_words_count >= 0),
  streak_days int not null default 0 check (streak_days >= 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(parent_id, child_id, metric_date)
);

create index if not exists parent_dashboard_metrics_parent_date_idx on public.parent_dashboard_metrics(parent_id, metric_date desc);
create trigger parent_dashboard_metrics_set_updated_at
before update on public.parent_dashboard_metrics
for each row execute function public.set_updated_at();

-- ---------- RLS ----------
alter table public.profiles enable row level security;
alter table public.children enable row level security;
alter table public.books enable row level security;
alter table public.book_uploads enable row level security;
alter table public.reading_progress enable row level security;
alter table public.reading_sessions enable row level security;
alter table public.word_attempts enable row level security;
alter table public.difficult_words enable row level security;
alter table public.vocabulary_lookups enable row level security;
alter table public.parent_dashboard_metrics enable row level security;

-- Profiles
create policy "profiles_select_own_or_admin" on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy "profiles_insert_own" on public.profiles for insert with check (id = auth.uid());
create policy "profiles_update_own" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

-- Children
create policy "children_parent_crud" on public.children for all using (parent_id = auth.uid() or public.is_admin()) with check (parent_id = auth.uid() or public.is_admin());

-- Books
create policy "books_select_public_or_owner" on public.books for select using (visibility = 'public' or owner_id = auth.uid() or public.is_admin());
create policy "books_insert_owner" on public.books for insert with check (owner_id = auth.uid() or (visibility = 'public' and public.is_admin()));
create policy "books_update_owner" on public.books for update using (owner_id = auth.uid() or public.is_admin()) with check (owner_id = auth.uid() or public.is_admin());
create policy "books_delete_owner" on public.books for delete using (owner_id = auth.uid() or public.is_admin());

-- Book uploads
create policy "book_uploads_owner_crud" on public.book_uploads for all using (uploader_id = auth.uid() or public.is_admin()) with check (uploader_id = auth.uid() or public.is_admin());

-- Reading progress/session data: parent can access own children, only for accessible books.
create policy "reading_progress_parent_crud" on public.reading_progress for all
  using (public.is_parent_of_child(child_id) and public.can_access_book(book_id))
  with check (public.is_parent_of_child(child_id) and public.can_access_book(book_id));

create policy "reading_sessions_parent_crud" on public.reading_sessions for all
  using (public.is_parent_of_child(child_id) and public.can_access_book(book_id))
  with check (public.is_parent_of_child(child_id) and public.can_access_book(book_id));

create policy "word_attempts_parent_crud" on public.word_attempts for all
  using (public.is_parent_of_child(child_id) and (book_id is null or public.can_access_book(book_id)))
  with check (public.is_parent_of_child(child_id) and (book_id is null or public.can_access_book(book_id)));

create policy "difficult_words_parent_crud" on public.difficult_words for all
  using (public.is_parent_of_child(child_id))
  with check (public.is_parent_of_child(child_id));

create policy "vocabulary_lookups_parent_crud" on public.vocabulary_lookups for all
  using (requester_id = auth.uid() and (child_id is null or public.is_parent_of_child(child_id)) or public.is_admin())
  with check (requester_id = auth.uid() and (child_id is null or public.is_parent_of_child(child_id)) or public.is_admin());

create policy "parent_dashboard_metrics_parent_crud" on public.parent_dashboard_metrics for all
  using (parent_id = auth.uid() and (child_id is null or public.is_parent_of_child(child_id)) or public.is_admin())
  with check (parent_id = auth.uid() and (child_id is null or public.is_parent_of_child(child_id)) or public.is_admin());

-- ---------- Storage buckets and policies ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('ebooks', 'ebooks', false, 52428800, array['application/pdf', 'application/epub+zip', 'text/plain']::text[]),
  ('word-images', 'word-images', false, 10485760, array['image/png', 'image/jpeg', 'image/webp']::text[]),
  ('audio-snippets', 'audio-snippets', false, 26214400, array['audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/webm', 'audio/ogg']::text[])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Convention: user-owned files live under <auth.uid()>/... ; child audio may use <auth.uid()>/<child_id>/...
create policy "ebooks_owner_read" on storage.objects for select
  using (bucket_id = 'ebooks' and (auth.uid()::text = (storage.foldername(name))[1] or public.is_admin()));
create policy "ebooks_owner_write" on storage.objects for insert
  with check (bucket_id = 'ebooks' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "ebooks_owner_update" on storage.objects for update
  using (bucket_id = 'ebooks' and auth.uid()::text = (storage.foldername(name))[1])
  with check (bucket_id = 'ebooks' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "ebooks_owner_delete" on storage.objects for delete
  using (bucket_id = 'ebooks' and (auth.uid()::text = (storage.foldername(name))[1] or public.is_admin()));

create policy "word_images_owner_read" on storage.objects for select
  using (bucket_id = 'word-images' and (auth.uid()::text = (storage.foldername(name))[1] or public.is_admin()));
create policy "word_images_owner_write" on storage.objects for insert
  with check (bucket_id = 'word-images' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "word_images_owner_update" on storage.objects for update
  using (bucket_id = 'word-images' and auth.uid()::text = (storage.foldername(name))[1])
  with check (bucket_id = 'word-images' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "word_images_owner_delete" on storage.objects for delete
  using (bucket_id = 'word-images' and (auth.uid()::text = (storage.foldername(name))[1] or public.is_admin()));

create policy "audio_snippets_owner_read" on storage.objects for select
  using (bucket_id = 'audio-snippets' and (auth.uid()::text = (storage.foldername(name))[1] or public.is_admin()));
create policy "audio_snippets_owner_write" on storage.objects for insert
  with check (bucket_id = 'audio-snippets' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "audio_snippets_owner_update" on storage.objects for update
  using (bucket_id = 'audio-snippets' and auth.uid()::text = (storage.foldername(name))[1])
  with check (bucket_id = 'audio-snippets' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "audio_snippets_owner_delete" on storage.objects for delete
  using (bucket_id = 'audio-snippets' and (auth.uid()::text = (storage.foldername(name))[1] or public.is_admin()));
