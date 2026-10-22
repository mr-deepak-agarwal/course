import fs from "fs";
import path from "path";

/** Who signs the certificates. Change these two lines to change every certificate. */
export const ISSUER_NAME = "Mr. Deepak Agarwal";
export const ISSUER_TITLE = "Founder, codeq.tech";
export const BRAND_NAME = "codeq";
export const BRAND_SUFFIX = ".tech";

/** "deepak agarwal" -> "Deepak Agarwal" (only raises the first letter of each word). */
export function titleCaseName(name: string): string {
  return name.replace(/(^|[\s'-])(\p{L})/gu, (_, sep: string, ch: string) => sep + ch.toUpperCase());
}

function readPublic(file: string): Buffer | null {
  try {
    return fs.readFileSync(path.join(process.cwd(), "public", file));
  } catch {
    return null;
  }
}

/**
 * Optional images. Drop these files into the /public folder:
 *   public/codeq-logo.png   - your logo (transparent PNG, ~600px wide works well)
 *   public/signature.png    - a scan of your signature (transparent PNG)
 * If a file is missing, a text wordmark / typed signature is used instead.
 */
export const readLogoPng = () => readPublic("codeq-logo.png");
export const readSignaturePng = () => readPublic("signature.png");
