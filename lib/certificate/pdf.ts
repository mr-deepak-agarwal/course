import { PDFDocument, StandardFonts, rgb } from "pdf-lib";
import QRCode from "qrcode";
import {
  BRAND_NAME,
  BRAND_SUFFIX,
  ISSUER_NAME,
  ISSUER_TITLE,
  readLogoPng,
  readSignaturePng,
  titleCaseName,
} from "./branding";

export type CertificateData = {
  certificate_code: string;
  student_name: string;
  stream: string | null;
  course_title: string;
  issued_at: string;
};

const INK = rgb(0.063, 0.102, 0.09);
const SIGNAL = rgb(0.122, 0.435, 0.29);
const GOLD = rgb(0.78, 0.49, 0.18);
const PAPER = rgb(0.985, 0.98, 0.955);
const MUTED = rgb(0.4, 0.42, 0.41);

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
  const cx = width / 2;

  const serif = await pdf.embedFont(StandardFonts.TimesRoman);
  const serifBold = await pdf.embedFont(StandardFonts.TimesRomanBold);
  const serifItalic = await pdf.embedFont(StandardFonts.TimesRomanItalic);
  const sans = await pdf.embedFont(StandardFonts.Helvetica);
  const sansBold = await pdf.embedFont(StandardFonts.HelveticaBold);

  const studentName = titleCaseName(cert.student_name);
  pdf.setTitle(`${cert.course_title} — ${studentName}`);
  pdf.setSubject(`Certificate ${cert.certificate_code}`);
  pdf.setAuthor(`${BRAND_NAME}${BRAND_SUFFIX}`);

  const centered = (
    text: string,
    font: typeof serif,
    size: number,
    y: number,
    color = INK,
    x = cx
  ) => {
    const w = font.widthOfTextAtSize(text, size);
    page.drawText(text, { x: x - w / 2, y, size, font, color });
  };

  // ---------- background + frame ----------
  page.drawRectangle({ x: 0, y: 0, width, height, color: PAPER });
  page.drawRectangle({ x: 22, y: 22, width: width - 44, height: height - 44, borderColor: INK, borderWidth: 2.5 });
  page.drawRectangle({ x: 31, y: 31, width: width - 62, height: height - 62, borderColor: GOLD, borderWidth: 1 });
  page.drawRectangle({ x: 36, y: 36, width: width - 72, height: height - 72, borderColor: SIGNAL, borderWidth: 0.5 });

  // corner accents
  const arm = 26;
  const inset = 46;
  const corners: [number, number, number, number][] = [
    [inset, height - inset, 1, -1],
    [width - inset, height - inset, -1, -1],
    [inset, inset, 1, 1],
    [width - inset, inset, -1, 1],
  ];
  for (const [x, y, dx, dy] of corners) {
    page.drawLine({ start: { x, y }, end: { x: x + dx * arm, y }, color: SIGNAL, thickness: 3 });
    page.drawLine({ start: { x, y }, end: { x, y: y + dy * arm }, color: SIGNAL, thickness: 3 });
  }

  // ---------- logo (PNG if provided, else text wordmark) ----------
  const logoBytes = readLogoPng();
  let logoDrawn = false;
  if (logoBytes) {
    try {
      const logo = await pdf.embedPng(logoBytes);
      const scale = Math.min(190 / logo.width, 46 / logo.height);
      const w = logo.width * scale;
      const h = logo.height * scale;
      page.drawImage(logo, { x: cx - w / 2, y: height - 66 - h, width: w, height: h });
      logoDrawn = true;
    } catch {
      /* fall through to the wordmark */
    }
  }
  if (!logoDrawn) {
    const a = serifBold.widthOfTextAtSize(BRAND_NAME, 30);
    const b = serifBold.widthOfTextAtSize(BRAND_SUFFIX, 30);
    const x0 = cx - (a + b) / 2;
    page.drawText(BRAND_NAME, { x: x0, y: height - 100, size: 30, font: serifBold, color: INK });
    page.drawText(BRAND_SUFFIX, { x: x0 + a, y: height - 100, size: 30, font: serifBold, color: SIGNAL });
  }

  // ---------- heading ----------
  centered("CERTIFICATE", serifBold, 38, height - 158);
  centered("OF COMPLETION", sansBold, 11, height - 180, SIGNAL);
  page.drawLine({ start: { x: cx - 50, y: height - 194 }, end: { x: cx + 50, y: height - 194 }, color: GOLD, thickness: 1.5 });

  // ---------- body ----------
  centered("This is to certify that", serifItalic, 16, height - 226, MUTED);
  centered(studentName, serifBold, 40, height - 274);
  page.drawLine({ start: { x: cx - 190, y: height - 286 }, end: { x: cx + 190, y: height - 286 }, color: MUTED, thickness: 0.5 });
  centered("has successfully completed the course", serifItalic, 16, height - 313, MUTED);
  centered(cert.course_title, serifBold, 26, height - 348, SIGNAL);
  centered("and cleared the final assessment on the Job-Ready Portal.", serifItalic, 13, height - 372, MUTED);

  // ---------- date (left) / seal (centre) / signature (right) ----------
  const lineY = 150;

  // date of issue
  const issued = new Date(cert.issued_at).toLocaleDateString("en-IN", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
  const dateCx = 170;
  centered(issued, serif, 15, lineY + 6, INK, dateCx);
  page.drawLine({ start: { x: dateCx - 95, y: lineY }, end: { x: dateCx + 95, y: lineY }, color: INK, thickness: 0.7 });
  centered("DATE OF ISSUE", sansBold, 8, lineY - 14, MUTED, dateCx);

  // signature
  const sigCx = width - 170;
  const sigBytes = readSignaturePng();
  let sigDrawn = false;
  if (sigBytes) {
    try {
      const sig = await pdf.embedPng(sigBytes);
      const scale = Math.min(150 / sig.width, 48 / sig.height);
      const w = sig.width * scale;
      const h = sig.height * scale;
      page.drawImage(sig, { x: sigCx - w / 2, y: lineY + 4, width: w, height: h });
      sigDrawn = true;
    } catch {
      /* fall through */
    }
  }
  if (!sigDrawn) {
    centered("Deepak Agarwal", serifItalic, 24, lineY + 8, INK, sigCx);
  }
  page.drawLine({ start: { x: sigCx - 95, y: lineY }, end: { x: sigCx + 95, y: lineY }, color: INK, thickness: 0.7 });
  centered(ISSUER_NAME, serifBold, 13, lineY - 15, INK, sigCx);
  centered(ISSUER_TITLE, sans, 9, lineY - 29, MUTED, sigCx);

  // seal
  const sealY = lineY + 22;
  page.drawCircle({ x: cx, y: sealY, size: 44, color: SIGNAL });
  page.drawCircle({ x: cx, y: sealY, size: 44, borderColor: GOLD, borderWidth: 2.5 });
  page.drawCircle({ x: cx, y: sealY, size: 37, borderColor: PAPER, borderWidth: 1 });
  centered("VERIFIED", sansBold, 9, sealY + 6, PAPER);
  centered(`${BRAND_NAME}${BRAND_SUFFIX}`, serifBold, 11, sealY - 8, PAPER);
  centered("CERTIFIED", sansBold, 6, sealY - 20, PAPER);

  // ---------- QR + id ----------
  const qrDataUrl = await QRCode.toDataURL(verifyUrl, { margin: 0, width: 300 });
  const qrImage = await pdf.embedPng(qrDataUrl);
  const qrSize = 50;
  page.drawImage(qrImage, { x: cx - qrSize / 2, y: 48, width: qrSize, height: qrSize });

  page.drawText("CERTIFICATE ID", { x: 84, y: 84, size: 7, font: sansBold, color: MUTED });
  page.drawText(cert.certificate_code.toUpperCase(), { x: 84, y: 68, size: 13, font: sansBold, color: INK });

  const verifyLabel = "Verify at";
  const vw = sans.widthOfTextAtSize(verifyUrl, 8);
  const rightX = width - 84;
  page.drawText(verifyLabel.toUpperCase(), {
    x: rightX - Math.max(vw, 40),
    y: 84,
    size: 7,
    font: sansBold,
    color: MUTED,
  });
  page.drawText(verifyUrl, { x: rightX - vw, y: 70, size: 8, font: sans, color: INK });

  return pdf.save();
}
