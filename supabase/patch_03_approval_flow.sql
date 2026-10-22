-- ============================================================
-- Patch 03 — categories, admin approval, access-gated content
-- Run AFTER schema.sql, the seeds, patch_01 and patch_02.
-- Safe to re-run.
--
-- Flow this enables:
--   register -> browse courses by category -> request access
--   -> admin approves -> student sees the course, learns day by day
--   -> finishes every lesson -> takes the test -> passes -> certificate
-- ============================================================

-- ------------------------------------------------------------
-- 1. Categories (courses are grouped by these in the catalog)
-- ------------------------------------------------------------
create table if not exists categories (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,
  name        text not null,
  order_index int not null default 0
);

alter table categories enable row level security;
drop policy if exists "categories read" on categories;
create policy "categories read" on categories for select using (true);

alter table courses add column if not exists category_id uuid references categories(id) on delete set null;

insert into categories (slug, name, order_index) values
  ('web-development', 'Web Development', 1),
  ('ai-data-science', 'AI & Data Science', 2),
  ('general', 'General', 99)
on conflict (slug) do nothing;

-- put the two existing courses in a category (only if not set yet)
update courses set category_id = (select id from categories where slug = 'web-development')
 where slug = 'mern-stack-foundations' and category_id is null;
update courses set category_id = (select id from categories where slug = 'ai-data-science')
 where slug = 'python-for-ai-21-days' and category_id is null;
-- anything else uncategorised lands in General
update courses set category_id = (select id from categories where slug = 'general')
 where category_id is null;

-- ------------------------------------------------------------
-- 2. Admins. A separate table, NOT a flag on profiles: students can
--    update their own profile row, so a profiles.is_admin column
--    would let anyone promote themselves.
--    RLS is on with no policies, so the API can never read or write it.
-- ------------------------------------------------------------
create table if not exists admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table admins enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;
grant execute on function public.is_admin() to anon, authenticated;

-- ------------------------------------------------------------
-- 3. Profiles: keep the email so the admin can tell students apart
-- ------------------------------------------------------------
alter table profiles add column if not exists email text;

update profiles p set email = u.email
from auth.users u
where u.id = p.id and p.email is null;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, stream, college, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'stream', 'Other'),
    new.raw_user_meta_data->>'college',
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop policy if exists "profile admin read" on profiles;
create policy "profile admin read" on profiles for select using (public.is_admin());

-- ------------------------------------------------------------
-- 4. Enrollments become requests: pending -> approved / rejected
-- ------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'enrollments' and column_name = 'status'
  ) then
    alter table enrollments
      add column status text not null default 'pending'
        check (status in ('pending', 'approved', 'rejected')),
      add column reviewed_at timestamptz,
      add column reviewed_by uuid references auth.users(id);

    -- One-time: enrollments that existed before this patch were already
    -- active students, so keep them approved.
    update enrollments set status = 'approved', reviewed_at = now();
  end if;
end $$;

drop policy if exists "enrollments self all"     on enrollments;
drop policy if exists "enrollments self read"    on enrollments;
drop policy if exists "enrollments self request" on enrollments;
drop policy if exists "enrollments self cancel"  on enrollments;
drop policy if exists "enrollments admin read"   on enrollments;
drop policy if exists "enrollments admin update" on enrollments;

-- a student sees their own requests
create policy "enrollments self read" on enrollments
  for select using (auth.uid() = student_id);

-- ...and can only ever file a PENDING request for themselves
create policy "enrollments self request" on enrollments
  for insert with check (
    auth.uid() = student_id and status = 'pending'
    and reviewed_at is null and reviewed_by is null
  );

-- ...and may withdraw a pending/rejected request (to re-request later),
-- but can never touch an approved one
create policy "enrollments self cancel" on enrollments
  for delete using (auth.uid() = student_id and status in ('pending', 'rejected'));

-- only admins review requests
create policy "enrollments admin read" on enrollments
  for select using (public.is_admin());
create policy "enrollments admin update" on enrollments
  for update using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- 5. Who may open a course's content?  Approved students + admins.
