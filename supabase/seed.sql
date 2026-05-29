-- Seed public demo catalog content. User/child-specific demo data should be created
-- through Supabase Auth so profile foreign keys point at real auth.users rows.

insert into public.books (
  id,
  owner_id,
  title,
  author,
  description,
  cover_image_url,
  storage_path,
  visibility,
  language,
  reading_level,
  word_count,
  metadata
) values
  (
    '11111111-1111-4111-8111-111111111111',
    null,
    'Milo and the Moon Kite',
    'Peekaboo Studio',
    'A gentle beginner story about Milo learning new moon words.',
    null,
    'public/milo-and-the-moon-kite.txt',
    'public',
    'en',
    'beginner',
    320,
    '{"themes":["friendship","night sky"],"demo":true}'::jsonb
  ),
  (
    '22222222-2222-4222-8222-222222222222',
    null,
    'Pip Finds a Rainbow',
    'Peekaboo Studio',
    'Short phonics-friendly passages for colors and nature words.',
    null,
    'public/pip-finds-a-rainbow.txt',
    'public',
    'en',
    'beginner',
    275,
    '{"themes":["colors","nature"],"demo":true}'::jsonb
  ),
  (
    '33333333-3333-4333-8333-333333333333',
    null,
    'The Secret Library Door',
    'Peekaboo Studio',
    'An early-reader adventure with richer vocabulary.',
    null,
    'public/the-secret-library-door.txt',
    'public',
    'en',
    'early-reader',
    610,
    '{"themes":["adventure","books"],"demo":true}'::jsonb
  )
on conflict (id) do update set
  title = excluded.title,
  author = excluded.author,
  description = excluded.description,
  visibility = excluded.visibility,
  language = excluded.language,
  reading_level = excluded.reading_level,
  word_count = excluded.word_count,
  metadata = excluded.metadata,
  updated_at = now();
