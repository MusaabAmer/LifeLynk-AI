"use server";

import { createClient } from "@/lib/supabase/server";
import { getCurrentUser } from "@/lib/auth/get-current-user";

export type GovernmentDecision = "VERIFY" | "REJECT";

export async function decideGovernmentOrganization(
  organizationId: string,
  decision: GovernmentDecision,
  notes: string,
): Promise<{ success: boolean; error?: string }> {
  const currentUser = await getCurrentUser();
  if (!currentUser) return { success: false, error: "You are not authenticated." };
  if (!["GOVERNMENT_ADMIN", "SUPER_ADMIN"].includes(currentUser.role)) {
    return { success: false, error: "You do not have permission to review organizations." };
  }
  if (!organizationId?.trim()) return { success: false, error: "Invalid organization." };
  if (decision !== "VERIFY" && decision !== "REJECT") return { success: false, error: "Invalid organization decision." };
  const trimmedNotes = notes.trim();
  if (decision === "REJECT" && trimmedNotes.length < 5) {
    return { success: false, error: "A rejection reason is required." };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("verify_organization", {
    p_organization_id: organizationId,
    p_status: decision === "VERIFY" ? "VERIFIED" : "REJECTED",
    p_notes: trimmedNotes || null,
  });

  if (error) {
    console.error("GOVERNMENT ORGANIZATION DECISION ERROR", error);
    return { success: false, error: error.message || "Unable to update organization verification." };
  }
  return { success: true };
}
