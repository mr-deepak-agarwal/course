import type { Metadata } from "next";
import "./globals.css";
import Navbar from "@/components/Navbar";

export const metadata: Metadata = {
  title: "Job-Ready Portal",
  description: "Courses that end in proof, not just a certificate of attendance.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="font-body min-h-screen flex flex-col">
        <Navbar />
        <main className="flex-1">{children}</main>
        <footer className="border-t border-line py-6 text-center text-sm text-ink/60 stamp">
          Job-Ready Portal — built by codeq.tech
        </footer>
      </body>
    </html>
  );
}
