"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type Step = "working" | "error";

export function CompleteSignup() {
  const router = useRouter();
  const [step, setStep] = useState<Step>("working");

  useEffect(() => {
    let cancelled = false;

    async function run() {
      const supabase = createClient();

      const {
        data: { user },
      } = await supabase.auth.getUser();

      if (!user) {
        router.replace("/giris?next=/kayit/tamamla");
        return;
      }

      // Idempotency: if this user already has a business (e.g. they
      // clicked the confirmation link twice), don't create a second one.
      const { data: existingMembership } = await supabase
        .from("business_memberships")
        .select("id")
        .eq("user_id", user.id)
        .limit(1)
        .maybeSingle();

      if (existingMembership) {
        router.replace("/isletme");
        return;
      }

      const meta = (user.user_metadata ?? {}) as Record<string, unknown>;
      const pendingName = typeof meta.pending_business_name === "string" ? meta.pending_business_name : null;

      if (!pendingName) {
        // Not a self-service signup in progress (e.g. an invited staff
        // member's confirmation link) -- send them to the generic
        // post-login router instead.
        router.replace("/hesabim");
        return;
      }

      const { error } = await supabase.rpc("create_own_business", {
        p_name: pendingName,
        p_business_type: (meta.pending_business_type as string | null) ?? null,
        p_city: (meta.pending_business_city as string | null) ?? null,
        p_address: (meta.pending_business_address as string | null) ?? null,
        p_phone: (meta.pending_business_phone as string | null) ?? null,
        p_email: user.email ?? null,
      });

      if (cancelled) return;

      if (error) {
        setStep("error");
        return;
      }

      router.replace("/isletme");
      router.refresh();
    }

    run();
    return () => {
      cancelled = true;
    };
  }, [router]);

  if (step === "error") {
    return (
      <div className="rounded-xl border border-red-200 bg-red-50 p-6 text-center shadow-sm">
        <h1 className="text-lg font-semibold text-red-800">Bir şeyler ters gitti</h1>
        <p className="mt-2 text-sm leading-6 text-red-700">
          E-postanız onaylandı ancak işletmeniz oluşturulamadı. Lütfen giriş yapıp tekrar
          deneyin veya destek ile iletişime geçin.
        </p>
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-zinc-200 bg-white p-6 text-center shadow-sm">
      <h1 className="text-lg font-semibold text-zinc-900">Hesabınız Hazırlanıyor</h1>
      <p className="mt-2 text-sm leading-6 text-zinc-600">Lütfen bekleyin...</p>
    </div>
  );
}
