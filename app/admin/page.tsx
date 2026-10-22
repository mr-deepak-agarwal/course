import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import AdminRequests, { type RequestRow } from "@/components/AdminRequests";

export const metadata = { title: "Admin — Job-Ready Portal" };

type RawRow = {
  id: string;
  status: RequestRow["status"];
  enrolled_at: string;
  profiles: { full_name: string; email: string | null; stream: string | null; college: string | null } | null;
  courses: { title: string } | null;
};

export default async function AdminPage() {
  const supabase = createClient();

  // Hide the page entirely from non-admins (the database enforces this too).
  const { data: isAdmin } = await supabase.rpc("is_admin");
  if (!isAdmin) notFound();

  const [{ data: enrollments }, { count: students }, { count: certificates }] =
    await Promise.all([
      supabase
        .from("enrollments")
        .select(
          "id, status, enrolled_at, profiles(full_name, email, stream, college), courses(title)"
        )
        .order("enrolled_at", { ascending: false }),
      supabase.from("profiles").select("id", { count: "exact", head: true }),
      supabase.from("certificates").select("id", { count: "exact", head: true }),
    ]);

  const rows: RequestRow[] = ((enrollments ?? []) as unknown as RawRow[]).map((e) => ({
    id: e.id,
    status: e.status,
    requested_at: e.enrolled_at,
    student_name: e.profiles?.full_name ?? "",
    email: e.profiles?.email ?? null,
    stream: e.profiles?.stream ?? null,
    college: e.profiles?.college ?? null,
    course_title: e.courses?.title ?? "(deleted course)",
  }));

  const pending = rows.filter((r) => r.status === "pending").length;
  const approved = rows.filter((r) => r.status === "approved").length;

  const stats = [
    { label: "Pending requests", value: pending, accent: pending > 0 },
    { label: "Active enrollments", value: approved },
    { label: "Registered students", value: students ?? 0 },
    { label: "Certificates issued", value: certificates ?? 0 },
  ];

  return (
    <div className="max-w-5xl mx-auto px-6 py-14">
      <p className="stamp text-xs text-signal mb-2">Admin</p>
      <h1 className="font-display text-3xl font-semibold mb-8">Enrollment requests</h1>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-10">
        {stats.map((s) => (
          <div key={s.label} className="border border-line rounded p-4 bg-panel">
            <p className={`font-display text-3xl font-semibold ${s.accent ? "text-amber" : ""}`}>
              {s.value}
            </p>
            <p className="stamp text-[11px] text-ink/50 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      <AdminRequests initialRows={rows} />
    </div>
  );
}
