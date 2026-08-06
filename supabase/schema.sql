-- ============================================================
-- Job-Ready Portal — schema
-- Run this in the Supabase SQL editor (or via supabase db push)
-- ============================================================

create extension if not exists "pgcrypto";

-- ---------- profiles (one row per auth.users, one login per student) ----------
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  stream text not null check (stream in ('BCA','BTech','MCA','MTech','Other')),
  college text,
  created_at timestamptz default now()
);

-- ---------- courses (generic — any stream, any subject) ----------
create table if not exists courses (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  description text,
  is_published boolean not null default true,
  order_index int not null default 0,
  created_at timestamptz default now()
);

create table if not exists modules (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses(id) on delete cascade,
  title text not null,
  order_index int not null default 0
);

create table if not exists lessons (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references modules(id) on delete cascade,
  title text not null,
  content text,          -- markdown body
  video_url text,        -- youtube/vimeo embed URL
  order_index int not null default 0
);

-- ---------- quiz ----------
create table if not exists quizzes (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses(id) on delete cascade,
  title text not null default 'Final Test',
  passing_score int not null default 70 -- percent
);

create table if not exists questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references quizzes(id) on delete cascade,
  question text not null,
  options jsonb not null,      -- e.g. ["A","B","C","D"]
  correct_index int not null,  -- 0-based index into options
  order_index int not null default 0
);

-- ---------- student activity ----------
create table if not exists enrollments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references profiles(id) on delete cascade,
  course_id uuid not null references courses(id) on delete cascade,
  enrolled_at timestamptz default now(),
  unique (student_id, course_id)
);

create table if not exists quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references profiles(id) on delete cascade,
  quiz_id uuid not null references quizzes(id) on delete cascade,
  score int not null,        -- percent
  passed boolean not null,
  submitted_at timestamptz default now()
);

create table if not exists certificates (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references profiles(id) on delete cascade,
  course_id uuid not null references courses(id) on delete cascade,
  certificate_code text unique not null default encode(gen_random_bytes(6), 'hex'),
  issued_at timestamptz default now(),
  unique (student_id, course_id)
);

-- ============================================================
-- Row Level Security
-- ============================================================
alter table profiles enable row level security;
alter table courses enable row level security;
alter table modules enable row level security;
alter table lessons enable row level security;
alter table quizzes enable row level security;
alter table questions enable row level security;
alter table enrollments enable row level security;
alter table quiz_attempts enable row level security;
alter table certificates enable row level security;

-- profiles: a student can read/update only their own profile
create policy "profile self read" on profiles for select using (auth.uid() = id);
create policy "profile self insert" on profiles for insert with check (auth.uid() = id);
create policy "profile self update" on profiles for update using (auth.uid() = id);

-- course content: any signed-in student can read published content
create policy "courses read" on courses for select using (is_published = true);
create policy "modules read" on modules for select using (
  exists (select 1 from courses c where c.id = modules.course_id and c.is_published)
);
create policy "lessons read" on lessons for select using (
  exists (
    select 1 from modules m join courses c on c.id = m.course_id
    where m.id = lessons.module_id and c.is_published
  )
);
create policy "quizzes read" on quizzes for select using (
  exists (select 1 from courses c where c.id = quizzes.course_id and c.is_published)
);
create policy "questions read" on questions for select using (
  exists (
    select 1 from quizzes q join courses c on c.id = q.course_id
    where q.id = questions.quiz_id and c.is_published
  )
);

-- enrollments: student manages their own
create policy "enrollments self all" on enrollments for all
  using (auth.uid() = student_id) with check (auth.uid() = student_id);

-- quiz attempts: student manages their own
create policy "attempts self all" on quiz_attempts for all
  using (auth.uid() = student_id) with check (auth.uid() = student_id);

-- certificates: student can read + insert their own
create policy "certificates self read" on certificates for select using (auth.uid() = student_id);
create policy "certificates self insert" on certificates for insert with check (auth.uid() = student_id);

-- ============================================================
-- Public verification view — only non-sensitive fields, no auth required
-- ============================================================
create or replace view certificate_public as
select
  cert.certificate_code,
  p.full_name as student_name,
  p.stream,
  c.title as course_title,
  cert.issued_at
from certificates cert
join profiles p on p.id = cert.student_id
join courses c on c.id = cert.course_id;

grant select on certificate_public to anon, authenticated;

-- ============================================================
-- Auto-create a profile row whenever a new auth user signs up.
-- Runs as SECURITY DEFINER so it bypasses RLS — this replaces
-- any client-side insert into `profiles`, which would otherwise
-- fail until the user's session is fully authenticated (e.g. if
-- email confirmation is required).
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, stream, college)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'stream', 'Other'),
    new.raw_user_meta_data->>'college'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
