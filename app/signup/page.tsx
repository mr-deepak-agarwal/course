"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function SignupPage() {
  const router = useRouter();
  const supabase = createClient();
  const [fullName, setFullName] = useState("");
  const [stream, setStream] = useState("BCA");
  const [college, setCollege] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [confirmEmailSent, setConfirmEmailSent] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const { data, error: signUpError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { full_name: fullName, stream, college },
      },
    });

    if (signUpError || !data.user) {
      setError(signUpError?.message ?? "Could not create account.");
      setLoading(false);
      return;
    }

    // The profiles row is created server-side by a database trigger
    // (see supabase/schema.sql) reading this metadata, so it works
    // even before email confirmation. If email confirmation is
    // required, there's no session yet — send them to check email
    // instead of the dashboard.
    if (!data.session) {
      setLoading(false);
      setConfirmEmailSent(true);
      return;
    }

    router.push("/dashboard");
    router.refresh();
  }

  if (confirmEmailSent) {
    return (
      <div className="max-w-md mx-auto px-6 py-16 text-center">
        <h1 className="font-display text-3xl font-semibold mb-3">Check your email</h1>
        <p className="text-ink/60 text-sm">
          We sent a confirmation link to <span className="text-ink">{email}</span>. Click it,
          then log in to start the course.
        </p>
      </div>
    );
  }

  return (
    <div className="max-w-md mx-auto px-6 py-16">
      <h1 className="font-display text-3xl font-semibold mb-2">Create your account</h1>
      <p className="text-ink/60 mb-8 text-sm">One login, every course, one record of what you've cleared.</p>

      <form onSubmit={handleSubmit} className="space-y-4">
        <Field label="Full name">
          <input
            required
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
            className="input"
          />
        </Field>

        <Field label="Stream">
          <select
            value={stream}
            onChange={(e) => setStream(e.target.value)}
            className="input"
          >
            <option>BCA</option>
            <option>BTech</option>
            <option>MCA</option>
            <option>MTech</option>
            <option>Other</option>
          </select>
        </Field>

        <Field label="College">
          <input
            value={college}
            onChange={(e) => setCollege(e.target.value)}
            className="input"
          />
        </Field>

        <Field label="Email">
          <input
            required
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="input"
          />
        </Field>

        <Field label="Password">
          <input
            required
            type="password"
            minLength={6}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="input"
          />
        </Field>

        {error && <p className="text-sm text-red-600">{error}</p>}

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-signal text-paper py-3 rounded font-medium hover:bg-signalDark transition-colors disabled:opacity-50"
        >
          {loading ? "Creating account…" : "Create account"}
        </button>
      </form>

      <style jsx global>{`
        .input {
          width: 100%;
          border: 1px solid #dcd8c8;
          border-radius: 6px;
          padding: 10px 12px;
          background: white;
        }
      `}</style>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="block text-sm font-medium mb-1">{label}</span>
      {children}
    </label>
  );
}
