import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import LessonViewer from "@/components/LessonViewer";
import Link from "next/link";

export default async function CoursePage({ params }: { params: { slug: string } }) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const { data: course } = await supabase
    .from("courses")
    .select("id, title, description")
    .eq("slug", params.slug)
    .eq("is_published", true)
    .single();

  if (!course) notFound();

  // auto-enroll on first visit (idempotent — unique constraint on student_id, course_id)
  await supabase
    .from("enrollments")
    .upsert({ student_id: user.id, course_id: course.id }, { onConflict: "student_id,course_id" });

  const { data: modules } = await supabase
    .from("modules")
    .select("id, title, order_index, lessons(id, title, content, video_url, order_index)")
    .eq("course_id", course.id)
    .order("order_index");

  const { data: existingCert } = await supabase
    .from("certificates")
    .select("certificate_code")
    .eq("student_id", user.id)
    .eq("course_id", course.id)
    .maybeSingle();

  const sortedModules = (modules ?? [])
    .sort((a, b) => a.order_index - b.order_index)
    .map((m) => ({
      ...m,
      lessons: [...(m.lessons ?? [])].sort((a, b) => a.order_index - b.order_index),
    }));

  return (
    <div className="max-w-6xl mx-auto px-6 py-10">
      <div className="mb-8 flex items-start justify-between gap-6">
        <div>
          <h1 className="font-display text-3xl font-semibold mb-1">{course.title}</h1>
          <p className="text-ink/60">{course.description}</p>
        </div>
        {existingCert ? (
          <Link
            href={`/verify/${existingCert.certificate_code}`}
            className="stamp text-xs text-signal whitespace-nowrap"
          >
            ✓ Certified
          </Link>
        ) : (
          <Link
            href={`/courses/${params.slug}/quiz`}
            className="bg-amber text-paper px-4 py-2 rounded text-sm hover:opacity-90 transition-opacity whitespace-nowrap"
          >
            Take the test
          </Link>
        )}
      </div>

      <LessonViewer modules={sortedModules} />
    </div>
  );
}
