import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import DashboardPage from "@/app/dashboard/page";

const STEPS = [
  { n: "01", title: "Learn", body: "Short lessons with a video and notes for every topic. No fluff, no filler weeks." },
  { n: "02", title: "Prove it", body: "Finish every lesson to unlock the final test. Scored on the server, so it can't be gamed." },
  { n: "03", title: "Get verified", body: "Pass and receive a certificate with a QR code that any recruiter or college can check." },
];

export default async function HomePage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Signed in: the home page is the student's dashboard.
  if (user) return <DashboardPage />;

  const { data: courses } = await supabase
    .from("courses")
    .select("slug, title, description")
    .eq("is_published", true)
    .order("order_index");

  return (
    <div>
      {/* Hero */}
      <section className="max-w-5xl mx-auto px-6 pt-20 pb-16">
        <p className="stamp text-xs text-signal mb-4">For BCA · BTech · MCA · MTech students</p>
        <h1 className="font-display text-4xl md:text-6xl font-semibold leading-tight max-w-3xl mb-6">
          Courses that end in proof, not just attendance.
        </h1>
        <p className="text-lg text-ink/70 max-w-2xl mb-10">
          Learn a job-ready skill, pass a real test, and earn a certificate
          anyone can verify with a single scan.
        </p>
        <div className="flex flex-col sm:flex-row gap-3">
          <Link
            href="/signup"
            className="bg-signal text-paper px-6 py-3 rounded font-medium text-center hover:bg-signalDark transition-colors"
          >
            Create your free account
          </Link>
          <Link
            href="/login"
            className="border border-line px-6 py-3 rounded text-center hover:border-signal transition-colors"
          >
            I already have an account
          </Link>
        </div>
      </section>

      {/* How it works */}
      <section className="border-y border-line bg-panel">
        <div className="max-w-5xl mx-auto px-6 py-14 grid grid-cols-1 md:grid-cols-3 gap-8">
          {STEPS.map((s) => (
            <div key={s.n}>
              <p className="stamp text-xs text-amber mb-2">{s.n}</p>
              <h3 className="font-display text-xl font-semibold mb-2">{s.title}</h3>
              <p className="text-sm text-ink/70">{s.body}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Courses */}
      <section className="max-w-5xl mx-auto px-6 py-16">
        <h2 className="font-display text-2xl font-semibold mb-6">Available courses</h2>
        {(courses ?? []).length === 0 ? (
          <p className="text-ink/50">Courses are coming soon.</p>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            {(courses ?? []).map((c) => (
              <div key={c.slug} className="border border-line rounded p-6 bg-panel">
                <h3 className="font-display text-xl font-semibold mb-2">{c.title}</h3>
                <p className="text-sm text-ink/60 mb-4">{c.description}</p>
                <Link
                  href="/signup"
                  className="stamp text-xs text-signal hover:text-signalDark"
                >
                  Sign up to start →
                </Link>
              </div>
            ))}
          </div>
        )}
      </section>

      {/* Verify */}
      <section className="max-w-5xl mx-auto px-6 pb-20">
        <div className="border border-line rounded p-8 bg-panel flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <h3 className="font-display text-xl font-semibold mb-1">Hiring or checking a certificate?</h3>
            <p className="text-sm text-ink/60">Enter the certificate code to confirm it&apos;s genuine.</p>
          </div>
          <Link
            href="/verify"
            className="border border-line px-6 py-3 rounded text-center hover:border-signal transition-colors"
          >
            Verify a certificate
          </Link>
        </div>
      </section>
    </div>
  );
}
