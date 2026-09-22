"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getSessionContext } from "@/lib/auth/session";
import type { SupportRequestStatus, CustomSoftwareRequestStatus } from "@/lib/supabase/database.types";

export async function updateSupportRequestStatus(
  requestId: string,
  status: SupportRequestStatus
): Promise<void> {
  const ctx = await getSessionContext();
  if (!ctx?.isPlatformAdmin) return;

  const supabase = await createClient();
  await supabase.from("support_requests").update({ status }).eq("id", requestId);

  revalidatePath("/super-admin/destek");
}

export async function updateCustomSoftwareRequestStatus(
  requestId: string,
  status: CustomSoftwareRequestStatus
): Promise<void> {
  const ctx = await getSessionContext();
  if (!ctx?.isPlatformAdmin) return;

  const supabase = await createClient();
  await supabase.from("custom_software_requests").update({ status }).eq("id", requestId);

  revalidatePath("/super-admin/destek");
}
