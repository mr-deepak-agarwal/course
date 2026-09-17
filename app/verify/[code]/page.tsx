import { notFound } from "next/navigation";
import QRCode from "qrcode";
import { createClient } from "@/lib/supabase/server";
import { siteUrl } from "@/lib/site-url";
import type { CertificateData } from "@/lib/certificate/pdf";

export default async function VerifyPage({ params }: { params: { code: string } }) {
  const supabase = createClient();

  const { data } = await supabase.rpc("verify_certificate", { p_code: params.code });
  const cert = (data as CertificateData[] | null)?.[0];

  if (!cert) notFound();

  const verifyUrl = `${siteUrl()}/verify/${cert.certificate_code}`;
  const qrDataUrl = await QRCode.toDataURL(verifyUrl, { margin: 0, width: 240 });

  const issuedDate = new Date(cert.issued_at).toLocaleDateString("en-IN", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });

  return (
    <div className="max-w-2xl mx-auto px-6 py-16">
      <p className="stamp text-xs text-signal mb-4 text-center">
        ✓ Verified — this certificate is genuine
      </p>

      <div className="border-2 border-ink rounded p-10 bg-panel text-center">
        <p className="stamp text-xs text-signal mb-6">Certificate of Completion</p>

        <h1 className="font-display text-2xl text-ink/60 mb-2">This certifies that</h1>
        <p className="font-display text-4xl font-semibold mb-6">{cert.student_name}</p>

        <h2 className="font-display text-xl text-ink/60 mb-2">has completed</h2>
        <p className="font-display text-2xl font-semibold text-signal mb-8">
          {cert.course_title}
        </p>

        <div className="flex flex-wrap justify-center items-start gap-10 text-sm text-ink/60 stamp">
          <div>
            <p className="text-ink/40">Issued</p>
            <p>{issuedDate}</p>
          </div>
          <div>
            <p className="text-ink/40">Stream</p>
            <p>{cert.stream ?? "—"}</p>
          </div>
          <div>
            <p className="text-ink/40">Code</p>
            <p>{cert.certificate_code}</p>
          </div>
          <div>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={qrDataUrl} alt="Verification QR code" className="w-20 h-20" />
            <p className="text-ink/40 text-[10px] mt-1">Scan to verify</p>
          </div>
        </div>
      </div>

      <div className="mt-8 flex flex-col sm:flex-row gap-3 justify-center">
        <a
          href={`/api/certificate/${cert.certificate_code}`}
          className="bg-signal text-paper px-6 py-3 rounded font-medium text-center hover:bg-signalDark transition-colors"
        >
          Download PDF
        </a>
        <a
          href="/verify"
          className="border border-line px-6 py-3 rounded text-center hover:border-signal transition-colors"
        >
          Verify another certificate
        </a>
      </div>

      <p className="text-center text-xs text-ink/40 mt-6 stamp break-all">{verifyUrl}</p>
    </div>
  );
}
