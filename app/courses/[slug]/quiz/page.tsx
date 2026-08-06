"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type Question = {
  id: string;
  question: string;
  options: string[];
  correct_index: number;
  order_index: number;
};

export default function QuizPage({ params }: { params: { slug: string } }) {
  const supabase = createClient();
  const router = useRouter();

  const [courseId, setCourseId] = useState<string | null>(null);
  const [courseTitle, setCourseTitle] = useState("");
  const [quizId, setQuizId] = useState<string | null>(null);
  const [passingScore, setPassingScore] = useState(70);
  const [questions, setQuestions] = useState<Question[]>([]);
  const [answers, setAnswers] = useState<Record<string, number>>({});
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [result, setResult] = useState<{ score: number; passed: boolean; code?: string } | null>(
    null
  );

  useEffect(() => {
    async function load() {
      const { data: course } = await supabase
        .from("courses")
        .select("id, title")
        .eq("slug", params.slug)
        .single();

      if (!course) {
        setLoading(false);
        return;
      }
      setCourseId(course.id);
      setCourseTitle(course.title);

      const { data: quiz } = await supabase
        .from("quizzes")
        .select("id, passing_score")
        .eq("course_id", course.id)
        .single();

      if (!quiz) {
        setLoading(false);
        return;
      }
      setQuizId(quiz.id);
      setPassingScore(quiz.passing_score);

      const { data: qs } = await supabase
        .from("questions")
        .select("id, question, options, correct_index, order_index")
        .eq("quiz_id", quiz.id)
        .order("order_index");

      setQuestions(qs ?? []);
      setLoading(false);
    }
    load();
  }, [params.slug]);

  async function handleSubmit() {
    if (!quizId || !courseId) return;
    setSubmitting(true);

    const total = questions.length;
    const correct = questions.filter((q) => answers[q.id] === q.correct_index).length;
    const score = total > 0 ? Math.round((correct / total) * 100) : 0;
    const passed = score >= passingScore;

    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setSubmitting(false);
      return;
    }

    await supabase.from("quiz_attempts").insert({
      student_id: user.id,
      quiz_id: quizId,
      score,
      passed,
    });

    let code: string | undefined;
    if (passed) {
      const { data: existing } = await supabase
        .from("certificates")
        .select("certificate_code")
        .eq("student_id", user.id)
        .eq("course_id", courseId)
        .maybeSingle();

      if (existing) {
        code = existing.certificate_code;
      } else {
        const { data: cert } = await supabase
          .from("certificates")
          .insert({ student_id: user.id, course_id: courseId })
          .select("certificate_code")
          .single();
        code = cert?.certificate_code;
      }
    }

    setResult({ score, passed, code });
    setSubmitting(false);
  }

  if (loading) {
    return <div className="max-w-2xl mx-auto px-6 py-16 text-ink/50">Loading test…</div>;
  }

  if (questions.length === 0) {
    return (
      <div className="max-w-2xl mx-auto px-6 py-16">
        <p className="text-ink/50">This course doesn't have a test set up yet.</p>
      </div>
    );
  }

  if (result) {
    return (
      <div className="max-w-2xl mx-auto px-6 py-16 text-center">
        <p className="stamp text-xs text-ink/50 mb-2">Result</p>
        <h1 className="font-display text-4xl font-semibold mb-4">{result.score}%</h1>
        {result.passed ? (
          <>
            <p className="text-signal font-medium mb-8">
              You passed — {courseTitle} certificate issued.
            </p>
            <button
              onClick={() => router.push(`/verify/${result.code}`)}
              className="bg-signal text-paper px-6 py-3 rounded font-medium hover:bg-signalDark transition-colors"
            >
              View your certificate
            </button>
          </>
        ) : (
          <>
            <p className="text-amber font-medium mb-8">
              You need {passingScore}% to pass. Review the lessons and try again.
            </p>
            <button
              onClick={() => router.push(`/courses/${params.slug}`)}
              className="border border-line px-6 py-3 rounded hover:border-signal transition-colors"
            >
              Back to course
            </button>
          </>
        )}
      </div>
    );
  }

  const allAnswered = questions.every((q) => answers[q.id] !== undefined);

  return (
    <div className="max-w-2xl mx-auto px-6 py-14">
      <p className="stamp text-xs text-signal mb-2">{courseTitle}</p>
      <h1 className="font-display text-3xl font-semibold mb-8">Final Test</h1>

      <div className="space-y-8">
        {questions.map((q, i) => (
          <div key={q.id} className="border border-line rounded p-6 bg-panel">
            <p className="font-medium mb-4">
              {i + 1}. {q.question}
            </p>
            <div className="space-y-2">
              {q.options.map((opt, idx) => (
                <label
                  key={idx}
                  className={`flex items-center gap-3 border rounded px-3 py-2 cursor-pointer transition-colors ${
                    answers[q.id] === idx ? "border-signal bg-signal/5" : "border-line"
                  }`}
                >
                  <input
                    type="radio"
                    name={q.id}
                    checked={answers[q.id] === idx}
                    onChange={() => setAnswers((a) => ({ ...a, [q.id]: idx }))}
                  />
                  <span className="text-sm">{opt}</span>
                </label>
              ))}
            </div>
          </div>
        ))}
      </div>

      <button
        onClick={handleSubmit}
        disabled={!allAnswered || submitting}
        className="mt-8 w-full bg-signal text-paper py-3 rounded font-medium hover:bg-signalDark transition-colors disabled:opacity-40"
      >
        {submitting ? "Submitting…" : "Submit test"}
      </button>
    </div>
  );
}
