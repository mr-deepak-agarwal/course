"use client";

import { useState } from "react";
import ReactMarkdown from "react-markdown";

type Lesson = {
  id: string;
  title: string;
  content: string | null;
  video_url: string | null;
  order_index: number;
};

type Module = {
  id: string;
  title: string;
  order_index: number;
  lessons: Lesson[];
};

export default function LessonViewer({ modules }: { modules: Module[] }) {
  const allLessons = modules.flatMap((m) => m.lessons);
  const [activeId, setActiveId] = useState<string | undefined>(allLessons[0]?.id);
  const active = allLessons.find((l) => l.id === activeId);

  return (
    <div className="grid grid-cols-1 md:grid-cols-[280px_1fr] gap-8">
      {/* Sidebar */}
      <aside className="border border-line rounded bg-panel divide-y divide-line">
        {modules.map((m) => (
          <div key={m.id} className="p-4">
            <h4 className="stamp text-xs text-ink/50 mb-2">{m.title}</h4>
            <ul className="space-y-1">
              {m.lessons.map((l) => (
                <li key={l.id}>
                  <button
                    onClick={() => setActiveId(l.id)}
                    className={`text-left w-full text-sm px-2 py-1.5 rounded transition-colors ${
                      l.id === activeId
                        ? "bg-signal text-paper"
                        : "hover:bg-paper text-ink/80"
                    }`}
                  >
                    {l.title}
                  </button>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </aside>

      {/* Content */}
      <div className="border border-line rounded bg-panel p-8">
        {active ? (
          <>
            <h2 className="font-display text-2xl font-semibold mb-4">{active.title}</h2>
            {active.video_url && (
              <div className="aspect-video mb-6 rounded overflow-hidden border border-line">
                <iframe
                  src={active.video_url}
                  className="w-full h-full"
                  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                  allowFullScreen
                />
              </div>
            )}
            {active.content && (
              <div className="prose prose-sm max-w-none text-ink/80">
                <ReactMarkdown>{active.content}</ReactMarkdown>
              </div>
            )}
          </>
        ) : (
          <p className="text-ink/50">This course has no lessons yet.</p>
        )}
      </div>
    </div>
  );
}
