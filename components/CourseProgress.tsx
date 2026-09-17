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

  async function markComplete(lessonId: string) {
    if (completedIds.has(lessonId)) return;
    setSaving(lessonId);

    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setSaving(null);
      return;
    }

    const { error } = await supabase
      .from("lesson_progress")
      .upsert(
        { student_id: user.id, lesson_id: lessonId },
        { onConflict: "student_id,lesson_id" }
      );

    if (!error) {
      setCompletedIds((prev) => new Set(prev).add(lessonId));
    }
    setSaving(null);
  }

  const done = completedIds.size;
  const allComplete = totalLessons > 0 && done >= totalLessons;
  const pct = totalLessons > 0 ? Math.round((done / totalLessons) * 100) : 0;

  return (
    <div>
      {!isCertified && (
        <div className="mb-6 flex items-center gap-4">
          <div className="flex-1 h-2 rounded-full bg-line overflow-hidden">
            <div
              className="h-full bg-signal transition-all"
              style={{ width: `${pct}%` }}
            />
          </div>
          <span className="stamp text-xs text-ink/50 whitespace-nowrap">
            {done}/{totalLessons} lessons
          </span>

          {allComplete ? (
            <Link
              href={`/courses/${courseSlug}/quiz`}
              className="bg-amber text-paper px-4 py-2 rounded text-sm hover:opacity-90 transition-opacity whitespace-nowrap"
            >
              Take the test
            </Link>
          ) : (
            <span
              title="Mark every lesson complete to unlock the test"
              className="bg-line text-ink/40 px-4 py-2 rounded text-sm whitespace-nowrap cursor-not-allowed"
            >
              Take the test
            </span>
          )}
        </div>
      )}

      <LessonViewer
        modules={modules}
        completedIds={completedIds}
        onMarkComplete={markComplete}
        saving={saving}
      />
    </div>
  );
}
