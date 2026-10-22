"use client";

import { useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import LessonViewer, { type Module } from "@/components/LessonViewer";

export default function CourseProgress({
  courseSlug,
  modules,
  totalLessons,
  initialCompletedIds,
  isCertified,
}: {
  courseSlug: string;
  modules: Module[];
  totalLessons: number;
  initialCompletedIds: string[];
  isCertified: boolean;
}) {
  const supabase = createClient();
  const [completedIds, setCompletedIds] = useState<Set<string>>(
    new Set(initialCompletedIds)
  );
  const [saving, setSaving] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function markComplete(lessonId: string): Promise<boolean> {
    if (completedIds.has(lessonId)) return true;
    setSaving(lessonId);
    setError(null);

    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setSaving(null);
      return false;
    }

    const { error: upsertError } = await supabase
      .from("lesson_progress")
      .upsert(
        { student_id: user.id, lesson_id: lessonId },
        { onConflict: "student_id,lesson_id" }
      );

    setSaving(null);
    if (upsertError) {
      setError("Could not save your progress. Please try again.");
      return false;
    }
    setCompletedIds((prev) => new Set(prev).add(lessonId));
    return true;
  }

  const done = completedIds.size;
  const allComplete = totalLessons > 0 && done >= totalLessons;
  const pct = totalLessons > 0 ? Math.round((done / totalLessons) * 100) : 0;

  return (
    <div>
      {/* Progress bar */}
      <div className="mb-6">
        <div className="flex justify-between stamp text-xs text-ink/50 mb-2">
          <span>
            {done} of {totalLessons} days completed
          </span>
          <span>{pct}%</span>
        </div>
        <div className="h-2 rounded-full bg-line overflow-hidden">
          <div className="h-full bg-signal transition-all" style={{ width: `${pct}%` }} />
        </div>
      </div>

      {/* Unlocks once every day is done */}
      {!isCertified && allComplete && (
        <div className="mb-6 border border-amber/50 bg-amber/10 rounded p-5 flex flex-wrap items-center justify-between gap-4">
          <div>
            <p className="font-display text-lg font-semibold">
              You&apos;ve completed all {totalLessons} days.
            </p>
            <p className="text-sm text-ink/70">
              The final test is unlocked. Pass it to earn your certificate.
            </p>
          </div>
          <Link
            href={`/courses/${courseSlug}/quiz`}
            className="bg-amber text-paper px-5 py-2.5 rounded font-medium hover:opacity-90 transition-opacity"
          >
            Take the final test
          </Link>
        </div>
      )}

      {!isCertified && !allComplete && totalLessons > 0 && (
        <p className="mb-6 text-sm text-ink/50">
          Finish every day to unlock the final test. {totalLessons - done} to go.
        </p>
      )}

      {error && <p className="mb-4 text-sm text-red-600">{error}</p>}

      <LessonViewer
        modules={modules}
        completedIds={completedIds}
        onMarkComplete={markComplete}
        saving={saving}
      />
    </div>
  );
}
