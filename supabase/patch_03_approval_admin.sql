-- ============================================================
-- Patch 03 — course categories, admin approval of enrollments,
-- day-wise lessons, and a 40% pass mark.
-- Run AFTER schema.sql, the seed files, patch_01 and patch_02.
-- Safe to re-run.
--
-- After running, make yourself the admin (use the email you sign up with):
--   update profiles set is_admin = true
--   where id = (select id from auth.users where email = 'YOU@example.com');
-- ============================================================

-- ------------------------------------------------------------
-- 1. Categories + day numbers
-- ------------------------------------------------------------
create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  order_index int not null default 0
);

alter table categories enable row level security;
drop policy if exists "categories read" on categories;
create policy "categories read" on categories for select using (true);

alter table courses add column if not exists category_id uuid references categories(id) on delete set null;
alter table lessons add column if not exists day_number int;

-- "Day 7: ..." titles become day_number 7 (courses without that pattern stay NULL
-- and the UI shows "Lesson n" instead).
update lessons
set day_number = substring(title from '^Day ([0-9]+)')::int
where day_number is null and title ~ '^Day [0-9]+';

insert into categories (slug, name, order_index) values
  ('web-development', 'Web Development', 1),
  ('ai-data-science', 'AI & Data Science', 2)
on conflict (slug) do nothing;

update courses set category_id = (select id from categories where slug = 'web-development')
where slug = 'mern-stack-foundations' and category_id is null;

update courses set category_id = (select id from categories where slug = 'ai-data-science')
where slug = 'python-for-ai-21-days' and category_id is null;

-- ------------------------------------------------------------
-- 2. Admin flag on profiles (+ email, so the admin can see who is asking)
-- ------------------------------------------------------------
alter table profiles add column if not exists is_admin boolean not null default false;
alter table profiles add column if not exists email text;

update profiles p set email = u.email
from auth.users u
where u.id = p.id and p.email is null;

-- A student must never be able to set is_admin on themselves: only these
-- columns are writable from the browser, and profiles are created by the
-- signup trigger (security definer), not by client inserts.
revoke insert, update on profiles from anon, authenticated;
grant update (full_name, stream, college) on profiles to authenticated;

create or replace function public.is_admin()
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select coalesce((select is_admin from profiles where id = auth.uid()), false);
$$;
grant execute on function public.is_admin() to authenticated;

drop policy if exists "profile admin read" on profiles;
create policy "profile admin read" on profiles for select using (public.is_admin());

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

-- ------------------------------------------------------------
-- 3. Enrollment requests: pending -> approved / rejected by an admin
-- ------------------------------------------------------------
-- Existing enrollments are grandfathered in as approved (the column is added
-- with default 'approved', then the default for NEW rows is switched to pending).
alter table enrollments
  add column if not exists status text not null default 'approved'
  check (status in ('pending', 'approved', 'rejected'));
alter table enrollments alter column status set default 'pending';
alter table enrollments add column if not exists reviewed_at timestamptz;
alter table enrollments add column if not exists reviewed_by uuid references profiles(id) on delete set null;

drop policy if exists "enrollments self all" on enrollments;
drop policy if exists "enrollments self read" on enrollments;
drop policy if exists "enrollments self request" on enrollments;
drop policy if exists "enrollments self withdraw" on enrollments;
drop policy if exists "enrollments admin read" on enrollments;
drop policy if exists "enrollments admin update" on enrollments;

create policy "enrollments self read" on enrollments
  for select using (auth.uid() = student_id);

-- a student can only ever create a PENDING request for themselves
create policy "enrollments self request" on enrollments
  for insert with check (auth.uid() = student_id and status = 'pending');

-- ...and withdraw / retry a request that is not approved
create policy "enrollments self withdraw" on enrollments
  for delete using (auth.uid() = student_id and status in ('pending', 'rejected'));

create policy "enrollments admin read" on enrollments
  for select using (public.is_admin());

create policy "enrollments admin update" on enrollments
  for update using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- 4. Lesson content is only readable once enrollment is approved
-- ------------------------------------------------------------
create or replace function public.has_course_access(p_course uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select public.is_admin()
      or exists (
        select 1 from enrollments e
        where e.student_id = auth.uid()
          and e.course_id = p_course
          and e.status = 'approved'
      );
$$;
grant execute on function public.has_course_access(uuid) to authenticated;

drop policy if exists "lessons read" on lessons;
create policy "lessons read" on lessons for select using (
  exists (
    select 1 from modules m join courses c on c.id = m.course_id
    where m.id = lessons.module_id
      and c.is_published
      and public.has_course_access(c.id)
  )
);

-- Catalog numbers (modules / lessons per course) without exposing lesson content.
create or replace view course_lesson_counts as
select c.id as course_id,
       count(distinct m.id)::int as module_count,
       count(l.id)::int as lesson_count
from courses c
left join modules m on m.course_id = c.id
left join lessons l on l.module_id = m.id
where c.is_published
group by c.id;

grant select on course_lesson_counts to anon, authenticated;

-- ------------------------------------------------------------
-- 5. Progress can only be recorded on an approved course
-- ------------------------------------------------------------
drop policy if exists "lesson_progress self all" on lesson_progress;
drop policy if exists "lesson_progress self read" on lesson_progress;
drop policy if exists "lesson_progress self write" on lesson_progress;
drop policy if exists "lesson_progress admin read" on lesson_progress;

create policy "lesson_progress self read" on lesson_progress
  for select using (auth.uid() = student_id);

create policy "lesson_progress self write" on lesson_progress
  for all
  using (auth.uid() = student_id)
  with check (
    auth.uid() = student_id
    and exists (
      select 1
      from lessons l
      join modules m on m.id = l.module_id
      join enrollments e on e.course_id = m.course_id
      where l.id = lesson_progress.lesson_id
        and e.student_id = auth.uid()
        and e.status = 'approved'
    )
  );

create policy "lesson_progress admin read" on lesson_progress
  for select using (public.is_admin());

-- admins can also see attempts and certificates (for the admin panel)
drop policy if exists "attempts admin read" on quiz_attempts;
create policy "attempts admin read" on quiz_attempts for select using (public.is_admin());
drop policy if exists "certificates admin read" on certificates;
create policy "certificates admin read" on certificates for select using (public.is_admin());

-- ------------------------------------------------------------
-- 6. Pass mark is 40%, and the test needs an APPROVED enrollment
--    plus every lesson completed. (score >= passing_score)
-- ------------------------------------------------------------
alter table quizzes alter column passing_score set default 40;
update quizzes set passing_score = 40;

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

  if not exists (
    select 1 from enrollments e
    where e.student_id = v_user and e.course_id = v_course and e.status = 'approved'
  ) then
    raise exception 'Your enrollment in this course has not been approved';
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
