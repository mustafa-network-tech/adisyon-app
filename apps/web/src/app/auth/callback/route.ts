import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";

// Exchanges the `code` from a Supabase invite/magic-link email for a
// session cookie, then sends the user on to finish onboarding. Used by
// the "new business admin" invite sent when a Super Admin approves a
// business application (see super-admin/basvurular/[id]/actions.ts).
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
