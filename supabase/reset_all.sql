-- ============================================================
-- Job-Ready Portal — RESET (destructive!)
-- Deletes every portal table, view and function in the public schema,
-- including ALL courses, enrollments, progress, test attempts,
-- certificates, profiles and the admins list.
-- It does NOT delete login accounts (Authentication > Users).
--
-- Use it, then run setup_all.sql to rebuild from scratch.
-- ============================================================

drop trigger if exists on_auth_user_created on auth.users;

drop view if exists lesson_outline      cascade;
drop view if exists questions_public    cascade;
drop view if exists certificate_public  cascade;

drop table if exists lesson_progress cascade;
drop table if exists certificates    cascade;
drop table if exists quiz_attempts   cascade;
drop table if exists enrollments     cascade;
drop table if exists questions       cascade;
drop table if exists quizzes         cascade;
drop table if exists lessons         cascade;
drop table if exists modules         cascade;
drop table if exists courses         cascade;
drop table if exists categories      cascade;
drop table if exists admins          cascade;
drop table if exists profiles        cascade;

drop function if exists public.submit_quiz(uuid, jsonb);
drop function if exists public.verify_certificate(text);
drop function if exists public.has_course_access(uuid);
drop function if exists public.is_admin();
drop function if exists public.handle_new_user();