-- ------------------------------------------------------------
create or replace function public.has_course_access(p_course uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select public.is_admin()
      or exists (
        select 1 from public.enrollments e
        where e.student_id = auth.uid()
          and e.course_id  = p_course
          and e.status     = 'approved'
      );
$$;
grant execute on function public.has_course_access(uuid) to anon, authenticated;

-- lesson bodies and videos are only readable with access
drop policy if exists "lessons read" on lessons;
create policy "lessons read" on lessons for select using (
  exists (
    select 1 from modules m join courses c on c.id = m.course_id
    where m.id = lessons.module_id and c.is_published
      and public.has_course_access(c.id)
  )
);

-- questions follow the same rule
create or replace view questions_public as
select qs.id, qs.quiz_id, qs.question, qs.options, qs.order_index
from questions qs
join quizzes q on q.id = qs.quiz_id
join courses c on c.id = q.course_id
where c.is_published and public.has_course_access(c.id);
grant select on questions_public to authenticated;

-- A public syllabus (titles only, no content/video) so a student can see
-- what a course covers BEFORE requesting it.
create or replace view lesson_outline as
select l.id, l.module_id, l.title, l.order_index
from lessons l
join modules m on m.id = l.module_id
join courses c on c.id = m.course_id
where c.is_published;
grant select on lesson_outline to anon, authenticated;

-- ------------------------------------------------------------
-- 6. Pass mark is 40% (a student needs 40% or more)
-- ------------------------------------------------------------
alter table quizzes alter column passing_score set default 40;
update quizzes set passing_score = 40;

-- ------------------------------------------------------------
-- 7. submit_quiz(): add "approved for this course" on top of the
--    patch_02 rules (all lessons done, server-side scoring).
-- ------------------------------------------------------------
create or replace function public.submit_quiz(p_quiz_id uuid, p_answers jsonb)
returns table (score int, passed boolean, certificate_code text)
language plpgsql
security definer set search_path = public
as $$
declare
  v_user          uuid := auth.uid();
  v_course        uuid;
  v_pass          int;
  v_total         int;
  v_correct       int;
  v_score         int;
  v_passed        boolean;
  v_code          text;
  v_lesson_total  int;
  v_lesson_done   int;
begin
  if v_user is null then
    raise exception 'Not authenticated';
  end if;

  select q.course_id, q.passing_score
    into v_course, v_pass
  from quizzes q
  where q.id = p_quiz_id;

  if v_course is null then
    raise exception 'Quiz not found';
  end if;

  if not public.has_course_access(v_course) then
    raise exception 'Your access to this course has not been approved yet';
  end if;

  select count(*) into v_lesson_total
  from lessons l
  join modules m on m.id = l.module_id
  where m.course_id = v_course;

  select count(distinct lp.lesson_id) into v_lesson_done
  from lesson_progress lp
  join lessons l on l.id = lp.lesson_id
  join modules m on m.id = l.module_id
  where m.course_id = v_course and lp.student_id = v_user;

  if v_lesson_total > 0 and v_lesson_done < v_lesson_total then
    raise exception 'Complete all % lessons before taking the test (% done)',
      v_lesson_total, v_lesson_done;
  end if;

  select count(*) into v_total
  from questions
  where quiz_id = p_quiz_id;

  select count(*) into v_correct
  from questions qs
  where qs.quiz_id = p_quiz_id
    and (p_answers ->> qs.id::text)::int = qs.correct_index;

  v_score := case when v_total = 0 then 0
                  else round((v_correct::numeric / v_total) * 100) end;
  v_passed := v_score >= v_pass;

  insert into quiz_attempts (student_id, quiz_id, score, passed)
  values (v_user, p_quiz_id, v_score, v_passed);

  if v_passed then
    insert into certificates (student_id, course_id)
    values (v_user, v_course)
    on conflict (student_id, course_id) do nothing;

    select c.certificate_code into v_code
    from certificates c
    where c.student_id = v_user and c.course_id = v_course;
  end if;

  return query select v_score, v_passed, v_code;
end;
$$;

revoke all on function public.submit_quiz(uuid, jsonb) from public, anon;
grant execute on function public.submit_quiz(uuid, jsonb) to authenticated;

-- ------------------------------------------------------------
-- 7b. Admin dashboard numbers: admins may read certificates and attempts
-- ------------------------------------------------------------
drop policy if exists "certificates admin read" on certificates;
create policy "certificates admin read" on certificates for select using (public.is_admin());
drop policy if exists "attempts admin read" on quiz_attempts;
create policy "attempts admin read" on quiz_attempts for select using (public.is_admin());

-- ------------------------------------------------------------
-- 8. MAKE YOURSELF ADMIN (run once, after you have signed up):
--
--   insert into admins (user_id)
--   select id from auth.users where email = 'YOUR_EMAIL_HERE'
--   on conflict do nothing;
-- ------------------------------------------------------------
