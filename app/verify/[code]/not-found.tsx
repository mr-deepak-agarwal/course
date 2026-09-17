import Link from "next/link";

export default function CertificateNotFound() {
  return (
    <div className="max-w-xl mx-auto px-6 py-24 text-center">
      <p className="stamp text-xs text-amber mb-3">Not verified</p>
      <h1 className="font-display text-3xl font-semibold mb-3">
        No certificate matches that code
      </h1>
      <p className="text-ink/60 mb-8">
        Check the code for typos — it&apos;s 12 characters, letters and digits only.
        If it still doesn&apos;t match, this certificate was not issued by us.
      </p>
      <Link
        href="/verify"
        className="inline-block bg-signal text-paper px-6 py-3 rounded font-medium hover:bg-signalDark transition-colors"
      >
        Try another code
      </Link>
    </div>
  );
}
