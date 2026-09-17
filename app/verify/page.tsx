import VerifyForm from "@/components/VerifyForm";

export const metadata = {
  title: "Verify a certificate — Job-Ready Portal",
  description: "Check whether a Job-Ready Portal certificate is genuine.",
};

export default function VerifyLandingPage() {
  return (
    <div className="max-w-xl mx-auto px-6 py-20">
      <p className="stamp text-xs text-signal mb-3">Certificate verification</p>
      <h1 className="font-display text-4xl font-semibold mb-3">
        Check a certificate
      </h1>
      <p className="text-ink/60 mb-8">
        Scan the QR code printed on the certificate, or enter its code below.
        Verification is public — no account needed.
      </p>

      <VerifyForm />

      <div className="mt-12 border-t border-line pt-6 text-sm text-ink/50">
        <p className="mb-2">
          The code is the 12-character string printed at the bottom-right of the
          certificate, for example <code className="stamp text-ink/70">a1b2c3d4e5f6</code>.
        </p>
        <p>
          Employers can confirm a candidate&apos;s result here without contacting us.
        </p>
      </div>
    </div>
  );
}
