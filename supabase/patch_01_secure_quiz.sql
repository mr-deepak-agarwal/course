-- ============================================================
-- Patch 01 — close the quiz/certificate holes before demoing
-- Run AFTER schema.sql and seed_mern.sql, in the Supabase SQL editor.
-- Safe to re-run.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Stop shipping the answer key to the browser.
--    `questions` holds correct_index, so the client must never
--    read that table directly. It reads this view instead.
-- ------------------------------------------------------------
drop policy if exists "questions read" on questions;
revoke select on questions from anon, authenticated;

create or replace view questions_public as
select qs.id, qs.quiz_id, qs.question, qs.options, qs.order_index
from questions qs
join quizzes q on q.id = qs.quiz_id
join courses c on c.id = q.course_id
where c.is_published;

grant select on questions_public to authenticated;

-- ------------------------------------------------------------
-- 2. Stop letting the browser mint its own certificate.
-- ------------------------------------------------------------
drop policy if exists "certificates self insert" on certificates;

-- attempts become read-only to the student; only the function below writes them
drop policy if exists "attempts self all" on quiz_attempts;
create policy "attempts self read" on quiz_attempts
  for select using (auth.uid() = student_id);

-- ------------------------------------------------------------
-- 3. Score the test server-side and issue the certificate here.
--    p_answers is { "<question_id>": <selected_option_index>, ... }
-- ------------------------------------------------------------
create or replace function public.submit_quiz(p_quiz_id uuid, p_answers jsonb)
returns table (score int, passed boolean, certificate_code text)
language plpgsql
security definer set search_path = public
as $$
declare
  v_user     uuid := auth.uid();
  v_course   uuid;
  v_pass     int;
  v_total    int;
  v_correct  int;
  v_score    int;
  v_passed   boolean;
  v_code     text;
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
-- 4. Verification: look up ONE code, never list everything.
--    The old open grant on certificate_public let anyone with the
--    anon key dump every certificate holder's name.
-- ------------------------------------------------------------
revoke select on certificate_public from anon, authenticated;

create or replace function public.verify_certificate(p_code text)
returns table (
  certificate_code text,
  student_name     text,
  stream           text,
  course_title     text,
  issued_at        timestamptz
)
language sql
security definer set search_path = public
stable
as $$
  select cert.certificate_code,
         p.full_name,
         p.stream,
         c.title,
         cert.issued_at
  from certificates cert
  join profiles p on p.id = cert.student_id
  join courses  c on c.id = cert.course_id
  where cert.certificate_code = p_code;
$$;

grant execute on function public.verify_certificate(text) to anon, authenticated;
