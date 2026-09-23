"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { LEGAL_LINKS } from "@/lib/legal-links";

const inputClass =
  "w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 outline-none placeholder:text-zinc-400 focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500";
const labelClass = "mb-1.5 block text-sm font-medium text-zinc-800";
const sectionTitleClass = "text-xs font-semibold uppercase tracking-wide text-zinc-500";

// Collects both the owner's account fields and the new business's
// profile fields in one form, then:
//   1. supabase.auth.signUp() -- the business fields are stashed on
//      user_metadata (pending_business_*) so they survive an email
//      confirmation round-trip if the project requires one.
//   2. If signUp already returns a session (email confirmation
//      disabled), create_own_business is called immediately and the
//      user lands straight in their new business panel.
//   3. If not (confirmation required), the user is sent to
//      /kayit/beklemede; /kayit/tamamla finishes step 2 once they
//      click the confirmation link and land back with a session (see
//      emailRedirectTo below).
export function SignupForm() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  const [ownerName, setOwnerName] = useState("");
  const [ownerPhone, setOwnerPhone] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const [businessName, setBusinessName] = useState("");
  const [businessType, setBusinessType] = useState("");
  const [city, setCity] = useState("");
  const [address, setAddress] = useState("");
  const [businessPhone, setBusinessPhone] = useState("");
  const [termsAccepted, setTermsAccepted] = useState(false);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);

    if (!termsAccepted) {
      setError("Devam etmek için Kullanım Koşulları'nı kabul etmelisiniz.");
      return;
    }

    if (password.length < 8) {
      setError("Şifre en az 8 karakter olmalıdır.");
      return;
    }
    if (!businessName.trim()) {
      setError("İşletme adı boş olamaz.");
      return;
    }

    setPending(true);
    const supabase = createClient();

    const { data, error: signUpError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name: ownerName || null,
          phone: ownerPhone || null,
          pending_business_name: businessName.trim(),
          pending_business_type: businessType.trim() || null,
          pending_business_city: city.trim() || null,
          pending_business_address: address.trim() || null,
          pending_business_phone: businessPhone.trim() || null,
        },
        emailRedirectTo: `${window.location.origin}/auth/callback?next=/kayit/tamamla`,
      },
    });

    if (signUpError) {
      setPending(false);
      setError(
        signUpError.message.toLowerCase().includes("already")
          ? "Bu e-posta adresiyle zaten bir hesap var. Giriş yapmayı deneyin."
          : "Hesap oluşturulamadı. Lütfen tekrar deneyin."
      );
      return;
    }

    if (data.session) {
      const { error: businessError } = await supabase.rpc("create_own_business", {
        p_name: businessName.trim(),
        p_business_type: businessType.trim() || null,
        p_city: city.trim() || null,
        p_address: address.trim() || null,
        p_phone: businessPhone.trim() || null,
        p_email: email,
      });
      setPending(false);

      if (businessError) {
        setError("Hesap oluşturuldu ancak işletme kaydı tamamlanamadı. Giriş yapıp tekrar deneyin.");
        return;
      }

      router.push("/isletme");
      router.refresh();
      return;
    }

    setPending(false);
    router.push("/kayit/beklemede");
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      <div className="space-y-4">
        <p className={sectionTitleClass}>Hesabınız</p>
        <div>
          <label className={labelClass} htmlFor="owner_name">
            Ad Soyad
          </label>
          <input
            id="owner_name"
            required
            value={ownerName}
            onChange={(e) => setOwnerName(e.target.value)}
            className={inputClass}
          />
        </div>
        <div>
          <label className={labelClass} htmlFor="email">
            E-posta
          </label>
          <input
            id="email"
            type="email"
            required
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className={inputClass}
          />
        </div>
        <div>
          <label className={labelClass} htmlFor="password">
            Şifre
          </label>
          <input
            id="password"
            type="password"
            required
            autoComplete="new-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className={inputClass}
          />
        </div>
        <div>
          <label className={labelClass} htmlFor="owner_phone">
            Telefon
          </label>
          <input
            id="owner_phone"
            value={ownerPhone}
            onChange={(e) => setOwnerPhone(e.target.value)}
            className={inputClass}
          />
        </div>
      </div>

      <div className="space-y-4 border-t border-zinc-100 pt-5">
        <p className={sectionTitleClass}>İşletmeniz</p>
        <div>
          <label className={labelClass} htmlFor="business_name">
            İşletme Adı
          </label>
          <input
            id="business_name"
            required
            value={businessName}
            onChange={(e) => setBusinessName(e.target.value)}
            className={inputClass}
          />
        </div>
        <div>
          <label className={labelClass} htmlFor="business_type">
            İşletme Türü
          </label>
          <input
            id="business_type"
            placeholder="Restoran, kafe, ..."
            value={businessType}
            onChange={(e) => setBusinessType(e.target.value)}
            className={inputClass}
          />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className={labelClass} htmlFor="city">
              Şehir
            </label>
            <input
              id="city"
              value={city}
              onChange={(e) => setCity(e.target.value)}
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass} htmlFor="business_phone">
              İşletme Telefonu
            </label>
            <input
              id="business_phone"
              value={businessPhone}
              onChange={(e) => setBusinessPhone(e.target.value)}
              className={inputClass}
            />
          </div>
        </div>
        <div>
          <label className={labelClass} htmlFor="address">
            Adres
          </label>
          <input
            id="address"
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            className={inputClass}
          />
        </div>
      </div>

      {/* Terms acceptance is the only checkbox. The KVKK notice is
          informational (KVKK md. 10), not consent, so it is shown as a
          link and must not be bundled into this acceptance. */}
      <div className="space-y-3 border-t border-zinc-100 pt-5">
        <label className="flex items-start gap-2.5 text-sm text-zinc-700" htmlFor="terms_accepted">
          <input
            id="terms_accepted"
            type="checkbox"
            required
            checked={termsAccepted}
            onChange={(e) => setTermsAccepted(e.target.checked)}
            className="mt-0.5 h-4 w-4 shrink-0 rounded border-zinc-300 accent-zinc-900"
          />
          <span>
            Üyelik oluşturarak{" "}
            <a
              href={LEGAL_LINKS.terms}
              target="_blank"
              rel="noopener noreferrer"
              className="font-medium text-zinc-900 underline underline-offset-2"
            >
              Kullanım Koşulları
            </a>
            &apos;nı kabul ediyorum.
          </span>
        </label>
        <p className="text-xs leading-relaxed text-zinc-500">
          Kişisel verilerinizin işlenmesine ilişkin bilgilendirme için{" "}
          <a
            href={LEGAL_LINKS.kvkk}
            target="_blank"
            rel="noopener noreferrer"
            className="underline underline-offset-2 hover:text-zinc-700"
          >
            KVKK Aydınlatma Metni
          </a>{" "}
          ve{" "}
          <a
            href={LEGAL_LINKS.privacy}
            target="_blank"
            rel="noopener noreferrer"
            className="underline underline-offset-2 hover:text-zinc-700"
          >
            Gizlilik Politikası
          </a>
          &apos;nı inceleyebilirsiniz.
        </p>
      </div>

      <button
        type="submit"
        disabled={pending}
        className="inline-flex h-11 w-full items-center justify-center rounded-lg bg-zinc-900 px-6 text-sm font-medium text-white transition-colors hover:bg-zinc-800 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {pending ? "Oluşturuluyor..." : "Hesabımı Oluştur"}
      </button>
    </form>
  );
}
