"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function RequestAccessButton({
  courseId,
  wasRejected = false,
  className = "",
}: {
  courseId: string;
  wasRejected?: boolean;
  className?: string;
}) {
  const supabase = createClient();
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function request() {
    setBusy(true);
    setError(null);

    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      router.push("/login");
      return;
    }

    // A rejected request must be withdrawn before filing a new one
    // (one row per student per course). RLS only allows this for
    // pending/rejected rows, never approved ones.
    if (wasRejected) {
      await supabase
        .from("enrollments")
        .delete()
        .eq("student_id", user.id)
        .eq("course_id", courseId);
    }

    const { error: insertError } = await supabase
      .from("enrollments")
      .insert({ student_id: user.id, course_id: courseId });

    if (insertError) {
      setError(insertError.message);
      setBusy(false);
      return;
    }

    router.refresh();
    setBusy(false);
  }

  return (
    <div className={className}>
      <button
        onClick={request}
        disabled={busy}
        className="bg-signal text-paper px-4 py-2 rounded text-sm hover:bg-signalDark transition-colors disabled:opacity-50"
      >
        {busy ? "Sending…" : wasRejected ? "Request again" : "Request access"}
      </button>
      {error && <p className="text-xs text-red-600 mt-2">{error}</p>}
    </div>
  );
}
