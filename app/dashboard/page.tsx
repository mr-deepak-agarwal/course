import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import RequestAccessButton from "@/components/RequestAccessButton";
import type { EnrollmentStatus } from "@/lib/course-utils";

type Course = {
  id: string;
  slug: string;
  title: string;
  description: string | null;
  category_id: string | null;
};

export default async function DashboardPage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const [
    { data: profile },
    { data: courses },
    { data: categories },
    { data: enrollments },
    { data: certificates },
    { data: modules },
    { data: outline },
    { data: progress },
    { data: isAdmin },
  ] = await Promise.all([
    supabase.from("profiles").select("full_name, stream").eq("id", user.id).single(),
    supabase
      .from("courses")
      .select("id, slug, title, description, category_id")
      .eq("is_published", true)
      .order("order_index"),
    supabase.from("categories").select("id, name, order_index").order("order_index"),
    supabase.from("enrollments").select("course_id, status").eq("student_id", user.id),
    supabase
      .from("certificates")
      .select("certificate_code, course_id")
      .eq("student_id", user.id),
    supabase.from("modules").select("id, course_id"),
    supabase.from("lesson_outline").select("id, module_id"),
    supabase.from("lesson_progress").select("lesson_id").eq("student_id", user.id),
    supabase.rpc("is_admin"),
  ]);

  const allCourses = (courses ?? []) as Course[];
  const statusByCourse = new Map<string, EnrollmentStatus>(
    (enrollments ?? []).map((e) => [e.course_id as string, e.status as EnrollmentStatus])
  );
  const certByCourse = new Map(
    (certificates ?? []).map((c) => [c.course_id as string, c.certificate_code as string])
  );

  // lesson totals / completed counts per course
  const courseOfModule = new Map((modules ?? []).map((m) => [m.id as string, m.course_id as string]));
  const doneSet = new Set((progress ?? []).map((p) => p.lesson_id as string));
  const totals = new Map<string, number>();
  const done = new Map<string, number>();
  for (const l of outline ?? []) {
    const cid = courseOfModule.get(l.module_id as string);
    if (!cid) continue;
    totals.set(cid, (totals.get(cid) ?? 0) + 1);
    if (doneSet.has(l.id as string)) done.set(cid, (done.get(cid) ?? 0) + 1);
  }

  const myCourses = allCourses.filter((c) => statusByCourse.get(c.id) === "approved");
  const pending = allCourses.filter((c) => statusByCourse.get(c.id) === "pending");
  const browsable = allCourses.filter((c) => {
    const s = statusByCourse.get(c.id);
    return s !== "approved" && s !== "pending";
  });

  const catalog = (categories ?? [])
    .map((cat) => ({
      ...cat,
      courses: browsable.filter((c) => c.category_id === cat.id),
    }))
    .filter((cat) => cat.courses.length > 0);

  return (
    <div className="max-w-5xl mx-auto px-6 py-14">
      <p className="stamp text-signal text-xs mb-2">Welcome back</p>
      <h1 className="font-display text-3xl font-semibold mb-1">{profile?.full_name ?? "Student"}</h1>
      <p className="text-ink/60 mb-10">
        {profile?.stream}
        {isAdmin && (
          <>
            {" · "}
            <Link href="/admin" className="text-signal underline">
              Admin panel
            </Link>
          </>
        )}
      </p>

      {/* ---------- My courses ---------- */}
      <section className="mb-12">
        <h2 className="font-display text-xl font-semibold mb-4">My courses</h2>

        {myCourses.length === 0 ? (
          <div className="border border-dashed border-line rounded p-6 text-sm text-ink/60">
            {pending.length > 0
              ? "Your request is with the admin. Your course will appear here as soon as it is approved."
              : "You have no courses yet. Pick one below and request access."}
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            {myCourses.map((c) => {
              const total = totals.get(c.id) ?? 0;
              const d = done.get(c.id) ?? 0;
              const pct = total > 0 ? Math.round((d / total) * 100) : 0;
              const code = certByCourse.get(c.id);
              const ready = total > 0 && d >= total;

              return (
                <div key={c.id} className="border border-line rounded p-6 bg-panel">
                  <h3 className="font-display text-xl font-semibold mb-2">{c.title}</h3>
                  <p className="text-sm text-ink/60 mb-4">{c.description}</p>

                  <div className="mb-4">
                    <div className="flex justify-between stamp text-[11px] text-ink/50 mb-1">
                      <span>
                        {d}/{total} days done
                      </span>
                      <span>{pct}%</span>
                    </div>
                    <div className="h-2 rounded-full bg-line overflow-hidden">
                      <div className="h-full bg-signal transition-all" style={{ width: `${pct}%` }} />
                    </div>
                  </div>

                  {code ? (
                    <div className="flex flex-wrap items-center gap-4">
                      <Link href={`/verify/${code}`} className="stamp text-xs text-signal">
                        ✓ Certified — view certificate
                      </Link>
                      <a
                        href={`/api/certificate/${code}`}
                        className="stamp text-xs text-ink/50 hover:text-signal"
                      >
                        Download PDF
                      </a>
                    </div>
                  ) : ready ? (
                    <Link
                      href={`/courses/${c.slug}/quiz`}
                      className="inline-block bg-amber text-paper px-4 py-2 rounded text-sm hover:opacity-90 transition-opacity"
                    >
                      Take the final test
                    </Link>
                  ) : (
                    <Link
                      href={`/courses/${c.slug}`}
                      className="inline-block bg-signal text-paper px-4 py-2 rounded text-sm hover:bg-signalDark transition-colors"
                    >
                      {d > 0 ? "Continue" : "Start course"}
                    </Link>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </section>

      {/* ---------- Waiting for approval ---------- */}
      {pending.length > 0 && (
        <section className="mb-12">
          <h2 className="font-display text-xl font-semibold mb-4">Waiting for approval</h2>
          <div className="space-y-3">
            {pending.map((c) => (
              <div
                key={c.id}
                className="border border-line rounded px-5 py-4 bg-panel flex flex-wrap items-center justify-between gap-3"
              >
                <span className="font-medium">{c.title}</span>
                <span className="stamp text-xs text-amber">⏳ Request sent</span>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* ---------- Catalog by category ---------- */}
      {catalog.length > 0 && (
        <section>
          <h2 className="font-display text-xl font-semibold mb-6">Browse courses</h2>
          <div className="space-y-10">
            {catalog.map((cat) => (
              <div key={cat.id}>
                <p className="stamp text-xs text-ink/50 mb-3">{cat.name}</p>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                  {cat.courses.map((c) => {
                    const total = totals.get(c.id) ?? 0;
                    const rejected = statusByCourse.get(c.id) === "rejected";
                    return (
                      <div key={c.id} className="border border-line rounded p-6 bg-panel flex flex-col">
                        <h3 className="font-display text-xl font-semibold mb-2">{c.title}</h3>
                        <p className="text-sm text-ink/60 mb-4 flex-1">{c.description}</p>
                        {rejected && (
                          <p className="text-xs text-red-600 mb-3">
                            Your last request was not approved. You can ask again.
                          </p>
                        )}
                        <div className="flex items-center gap-4">
                          <RequestAccessButton courseId={c.id} wasRejected={rejected} />
                          <Link
                            href={`/courses/${c.slug}`}
                            className="text-sm text-ink/60 underline hover:text-signal"
                          >
                            See syllabus{total > 0 ? ` (${total} days)` : ""}
                          </Link>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
