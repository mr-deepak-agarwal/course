import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export default async function Navbar() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <header className="border-b border-line bg-paper">
      <div className="max-w-5xl mx-auto px-6 py-4 flex items-center justify-between">
        <Link href="/" className="font-display text-xl font-semibold text-ink">
          Job-Ready Portal
        </Link>
        <nav className="flex items-center gap-6 text-sm">
          {user ? (
            <>
              <Link href="/dashboard" className="hover:text-signal">
                My Courses
              </Link>
              <form action="/auth/sign-out" method="post">
                <button className="hover:text-signal" type="submit">
                  Sign out
                </button>
              </form>
            </>
          ) : (
            <>
              <Link href="/login" className="hover:text-signal">
                Log in
              </Link>
              <Link
                href="/signup"
                className="bg-signal text-paper px-4 py-2 rounded hover:bg-signalDark transition-colors"
              >
                Get started
              </Link>
            </>
          )}
        </nav>
      </div>
    </header>
  );
}
