import { notFound } from "next/navigation";
import QRCode from "qrcode";
import { createClient } from "@/lib/supabase/server";
import { siteUrl } from "@/lib/site-url";
import type { CertificateData } from "@/lib/certificate/pdf";
import {
  BRAND_NAME,
  BRAND_SUFFIX,
  ISSUER_NAME,
  ISSUER_TITLE,
  readLogoPng,
  readSignaturePng,
  titleCaseName,
} from "@/lib/certificate/branding";

export default async function VerifyPage({ params }: { params: { code: string } }) {
  const supabase = createClient();

  const { data } = await supabase.rpc("verify_certificate", {
    p_code: params.code.trim().toLowerCase(),
  });
  const cert = (data as CertificateData[] | null)?.[0];

  if (!cert) notFound();

  const verifyUrl = `${siteUrl()}/verify/${cert.certificate_code}`;
  const qrDataUrl = await QRCode.toDataURL(verifyUrl, { margin: 0, width: 240 });

  const issuedDate = new Date(cert.issued_at).toLocaleDateString("en-IN", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });

  const hasLogo = readLogoPng() !== null;
  const hasSignature = readSignaturePng() !== null;
  const studentName = titleCaseName(cert.student_name);

  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 py-12">
      <p className="stamp text-xs text-signal mb-4 text-center">
        ✓ Verified — this certificate is genuine
      </p>

      {/* Certificate: double frame with corner accents */}
      <div className="border-[3px] border-ink p-1.5 bg-[#fbfaf4]">
        <div className="border border-amber p-1">
          <div className="relative border border-signal/60 px-6 sm:px-14 py-10 text-center">
            <span className="absolute top-2 left-2 w-6 h-6 border-t-[3px] border-l-[3px] border-signal" />
            <span className="absolute top-2 right-2 w-6 h-6 border-t-[3px] border-r-[3px] border-signal" />
            <span className="absolute bottom-2 left-2 w-6 h-6 border-b-[3px] border-l-[3px] border-signal" />
            <span className="absolute bottom-2 right-2 w-6 h-6 border-b-[3px] border-r-[3px] border-signal" />

            {/* Logo */}
            <div className="flex justify-center mb-5 h-12 items-center">
              {hasLogo ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src="/codeq-logo.png" alt={`${BRAND_NAME}${BRAND_SUFFIX}`} className="max-h-12 w-auto" />
              ) : (
                <span className="font-display text-3xl font-bold tracking-tight">
                  {BRAND_NAME}
                  <span className="text-signal">{BRAND_SUFFIX}</span>
                </span>
              )}
            </div>

            <h1 className="font-display text-4xl sm:text-5xl font-bold tracking-wide">CERTIFICATE</h1>
            <p className="stamp text-xs text-signal mt-1 mb-3">of Completion</p>
            <div className="mx-auto w-16 border-t-2 border-amber mb-6" />

            <p className="font-display italic text-ink/60 mb-2">This is to certify that</p>
            <p className="font-display text-3xl sm:text-5xl font-semibold pb-2 border-b border-ink/30 inline-block px-6 mb-4">
              {studentName}
            </p>
            <p className="font-display italic text-ink/60 mt-2 mb-2">has successfully completed the course</p>
            <p className="font-display text-2xl sm:text-3xl font-semibold text-signal mb-2">
              {cert.course_title}
            </p>
            <p className="font-display italic text-sm text-ink/50 mb-10">
              and cleared the final assessment on the Job-Ready Portal.
            </p>

            {/* Date / seal / signature */}
            <div className="grid grid-cols-1 sm:grid-cols-3 items-end gap-8 mb-8">
              <div>
                <p className="font-display text-lg border-b border-ink pb-1 px-2">{issuedDate}</p>
                <p className="stamp text-[10px] text-ink/50 mt-1.5">Date of issue</p>
              </div>

              <div className="flex justify-center order-first sm:order-none">
                <div className="w-24 h-24 rounded-full bg-signal ring-2 ring-amber ring-offset-2 ring-offset-[#fbfaf4] flex flex-col items-center justify-center text-paper">
                  <span className="stamp text-[9px]">Verified</span>
                  <span className="font-display font-bold text-sm leading-tight">
                    {BRAND_NAME}
                    {BRAND_SUFFIX}
                  </span>
                  <span className="stamp text-[7px] opacity-80">Certified</span>
                </div>
              </div>

              <div>
                <div className="h-10 flex items-end justify-center border-b border-ink pb-1">
                  {hasSignature ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src="/signature.png" alt="Signature" className="max-h-10 w-auto" />
                  ) : (
                    <span className="font-display italic text-2xl leading-none">Deepak Agarwal</span>
                  )}
                </div>
                <p className="font-display font-semibold text-sm mt-1.5">{ISSUER_NAME}</p>
                <p className="stamp text-[10px] text-ink/50">{ISSUER_TITLE}</p>
              </div>
            </div>

            {/* ID + QR */}
            <div className="flex flex-wrap items-center justify-between gap-4 text-left">
              <div>
                <p className="stamp text-[10px] text-ink/50">Certificate ID</p>
                <p className="stamp text-base font-semibold">{cert.certificate_code.toUpperCase()}</p>
                <p className="stamp text-[10px] text-ink/50 mt-1">Stream: {cert.stream ?? "—"}</p>
              </div>
              <div className="text-center">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={qrDataUrl} alt="Verification QR code" className="w-20 h-20 mx-auto" />
                <p className="stamp text-[9px] text-ink/40 mt-1">Scan to verify</p>
              </div>
            </div>
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
