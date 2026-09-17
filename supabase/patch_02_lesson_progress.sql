-- ============================================================
-- Patch 02 — lesson progress tracking, gating the test behind it
-- Run AFTER patch_01_secure_quiz.sql. Safe to re-run.
-- ============================================================

-- ------------------------------------------------------------
-- 1. One row per lesson a student has marked as read/watched.
-- ------------------------------------------------------------
create table if not exists lesson_progress (
  student_id   uuid not null references profiles(id) on delete cascade,
  lesson_id    uuid not null references lessons(id) on delete cascade,
  completed_at timestamptz not null default now(),
  primary key (student_id, lesson_id)
);

alter table lesson_progress enable row level security;

drop policy if exists "lesson_progress self all" on lesson_progress;
create policy "lesson_progress self all" on lesson_progress
  for all
  using (auth.uid() = student_id)
  with check (auth.uid() = student_id);

-- ------------------------------------------------------------
-- 2. Replace submit_quiz() to also require 100% lesson completion.
--    Same signature as patch_01 — this is a straight override.
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
