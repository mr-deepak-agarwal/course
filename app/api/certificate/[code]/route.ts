import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { buildCertificatePdf, type CertificateData } from "@/lib/certificate/pdf";
import { siteUrl } from "@/lib/site-url";

export const runtime = "nodejs";

export async function GET(
  request: Request,
  { params }: { params: { code: string } }
) {
  const supabase = createClient();

  // verify_certificate is a security-definer function granted to anon,
  // so this works for anyone holding the code — no login required.
  const { data, error } = await supabase.rpc("verify_certificate", {
    p_code: params.code,
  });

  const cert = (data as CertificateData[] | null)?.[0];

  if (error || !cert) {
    return NextResponse.json({ error: "Certificate not found" }, { status: 404 });
  }

  const verifyUrl = `${siteUrl(request)}/verify/${cert.certificate_code}`;
  const pdf = await buildCertificatePdf(cert, verifyUrl);

  const safeName = cert.student_name.replace(/[^a-z0-9]+/gi, "-").toLowerCase();

  return new NextResponse(Buffer.from(pdf), {
    headers: {
      "Content-Type": "application/pdf",
      "Content-Disposition": `attachment; filename="certificate-${safeName}-${cert.certificate_code}.pdf"`,
      "Cache-Control": "public, max-age=3600",
    },
  });
}
