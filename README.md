# Job-Ready Portal

A generic course engine — one login per student, read → watch → test → get a
verifiable certificate. Seeded with a **MERN Stack Foundations** course.

Stack: Next.js 14 (App Router) · Supabase (auth + Postgres + RLS) · Tailwind.

## How it's structured

```
courses → modules → lessons (markdown + video embed)
        → quiz → questions
students (profiles) → enrollments, quiz_attempts, certificates
```

Adding a new course is a SQL insert (or a future admin UI) — the app code
doesn't change. `supabase/seed_mern.sql` is a working example to copy for
your next course (BTech, MCA, MTech content, etc).

## Setup

1. **Create a Supabase project** at supabase.com.
2. In the SQL editor, run, in order: `supabase/schema.sql`,
   `supabase/seed_mern.sql`, `supabase/patch_01_secure_quiz.sql`, then
   `supabase/patch_02_lesson_progress.sql`. All four are required —
   patch_01 moves scoring and certificate issuance server-side, patch_02
   adds lesson tracking and gates the test behind finishing the course.
   Then run `supabase/patch_03_approval_flow.sql` (categories, admin approval,
   access-gated content, 40% pass mark).
   Optional: run `supabase/seed_python_ai.sql` (after the patches) to add the
   21-day **Python for AI** course. Its `video_url` values are NULL until you set them.
3. Swap the placeholder `video_url` values in `seed_mern.sql` (or update the
   `lessons` table directly) for your real unlisted YouTube/Vimeo embed
   links — format: `https://www.youtube.com/embed/VIDEO_ID`.
4. Copy `.env.example` to `.env.local` and fill in your project URL + anon
   key (Supabase dashboard → Project Settings → API), plus
   `NEXT_PUBLIC_SITE_URL`. Set that to your real domain before demoing —
   certificate QR codes encode it, and a localhost QR won't open on a
   student's phone.
5. Install and run:
   ```
   npm install
   npm run dev
   ```
6. Visit `http://localhost:3000`, sign up as a student, work through the
   MERN course, take the test, and check the certificate + its public
   `/verify/[code]` link.

## Student flow & admin approval

1. A student registers, then sees **My courses**, **Waiting for approval** and
   **Browse courses** (grouped by category) on `/dashboard`.
2. They press **Request access** on a course (or open it to see the day-wise
   syllabus first). This creates an `enrollments` row with `status = 'pending'`.
3. The admin opens `/admin`, and approves or rejects it (a revoke is also possible).
4. Once approved, the course appears under **My courses**. Inside the course the
   lessons are grouped by module (week) and numbered Day 1, Day 2, ...
   with a progress bar. Marking a day complete saves progress.
5. When every day is complete, **Take the final test** unlocks. A score of **40% or
   more** issues the certificate. Anyone with the certificate code can verify and
   download it at `/verify`.

**Making yourself admin** (once, after you have signed up):

```sql
insert into admins (user_id)
select id from auth.users where email = 'YOUR_EMAIL_HERE'
on conflict do nothing;
```

Admins live in their own `admins` table, not a flag on `profiles`, because students
can edit their own profile row and could otherwise promote themselves.

Security is enforced in the database (RLS), not only in the UI: a student cannot
insert or edit an approved enrollment, cannot read lesson content or questions
without approval, and `submit_quiz()` rejects unapproved students.

**Adding a course category:** `insert into categories (slug, name, order_index) ...`
then set `courses.category_id`. Change the pass mark with
`update quizzes set passing_score = 50 where ...`.

## Certificates & verification

A certificate is a row in `certificates` holding a 12-character
`certificate_code`. Nothing is stored as a file — the PDF is rebuilt from
that code on every request, so re-downloads work forever and cost no
storage.

- `app/api/certificate/[code]/route.ts` — renders the A4-landscape PDF with
  `pdf-lib`, embeds a QR code pointing back at the verify URL, and returns it
  as an attachment. Public: anyone holding the code can download it.
- `app/verify/page.tsx` — the page you point colleges at. Paste a code (or a
  full verify URL) and it routes through.
- `app/verify/[code]/page.tsx` — where a QR scan lands. Shows the certificate
  on screen with its QR and a Download PDF button.
- `app/verify/[code]/not-found.tsx` — shown when a code doesn't match, which
  is the answer to "what if someone fakes one?"

## Security notes for the demo

`supabase/patch_01_secure_quiz.sql` fixes three things that matter if you're
demoing in a room full of CS students:

- The browser no longer receives `correct_index`. It reads `questions_public`,
  a view without that column.
- Scoring, the attempt record, and certificate issuance happen inside the
  `submit_quiz()` Postgres function. A student can't insert a certificate for
  themselves any more.
- `verify_certificate(code)` replaces the open grant on `certificate_public`,
  so nobody can dump the full list of certificate holders with the anon key.

## Lesson progress

`lesson_progress` (added by `patch_02_lesson_progress.sql`) records one row
per lesson a student marks complete via the button at the bottom of each
lesson in `components/LessonViewer.tsx`. `components/CourseProgress.tsx`
holds that state, shows the progress bar, and only links to the test once
every lesson is checked off. The same rule is enforced again inside
`submit_quiz()` in Postgres — a student calling the RPC directly, past the
disabled button, still gets rejected server-side.

This is presence-based (did they click "mark complete"), not proof they
watched the video or read every word — there's no way to guarantee that
without more invasive tracking (watch-time on the video, scroll tracking).
Good enough to say "the test is gated behind the material" in a demo;
tighten it later if you need stronger evidence.

## Notes on what's deliberately left simple

- **No admin UI yet** — courses/lessons/quizzes are managed via SQL or the
  Supabase table editor. Worth building once you have 3-4 courses and are
  tired of writing inserts by hand.
- **Auth** is email/password. Swap in magic links or Google OAuth via
  Supabase Auth settings with no schema changes.
- **RLS** is on for every table — students can only ever see their own
  enrollments/attempts/certificates, and the `certificate_public` view
  exposes only the fields needed for verification (name, stream, course,
  date) to anonymous visitors.
