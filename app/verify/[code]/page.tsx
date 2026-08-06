import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export default async function VerifyPage({ params }: { params: { code: string } }) {
  const supabase = createClient();

  const { data: cert } = await supabase
    .from("certificate_public")
    .select("certificate_code, student_name, stream, course_title, issued_at")
    .eq("certificate_code", params.code)
    .maybeSingle();

  if (!cert) notFound();

  const issuedDate = new Date(cert.issued_at).toLocaleDateString("en-IN", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });

  return (
    <div className="max-w-2xl mx-auto px-6 py-16">
      <div className="border-2 border-ink rounded p-10 bg-panel text-center relative">
        <p className="stamp text-xs text-signal mb-6">Verified Certificate</p>

        <h1 className="font-display text-2xl text-ink/60 mb-2">This certifies that</h1>
        <p className="font-display text-4xl font-semibold mb-6">{cert.student_name}</p>

        <h2 className="font-display text-xl text-ink/60 mb-2">has completed</h2>
        <p className="font-display text-2xl font-semibold text-signal mb-8">
          {cert.course_title}
        </p>

        <div className="flex justify-center gap-10 text-sm text-ink/60 stamp">
          <div>
            <p className="text-ink/40">Issued</p>
            <p>{issuedDate}</p>
          </div>
          <div>
            <p className="text-ink/40">Stream</p>
            <p>{cert.stream}</p>
          </div>
          <div>
            <p className="text-ink/40">Code</p>
            <p>{cert.certificate_code}</p>
          </div>
        </div>
      </div>

      <p className="text-center text-xs text-ink/40 mt-6 stamp">
        job-ready-portal.example / verify / {cert.certificate_code}
      </p>
    </div>
  );
}
