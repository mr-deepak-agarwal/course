"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export default function VerifyForm() {
  const router = useRouter();
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();

    // Accept a pasted full URL as well as a bare code.
    const cleaned = code.trim().replace(/^.*\/verify\//, "").replace(/[^a-zA-Z0-9]/g, "");

    if (!cleaned) {
      setError("Enter the certificate code printed on the certificate.");
      return;
    }

    setError(null);
    router.push(`/verify/${cleaned.toLowerCase()}`);
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-3">
      <label className="block">
        <span className="block text-sm font-medium mb-1">Certificate code</span>
        <input
          value={code}
          onChange={(e) => setCode(e.target.value)}
          placeholder="a1b2c3d4e5f6"
          autoComplete="off"
          spellCheck={false}
          className="w-full border border-line rounded px-3 py-3 bg-panel stamp tracking-widest"
        />
      </label>

      {error && <p className="text-sm text-red-600">{error}</p>}

      <button
        type="submit"
        className="w-full bg-signal text-paper py-3 rounded font-medium hover:bg-signalDark transition-colors"
      >
        Verify
      </button>
    </form>
  );
}
