import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export default async function DashboardPage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const [{ data: profile }, { data: courses }, { data: enrollments }, { data: certificates }] =
    await Promise.all([
      supabase.from("profiles").select("full_name, stream").eq("id", user.id).single(),
      supabase.from("courses").select("id, slug, title, description").eq("is_published", true),
      supabase.from("enrollments").select("course_id").eq("student_id", user.id),
      supabase
        .from("certificates")
        .select("certificate_code, course_id, issued_at")
        .eq("student_id", user.id),
    ]);

  const enrolledIds = new Set((enrollments ?? []).map((e) => e.course_id));
  const certByCourse = new Map((certificates ?? []).map((c) => [c.course_id, c]));

  return (
    <div className="max-w-5xl mx-auto px-6 py-14">
      <p className="stamp text-signal text-xs mb-2">Welcome back</p>
      <h1 className="font-display text-3xl font-semibold mb-1">{profile?.full_name ?? "Student"}</h1>
      <p className="text-ink/60 mb-10">{profile?.stream}</p>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
        {(courses ?? []).map((c) => {
          const cert = certByCourse.get(c.id);
          const enrolled = enrolledIds.has(c.id);
          return (
            <div key={c.id} className="border border-line rounded p-6 bg-panel">
              <h3 className="font-display text-xl font-semibold mb-2">{c.title}</h3>
              <p className="text-sm text-ink/60 mb-4">{c.description}</p>

              {cert ? (
                <div className="flex flex-wrap items-center gap-4">
                  <Link
                    href={`/verify/${cert.certificate_code}`}
                    className="stamp text-xs text-signal"
                  >
                    ✓ Certified — view certificate
                  </Link>
                  <a
                    href={`/api/certificate/${cert.certificate_code}`}
                    className="stamp text-xs text-ink/50 hover:text-signal"
                  >
                    Download PDF
                  </a>
                </div>
              ) : (
                <Link
                  href={`/courses/${c.slug}`}
                  className="inline-block bg-signal text-paper px-4 py-2 rounded text-sm hover:bg-signalDark transition-colors"
                >
                  {enrolled ? "Continue" : "Start course"}
                </Link>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
