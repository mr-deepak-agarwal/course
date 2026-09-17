import { PDFDocument, StandardFonts, rgb } from "pdf-lib";
import QRCode from "qrcode";

export type CertificateData = {
  certificate_code: string;
  student_name: string;
  stream: string | null;
  course_title: string;
  issued_at: string;
};

const INK = rgb(0.063, 0.102, 0.09);
const SIGNAL = rgb(0.122, 0.435, 0.29);
const PAPER = rgb(0.965, 0.961, 0.937);
const MUTED = rgb(0.45, 0.47, 0.46);

/**
 * Renders the certificate as an A4-landscape PDF with a QR code that
 * points back at the public verification URL. Deterministic — the same
 * code always produces the same file, so re-downloads need no storage.
 */
export async function buildCertificatePdf(
  cert: CertificateData,
  verifyUrl: string
): Promise<Uint8Array> {
  const pdf = await PDFDocument.create();
  const page = pdf.addPage([842, 595]);
  const { width, height } = page.getSize();

  const serif = await pdf.embedFont(StandardFonts.TimesRoman);
  const serifBold = await pdf.embedFont(StandardFonts.TimesRomanBold);
  const sans = await pdf.embedFont(StandardFonts.Helvetica);

  pdf.setTitle(`${cert.course_title} — ${cert.student_name}`);
  pdf.setSubject(`Certificate ${cert.certificate_code}`);

  page.drawRectangle({ x: 0, y: 0, width, height, color: PAPER });
  page.drawRectangle({
    x: 28,
    y: 28,
    width: width - 56,
    height: height - 56,
    borderColor: INK,
    borderWidth: 2,
  });
  page.drawRectangle({
    x: 38,
    y: 38,
    width: width - 76,
    height: height - 76,
    borderColor: SIGNAL,
    borderWidth: 0.75,
  });

  const center = (
    text: string,
    font: typeof serif,
    size: number,
    y: number,
    color = INK
  ) => {
    const w = font.widthOfTextAtSize(text, size);
    page.drawText(text, { x: (width - w) / 2, y, size, font, color });
  };

  center("CERTIFICATE OF COMPLETION", sans, 11, height - 96, SIGNAL);
  center("This certifies that", serif, 16, height - 150, MUTED);
  center(cert.student_name, serifBold, 40, height - 205);
  center("has successfully completed", serif, 16, height - 250, MUTED);
  center(cert.course_title, serifBold, 26, height - 295, SIGNAL);
  center("Job-Ready Portal  ·  codeq.tech", sans, 9, height - 330, MUTED);

  const issued = new Date(cert.issued_at).toLocaleDateString("en-IN", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });

  const baseY = 120;
  const field = (x: number, label: string, value: string) => {
    page.drawLine({
      start: { x, y: baseY + 26 },
      end: { x: x + 160, y: baseY + 26 },
      color: MUTED,
      thickness: 0.5,
    });
    page.drawText(label, { x, y: baseY + 8, size: 8, font: sans, color: MUTED });
    page.drawText(value, { x, y: baseY - 10, size: 11, font: serif, color: INK });
  };

  field(90, "Issued", issued);
  field(300, "Stream", cert.stream ?? "—");
  field(510, "Certificate code", cert.certificate_code);

  const qrDataUrl = await QRCode.toDataURL(verifyUrl, { margin: 0, width: 300 });
  const qrImage = await pdf.embedPng(qrDataUrl);
  const qrSize = 88;
  const qrX = width - 90 - qrSize;
  page.drawImage(qrImage, { x: qrX, y: baseY - 6, width: qrSize, height: qrSize });
  page.drawText("Scan to verify", {
    x: qrX,
    y: baseY - 20,
    size: 7,
    font: sans,
    color: MUTED,
  });

  const fw = sans.widthOfTextAtSize(verifyUrl, 8);
  page.drawText(verifyUrl, {
    x: (width - fw) / 2,
    y: 52,
    size: 8,
    font: sans,
    color: MUTED,
  });

  return pdf.save();
}
