"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { EnrollmentStatus } from "@/lib/course-utils";

export type RequestRow = {
  id: string;
  status: EnrollmentStatus;
  requested_at: string;
  student_name: string;
  email: string | null;
  stream: string | null;
  college: string | null;
  course_title: string;
};

const TABS: { key: EnrollmentStatus; label: string }[] = [
  { key: "pending", label: "Pending" },
  { key: "approved", label: "Approved" },
  { key: "rejected", label: "Rejected" },
];

export default function AdminRequests({ initialRows }: { initialRows: RequestRow[] }) {
  const supabase = createClient();
  const router = useRouter();
  const [rows, setRows] = useState(initialRows);
  const [tab, setTab] = useState<EnrollmentStatus>("pending");
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function setStatus(id: string, status: EnrollmentStatus) {
    setBusyId(id);
    setError(null);

    const {
      data: { user },
    } = await supabase.auth.getUser();

    const { data, error: updateError } = await supabase
      .from("enrollments")
      .update({
        status,
        reviewed_at: new Date().toISOString(),
        reviewed_by: user?.id ?? null,
      })
      .eq("id", id)
      .select("id");

    if (updateError || !data || data.length === 0) {
      setError(updateError?.message ?? "Update was not allowed. Are you signed in as an admin?");
      setBusyId(null);
      return;
    }

    setRows((rs) => rs.map((r) => (r.id === id ? { ...r, status } : r)));
    setBusyId(null);
    router.refresh();
  }

  const visible = rows.filter((r) => r.status === tab);

  return (
    <div>
      <div className="flex gap-2 mb-5 border-b border-line">
        {TABS.map((t) => {
          const count = rows.filter((r) => r.status === t.key).length;
          return (
            <button
              key={t.key}
              onClick={() => setTab(t.key)}
              className={`px-4 py-2 text-sm -mb-px border-b-2 transition-colors ${
                tab === t.key
                  ? "border-signal text-signal font-medium"
                  : "border-transparent text-ink/60 hover:text-ink"
              }`}
            >
              {t.label} <span className="stamp text-[11px] ml-1">{count}</span>
            </button>
          );
        })}
      </div>

      {error && <p className="mb-4 text-sm text-red-600">{error}</p>}

      {visible.length === 0 ? (
        <p className="text-sm text-ink/50 py-8">Nothing here.</p>
      ) : (
        <div className="border border-line rounded bg-panel divide-y divide-line">
          {visible.map((r) => (
            <div key={r.id} className="p-4 flex flex-wrap items-center justify-between gap-4">
              <div className="min-w-0">
                <p className="font-medium">
                  {r.student_name || "(no name)"}{" "}
                  <span className="text-ink/40 font-normal">· {r.stream ?? "—"}</span>
                </p>
                <p className="text-sm text-ink/60 break-all">
                  {r.email ?? "no email on file"}
                  {r.college ? ` · ${r.college}` : ""}
                </p>
                <p className="text-sm mt-1">
                  Wants: <span className="font-medium">{r.course_title}</span>
                  <span className="stamp text-[11px] text-ink/40 ml-3">
                    {new Date(r.requested_at).toLocaleDateString("en-IN", {
                      day: "numeric",
                      month: "short",
                      year: "numeric",
                    })}
                  </span>
                </p>
              </div>

              <div className="flex gap-2">
                {r.status !== "approved" && (
                  <button
                    onClick={() => setStatus(r.id, "approved")}
                    disabled={busyId === r.id}
                    className="bg-signal text-paper px-4 py-2 rounded text-sm hover:bg-signalDark transition-colors disabled:opacity-50"
                  >
                    Approve
                  </button>
                )}
                {r.status === "pending" && (
                  <button
                    onClick={() => setStatus(r.id, "rejected")}
                    disabled={busyId === r.id}
                    className="border border-line px-4 py-2 rounded text-sm hover:border-red-500 hover:text-red-600 transition-colors disabled:opacity-50"
                  >
                    Reject
                  </button>
                )}
                {r.status === "approved" && (
                  <button
                    onClick={() => setStatus(r.id, "rejected")}
                    disabled={busyId === r.id}
                    className="border border-line px-4 py-2 rounded text-sm hover:border-red-500 hover:text-red-600 transition-colors disabled:opacity-50"
                  >
                    Revoke access
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
