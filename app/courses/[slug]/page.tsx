import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import CourseProgress from "@/components/CourseProgress";
import RequestAccessButton from "@/components/RequestAccessButton";
import type { Module } from "@/components/LessonViewer";
import { stripDayPrefix, type EnrollmentStatus } from "@/lib/course-utils";

export default async function CoursePage({
  params,
}: {
  params: { slug: string };
}) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // middleware already redirects signed-out users; this keeps types honest.
  if (!user) return null;

  const { data: course } = await supabase
    .from("courses")
    .select("id, title, description")
    .eq("slug", params.slug)
    .eq("is_published", true)
    .maybeSingle();

  if (!course) notFound();

  const [{ data: enrollment }, { data: isAdmin }] = await Promise.all([
    supabase
      .from("enrollments")
      .select("status")
      .eq("student_id", user.id)
      .eq("course_id", course.id)
      .maybeSingle(),
    supabase.rpc("is_admin"),
  ]);

  const status = (enrollment?.status ?? null) as EnrollmentStatus | null;
  const hasAccess = status === "approved" || !!isAdmin;

  const header = (
    <>
      <Link href="/dashboard" className="stamp text-xs text-ink/50 hover:text-signal">
        ← My courses
      </Link>
      <h1 className="font-display text-3xl font-semibold mt-3 mb-2">{course.title}</h1>
      {course.description && (
        <p className="text-ink/60 max-w-2xl mb-8">{course.description}</p>
      )}
    </>
  );

  // ------------------------------------------------------------------
  // No access yet: show the day-wise syllabus (titles only) + request state
  // ------------------------------------------------------------------
  if (!hasAccess) {
    const [{ data: mods }, { data: outline }] = await Promise.all([
      supabase
        .from("modules")
        .select("id, title, order_index")
        .eq("course_id", course.id)
        .order("order_index"),
      supabase.from("lesson_outline").select("id, module_id, title, order_index"),
    ]);

    let day = 0;
    const syllabus = (mods ?? []).map((m) => ({
      ...m,
      lessons: (outline ?? [])
        .filter((l) => l.module_id === m.id)
        .sort((a, b) => a.order_index - b.order_index)
        .map((l) => ({ ...l, day: ++day })),
    }));

    return (
      <div className="max-w-3xl mx-auto px-6 py-12">
        {header}

        <div className="border border-line rounded p-5 bg-panel mb-10 flex flex-wrap items-center justify-between gap-4">
          {status === "pending" ? (
            <p className="text-sm">
              <span className="stamp text-xs text-amber mr-2">⏳ Request sent</span>
              The admin will approve your access soon. Check back here or on your dashboard.
            </p>
          ) : (
            <>
              <p className="text-sm text-ink/70">
                {status === "rejected"
                  ? "Your last request was not approved. You can ask again."
                  : "Request access and the admin will approve it."}
              </p>
              <RequestAccessButton courseId={course.id} wasRejected={status === "rejected"} />
            </>
          )}
        </div>

        <h2 className="font-display text-xl font-semibold mb-4">Syllabus</h2>
        <div className="space-y-6">
          {syllabus.map((m) => (
            <div key={m.id} className="border border-line rounded bg-panel">
              <p className="stamp text-xs text-ink/50 px-5 py-3 border-b border-line">{m.title}</p>
              <ul className="divide-y divide-line">
                {m.lessons.map((l) => (
                  <li key={l.id} className="px-5 py-2.5 text-sm flex gap-4">
                    <span className="stamp text-xs text-ink/40 w-14 shrink-0 pt-0.5">Day {l.day}</span>
                    <span>{stripDayPrefix(l.title)}</span>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>
    );
  }

  // ------------------------------------------------------------------
  // Approved (or admin): the full course
  // ------------------------------------------------------------------
  const { data: full } = await supabase
    .from("modules")
    .select("id, title, order_index, lessons(id, title, content, video_url, order_index)")
    .eq("course_id", course.id);

  const modules: Module[] = ((full ?? []) as Module[])
    .map((m) => ({
      ...m,
      lessons: [...(m.lessons ?? [])].sort((a, b) => a.order_index - b.order_index),
    }))
    .sort((a, b) => a.order_index - b.order_index);

  const lessonIds = modules.flatMap((m) => m.lessons.map((l) => l.id));
  const totalLessons = lessonIds.length;

  const [{ data: progress }, { data: certificate }] = await Promise.all([
    supabase
      .from("lesson_progress")
      .select("lesson_id")
      .eq("student_id", user.id)
      .in("lesson_id", lessonIds.length ? lessonIds : ["00000000-0000-0000-0000-000000000000"]),
    supabase
      .from("certificates")
      .select("certificate_code")
      .eq("student_id", user.id)
      .eq("course_id", course.id)
      .maybeSingle(),
  ]);

  const completedIds = (progress ?? []).map((p) => p.lesson_id as string);

  return (
    <div className="max-w-6xl mx-auto px-6 py-12">
      {header}

      {certificate && (
        <div className="mb-6 border border-signal/40 bg-signal/5 rounded p-4 flex flex-wrap items-center gap-4">
          <span className="stamp text-xs text-signal">✓ Certified</span>
          <Link href={`/verify/${certificate.certificate_code}`} className="text-sm underline">
            View certificate
          </Link>
          <a href={`/api/certificate/${certificate.certificate_code}`} className="text-sm underline">
            Download PDF
          </a>
        </div>
      )}

      <CourseProgress
        courseSlug={params.slug}
        modules={modules}
        totalLessons={totalLessons}
        initialCompletedIds={completedIds}
        isCertified={!!certificate}
      />
    </div>
  );
}
