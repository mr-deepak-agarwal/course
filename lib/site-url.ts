import { headers } from "next/headers";

/**
 * The absolute base URL the QR code should point at.
 *
 * Set NEXT_PUBLIC_SITE_URL in production — a QR printed from a laptop
 * running on localhost is useless on a student's phone. Falls back to
 * the request host so local dev still works.
 */
export function siteUrl(request?: Request): string {
  const configured = process.env.NEXT_PUBLIC_SITE_URL;
  if (configured) return configured.replace(/\/$/, "");

  if (request) {
    return new URL(request.url).origin;
  }

  const h = headers();
  const host = h.get("x-forwarded-host") ?? h.get("host") ?? "localhost:3000";
  const proto = h.get("x-forwarded-proto") ?? (host.startsWith("localhost") ? "http" : "https");
  return `${proto}://${host}`;
}
