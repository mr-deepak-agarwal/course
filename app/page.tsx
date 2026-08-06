import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export default async function HomePage() {
  const supabase = createClient();
  const { data: courses } = await supabase
    .from("courses")
    .select("slug, title, description")
    .eq("is_published", true)
    .order("order_index");

  const steps = [
    { n: "01", label: "Read", detail: "Work through short, focused lessons per module." },
    { n: "02", label: "Watch", detail: "Pair each lesson with a linked video walkthrough." },
    { n: "03", label: "Test", detail: "Clear a scored quiz at the end of the course." },
    { n: "04", label: "Prove it", detail: "Get a verifiable certificate with a public link." },
  ];

  return (
    <div>
      {/* Hero */}
      <section className="border-b border-line">
        <div className="max-w-5xl mx-auto px-6 py-20">
          <p className="stamp text-signal text-xs mb-4">For BCA · BTech · MCA · MTech students</p>
          <h1 className="font-display text-5xl md:text-6xl font-semibold leading-[1.05] max-w-3xl">
            Courses that end in <span className="text-signal">proof</span>,
            not just a certificate of attendance.
          </h1>
          <p className="mt-6 text-lg text-ink/70 max-w-xl">
            Read the material, watch the walkthroughs, pass a real test, and
            walk away with a certificate anyone can verify — not just one you
            can screenshot.
          </p>
          <div className="mt-8 flex gap-4">
            <Link
              href="/signup"
              className="bg-signal text-paper px-6 py-3 rounded font-medium hover:bg-signalDark transition-colors"
            >
              Start with MERN Stack
            </Link>
            <a href="#courses" className="px-6 py-3 rounded border border-line hover:border-signal transition-colors">
              See all courses
            </a>
          </div>
        </div>
      </section>

      {/* Signature element: the readiness ledger — a stamped 4-step record */}
      <section className="border-b border-line bg-panel">
        <div className="max-w-5xl mx-auto px-6 py-14">
          <div className="grid grid-cols-1 md:grid-cols-4 divide-y md:divide-y-0 md:divide-x divide-line border border-line rounded">
            {steps.map((s) => (
              <div key={s.n} className="p-6">
                <span className="stamp text-amber text-xs">{s.n}</span>
                <h3 className="font-display text-xl mt-2 mb-1">{s.label}</h3>
                <p className="text-sm text-ink/60">{s.detail}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Course catalog */}
      <section id="courses" className="max-w-5xl mx-auto px-6 py-16">
        <h2 className="font-display text-3xl font-semibold mb-8">Courses</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          {(courses ?? []).map((c) => (
            <Link
              key={c.slug}
              href={`/courses/${c.slug}`}
              className="block border border-line rounded p-6 bg-panel hover:border-signal transition-colors"
            >
              <h3 className="font-display text-xl font-semibold mb-2">{c.title}</h3>
              <p className="text-sm text-ink/60">{c.description}</p>
            </Link>
          ))}
          {(!courses || courses.length === 0) && (
            <p className="text-ink/50 text-sm">
              No courses published yet — run{" "}
              <code className="stamp">supabase/seed_mern.sql</code> against your
              database.
            </p>
          )}
        </div>
      </section>
    </div>
  );
}
