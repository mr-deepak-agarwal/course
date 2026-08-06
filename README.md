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
2. In the SQL editor, run `supabase/schema.sql`, then `supabase/seed_mern.sql`.
3. Swap the placeholder `video_url` values in `seed_mern.sql` (or update the
   `lessons` table directly) for your real unlisted YouTube/Vimeo embed
   links — format: `https://www.youtube.com/embed/VIDEO_ID`.
4. Copy `.env.example` to `.env.local` and fill in your project URL + anon
   key (Supabase dashboard → Project Settings → API).
5. Install and run:
   ```
   npm install
   npm run dev
   ```
6. Visit `http://localhost:3000`, sign up as a student, work through the
   MERN course, take the test, and check the certificate + its public
   `/verify/[code]` link.

## Notes on what's deliberately left simple

- **Certificates** are on-page + a public verification URL (no PDF). Add a
  PDF export later if you need a downloadable file — `@react-pdf/renderer`
  or a serverless screenshot of the verify page both work well.
- **No admin UI yet** — courses/lessons/quizzes are managed via SQL or the
  Supabase table editor. Worth building once you have 3-4 courses and are
  tired of writing inserts by hand.
- **Auth** is email/password. Swap in magic links or Google OAuth via
  Supabase Auth settings with no schema changes.
- **RLS** is on for every table — students can only ever see their own
  enrollments/attempts/certificates, and the `certificate_public` view
  exposes only the fields needed for verification (name, stream, course,
  date) to anonymous visitors.
