"use client";

import { useState } from "react";
import ReactMarkdown from "react-markdown";
import { stripDayPrefix } from "@/lib/course-utils";

type Lesson = {
  id: string;
  title: string;
  content: string | null;
  video_url: string | null;
  order_index: number;
};

export type Module = {
  id: string;
  title: string;
  order_index: number;
  lessons: Lesson[];
};

export default function LessonViewer({
  modules,
  completedIds,
  onMarkComplete,
  saving,
}: {
  modules: Module[];
  completedIds: Set<string>;
  onMarkComplete: (lessonId: string) => Promise<boolean>;
  saving: string | null;
}) {
  // Every lesson gets a running day number across the whole course.
  const days = modules.flatMap((m) =>
    m.lessons.map((l) => ({ lesson: l, module: m }))
  );
  const dayNumber = new Map(days.map((d, i) => [d.lesson.id, i + 1]));

  // Resume where the student left off: first lesson not yet completed.
  const firstUndone = days.find((d) => !completedIds.has(d.lesson.id)) ?? days[0];
  const [activeId, setActiveId] = useState<string | undefined>(firstUndone?.lesson.id);
  const [open, setOpen] = useState<Record<string, boolean>>(
    firstUndone ? { [firstUndone.module.id]: true } : {}
  );

  const activeIndex = days.findIndex((d) => d.lesson.id === activeId);
  const current = activeIndex >= 0 ? days[activeIndex] : undefined;
  const prev = activeIndex > 0 ? days[activeIndex - 1] : undefined;
  const next = activeIndex >= 0 ? days[activeIndex + 1] : undefined;

  function goTo(d: { lesson: Lesson; module: Module }) {
    setActiveId(d.lesson.id);
    setOpen((o) => ({ ...o, [d.module.id]: true }));
    if (typeof window !== "undefined") window.scrollTo({ top: 0, behavior: "smooth" });
  }

  async function completeAndContinue() {
    if (!current) return;
    const ok = await onMarkComplete(current.lesson.id);
    if (ok && next) goTo(next);
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-[300px_1fr] gap-8 items-start">
      {/* ---------- Sidebar: modules (weeks) -> days ---------- */}
      <aside className="border border-line rounded bg-panel md:sticky md:top-6 max-h-[80vh] overflow-y-auto">
        {modules.map((m) => {
          const doneInModule = m.lessons.filter((l) => completedIds.has(l.id)).length;
          const isOpen = !!open[m.id];
          return (
            <div key={m.id} className="border-b border-line last:border-b-0">
              <button
                onClick={() => setOpen((o) => ({ ...o, [m.id]: !isOpen }))}
                className="w-full flex items-center justify-between gap-3 px-4 py-3 text-left hover:bg-paper transition-colors"
                aria-expanded={isOpen}
              >
                <span>
                  <span className="block text-sm font-medium">{m.title}</span>
                  <span className="stamp text-[10px] text-ink/50">
                    {doneInModule}/{m.lessons.length} days done
                  </span>
                </span>
                <span className="text-ink/40 text-xs">{isOpen ? "▲" : "▼"}</span>
              </button>

              {isOpen && (
                <ul className="pb-2">
                  {m.lessons.map((l) => {
                    const isActive = l.id === activeId;
                    const isDone = completedIds.has(l.id);
                    return (
                      <li key={l.id}>
                        <button
                          onClick={() => goTo({ lesson: l, module: m })}
                          className={`flex items-start gap-3 text-left w-full text-sm px-4 py-2 transition-colors ${
                            isActive ? "bg-signal text-paper" : "hover:bg-paper text-ink/80"
                          }`}
                        >
                          <span
                            className={`mt-0.5 inline-flex items-center justify-center w-4 h-4 rounded-full text-[10px] shrink-0 ${
                              isDone
                                ? isActive
                                  ? "bg-paper text-signal"
                                  : "bg-signal text-paper"
                                : "border border-current opacity-40"
                            }`}
                          >
                            {isDone ? "✓" : ""}
                          </span>
                          <span>
                            <span className="stamp block text-[10px] opacity-60">
                              Day {dayNumber.get(l.id)}
                            </span>
                            {stripDayPrefix(l.title)}
                          </span>
                        </button>
                      </li>
                    );
                  })}
                </ul>
              )}
            </div>
          );
        })}
      </aside>

      {/* ---------- Lesson content ---------- */}
      <div className="border border-line rounded bg-panel p-6 md:p-8 min-w-0">
        {current ? (
          <>
            <p className="stamp text-xs text-signal mb-2">
              Day {dayNumber.get(current.lesson.id)} of {days.length} · {current.module.title}
            </p>
            <h2 className="font-display text-2xl font-semibold mb-5">
              {stripDayPrefix(current.lesson.title)}
            </h2>

            {current.lesson.video_url && (
              <div className="aspect-video mb-6 rounded overflow-hidden border border-line">
                <iframe
                  src={current.lesson.video_url}
                  className="w-full h-full"
                  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                  allowFullScreen
                />
              </div>
            )}

            {current.lesson.content && (
              <div className="prose prose-sm max-w-none text-ink/80 prose-pre:bg-ink prose-pre:text-paper mb-8">
                <ReactMarkdown>{current.lesson.content}</ReactMarkdown>
              </div>
            )}

            <div className="flex flex-wrap items-center gap-3 pt-5 border-t border-line">
              {prev && (
                <button
                  onClick={() => goTo(prev)}
                  className="text-sm text-ink/60 hover:text-signal transition-colors"
                >
                  ← Previous day
                </button>
              )}

              {completedIds.has(current.lesson.id) ? (
                <span className="stamp text-xs text-signal">✓ Completed</span>
              ) : (
                <button
                  onClick={completeAndContinue}
                  disabled={saving === current.lesson.id}
                  className="bg-signal text-paper px-4 py-2 rounded text-sm hover:bg-signalDark transition-colors disabled:opacity-50"
                >
                  {saving === current.lesson.id
                    ? "Saving…"
                    : next
                    ? "Mark complete & continue"
                    : "Mark complete"}
                </button>
              )}

              {next && (
                <button
                  onClick={() => goTo(next)}
                  className="ml-auto text-sm text-ink/60 hover:text-signal transition-colors"
                >
                  Next day →
                </button>
              )}
            </div>
          </>
        ) : (
          <p className="text-ink/50">This course has no lessons yet.</p>
        )}
      </div>
    </div>
  );
}
