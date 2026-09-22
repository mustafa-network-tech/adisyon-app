import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";

// Exchanges the `code` from a Supabase invite/magic-link/signup-confirm
// email for a session cookie, then sends the user on to finish
// onboarding. Two callers: staff invites (see
// isletme/personel/actions.ts, next defaults to /davet/sifre-olustur)
// and self-service signup email confirmation (see kayit/signup-form.tsx,
// next=/kayit/tamamla, which finishes creating the business once a
// session exists here).
export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/davet/sifre-olustur";

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`);
    }
  }

  return NextResponse.redirect(`${origin}/giris?error=davet-linki-gecersiz`);
}
