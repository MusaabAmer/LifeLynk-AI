"use server";

import { createClient } from "@/lib/supabase/server";
import { getCurrentUser } from "@/lib/auth/get-current-user";

export type EmergencySosStatus =
  | "pending"
  | "matched"
  | "in_progress"
  | "completed"
  | "cancelled";

const ALL_STATUSES: EmergencySosStatus[] = [
  "pending",
  "matched",
  "in_progress",
  "completed",
  "cancelled",
];

const ALLOWED_TRANSITIONS: Record<
  EmergencySosStatus,
  EmergencySosStatus[]
> = {
  pending: [
    "matched",
    "cancelled",
  ],

  matched: [
    "in_progress",
    "cancelled",
  ],

  in_progress: [
    "completed",
    "cancelled",
  ],

  completed: [],

  cancelled: [],
};

const RESPONSE_ROLES = [
  "SUPER_ADMIN",
  "GOVERNMENT_ADMIN",
  "HOSPITAL_ADMIN",
  "BLOOD_BANK_ADMIN",
  "STAFF",
] as const;

function isValidStatus(
  status: string,
): status is EmergencySosStatus {
  return ALL_STATUSES.includes(
    status as EmergencySosStatus,
  );
}

export async function updateEmergencySosStatus(
  sosId: string,
  nextStatus: EmergencySosStatus,
): Promise<{
  success: boolean;
  error?: string;
}> {
  /*
   * ------------------------------------------------
   * AUTHENTICATION
   * ------------------------------------------------
   */

  const currentUser =
    await getCurrentUser();

  if (!currentUser) {
    return {
      success: false,
      error: "You are not authenticated.",
    };
  }

  /*
   * ------------------------------------------------
   * AUTHORIZATION
   * ------------------------------------------------
   */

  if (
    !RESPONSE_ROLES.includes(
      currentUser.role as (typeof RESPONSE_ROLES)[number],
    )
  ) {
    return {
      success: false,
      error:
        "You do not have permission to respond to SOS requests.",
    };
  }

  /*
   * ------------------------------------------------
   * INPUT VALIDATION
   * ------------------------------------------------
   */

  const cleanSosId =
    typeof sosId === "string"
      ? sosId.trim()
      : "";

  if (!cleanSosId) {
    return {
      success: false,
      error: "Invalid SOS request.",
    };
  }

  const cleanNextStatus =
    typeof nextStatus === "string"
      ? nextStatus.trim().toLowerCase()
      : "";

  if (!isValidStatus(cleanNextStatus)) {
    return {
      success: false,
      error: "Invalid SOS status.",
    };
  }

  /*
   * ------------------------------------------------
   * DATABASE
   * ------------------------------------------------
   */

  const supabase =
    await createClient();

  /*
   * ------------------------------------------------
   * LOAD CURRENT SOS
   *
   * Uses the real emergency_sos table.
   *
   * There is intentionally NO organization_id
   * because that column does not exist in the
   * actual database schema.
   * ------------------------------------------------
   */

  const {
    data: sos,
    error: fetchError,
  } = await supabase
    .from("emergency_sos")
    .select(`
      id,
      status
    `)
    .eq("id", cleanSosId)
    .maybeSingle();

  if (fetchError) {
    console.error(
      "UPDATE SOS - FETCH ERROR:",
      fetchError,
    );

    return {
      success: false,
      error:
        "Unable to load the SOS request.",
    };
  }

  if (!sos) {
    return {
      success: false,
      error:
        "SOS request not found.",
    };
  }

  /*
   * ------------------------------------------------
   * NORMALIZE CURRENT STATUS
   * ------------------------------------------------
   */

  const rawCurrentStatus =
    String(sos.status ?? "")
      .trim()
      .toLowerCase();

  if (!isValidStatus(rawCurrentStatus)) {
    return {
      success: false,
      error:
        `Unsupported current SOS status: ${sos.status}`,
    };
  }

  /*
   * ------------------------------------------------
   * PREVENT SAME-STATUS UPDATE
   * ------------------------------------------------
   */

  if (
    rawCurrentStatus ===
    cleanNextStatus
  ) {
    return {
      success: false,
      error:
        `SOS is already ${cleanNextStatus}.`,
    };
  }

  /*
   * ------------------------------------------------
   * VALIDATE STATUS TRANSITION
   *
   * pending
   *    -> matched
   *    -> cancelled
   *
   * matched
   *    -> in_progress
   *    -> cancelled
   *
   * in_progress
   *    -> completed
   *    -> cancelled
   *
   * completed / cancelled
   *    -> terminal
   * ------------------------------------------------
   */

  const allowedNextStatuses =
    ALLOWED_TRANSITIONS[
      rawCurrentStatus
    ];

  if (
    !allowedNextStatuses.includes(
      cleanNextStatus,
    )
  ) {
    return {
      success: false,
      error:
        `Cannot change SOS from ${rawCurrentStatus} to ${cleanNextStatus}.`,
    };
  }

  /*
   * ------------------------------------------------
   * UPDATE REAL DATABASE RECORD
   * ------------------------------------------------
   */

  const {
    data: updatedSos,
    error: updateError,
  } = await supabase
    .from("emergency_sos")
    .update({
      status: cleanNextStatus,
    })
    .eq("id", cleanSosId)
    .select(`
      id,
      status
    `)
    .maybeSingle();

  if (updateError) {
    console.error(
      "UPDATE SOS - UPDATE ERROR:",
      updateError,
    );

    return {
      success: false,
      error:
        updateError.message ||
        "Unable to update SOS status.",
    };
  }

  /*
   * ------------------------------------------------
   * RLS / NO-ROW-UPDATED CHECK
   *
   * If RLS prevents the update, Supabase may
   * return no updated row rather than a useful
   * application-level error.
   * ------------------------------------------------
   */

  if (!updatedSos) {
    return {
      success: false,
      error:
        "SOS status could not be updated. Your account may not have database permission to respond to this request.",
    };
  }

  /*
   * ------------------------------------------------
   * SUCCESS
   * ------------------------------------------------
   */

  return {
    success: true,
  };
}

