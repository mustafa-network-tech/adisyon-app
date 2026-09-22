import { CompleteSignup } from "./complete-signup";

// Reached via /auth/callback?next=/kayit/tamamla after the user clicks
// their confirmation email -- see signup-form.tsx's emailRedirectTo.
// The actual business-creation call (create_own_business) happens
// client-side in CompleteSignup once a session exists.
export default function KayitTamamlaPage() {
  return (
    <div className="flex flex-1 items-center justify-center px-6 py-16">
      <div className="w-full max-w-md">
        <CompleteSignup />
      </div>
    </div>
  );
}
