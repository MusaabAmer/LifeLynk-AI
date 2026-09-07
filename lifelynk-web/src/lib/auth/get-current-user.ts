import { createClient } from "@/lib/supabase/server";

export type WebRole =
  | "HOSPITAL_ADMIN"
  | "BLOOD_BANK_ADMIN"
  | "STAFF"
  | "GOVERNMENT_ADMIN"
  | "SUPER_ADMIN";

export type OrganizationType =
  | "HOSPITAL"
  | "BLOOD_BANK";

export type OrganizationVerificationStatus =
  | "PENDING"
  | "VERIFIED"
  | "REJECTED";

export interface CurrentUser {
  id: string;
  email: string;
  fullName: string;
  role: WebRole;

  organizationId: string | null;
  organizationName: string | null;
  organizationType: OrganizationType | null;

  organizationVerificationStatus:
    | OrganizationVerificationStatus
    | null;

  organizationVerificationNotes: string | null;
}

const WEB_ROLES: readonly WebRole[] = [
  "HOSPITAL_ADMIN",
  "BLOOD_BANK_ADMIN",
  "STAFF",
  "GOVERNMENT_ADMIN",
  "SUPER_ADMIN",
];

export async function getCurrentUser(): Promise<CurrentUser | null> {
  const supabase = await createClient();

  // --------------------------------------------------
  // 1. Authenticate user
  // --------------------------------------------------

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    if (process.env.NODE_ENV === 'development') {
      console.error(
        "GET CURRENT USER - AUTH ERROR",
        authError,
      );
    }

    return null;
  }

  // --------------------------------------------------
  // 2. Load application profile + role
  // --------------------------------------------------

  const {
    data: profile,
    error: profileError,
  } = await supabase
    .from("users")
    .select(`
      id,
      email,
      full_name,
      role_id,
      is_active,
      is_verified,
      roles (
        id,
        name
      )
    `)
    .eq("id", user.id)
    .is("deleted_at", null)
    .maybeSingle();

  if (profileError || !profile) {
    if (process.env.NODE_ENV === 'development') {
      console.error(
        "GET CURRENT USER - PROFILE ERROR",
        profileError,
      );
    }

    return null;
  }

  // --------------------------------------------------
  // 3. Account validation
  // --------------------------------------------------

  if (!profile.is_active) {
    console.error(
      "GET CURRENT USER - ACCOUNT INACTIVE",
    );

    return null;
  }

  if (!profile.is_verified) {
    console.error(
      "GET CURRENT USER - ACCOUNT NOT VERIFIED",
    );

    return null;
  }

  // --------------------------------------------------
  // 4. Resolve role
  // --------------------------------------------------

  const roleData = Array.isArray(profile.roles)
    ? profile.roles[0]
    : profile.roles;

  const role =
    roleData?.name as WebRole | undefined;

  if (!role || !WEB_ROLES.includes(role)) {
    console.error(
      "GET CURRENT USER - INVALID WEB ROLE",
      {
        userId: user.id,
        roleId: profile.role_id,
        role,
      },
    );

    return null;
  }

  // --------------------------------------------------
  // 5. Default organization values
  // --------------------------------------------------

  let organizationId: string | null = null;

  let organizationName: string | null = null;

  let organizationType:
    | OrganizationType
    | null = null;

  let organizationVerificationStatus:
    | OrganizationVerificationStatus
    | null = null;

  let organizationVerificationNotes:
    | string
    | null = null;

  // --------------------------------------------------
  // 6. Privileged users
  // --------------------------------------------------

  const isPrivilegedRole =
    role === "SUPER_ADMIN" ||
    role === "GOVERNMENT_ADMIN";

  // --------------------------------------------------
  // 7. Resolve organization membership
  // --------------------------------------------------

  if (!isPrivilegedRole) {
    const {
      data: membership,
      error: membershipError,
    } = await supabase
      .from("organization_staff")
      .select(`
        organization_id,
        is_primary
      `)
      .eq("user_id", user.id)
      .is("deleted_at", null)
      .order("is_primary", {
        ascending: false,
      })
      .limit(1)
      .maybeSingle();

    if (membershipError) {
      if (process.env.NODE_ENV === 'development') {
        console.error(
          "GET CURRENT USER - MEMBERSHIP ERROR",
          membershipError,
        );
      }
    }

    // ------------------------------------------------
    // 8. Organization ID
    // ------------------------------------------------

    if (membership?.organization_id) {
      organizationId =
        membership.organization_id;

      // ----------------------------------------------
      // 9. Load organization separately
      // ----------------------------------------------

      const {
        data: organization,
        error: organizationError,
      } = await supabase
        .from("organizations")
        .select(`
          id,
          name,
          organization_type,
          verification_status,
          verification_notes
        `)
        .eq("id", organizationId)
        .is("deleted_at", null)
        .maybeSingle();

      if (organizationError) {
        if (process.env.NODE_ENV === 'development') {
          console.error(
            "GET CURRENT USER - ORGANIZATION ERROR",
            organizationError,
          );
        }
      }

      // ----------------------------------------------
      // 10. Resolve organization data
      // ----------------------------------------------

      if (organization) {
        organizationName =
          organization.name ?? null;

        if (
          organization.organization_type ===
            "HOSPITAL" ||
          organization.organization_type ===
            "BLOOD_BANK"
        ) {
          organizationType =
            organization.organization_type;
        }

        if (
          organization.verification_status ===
            "PENDING" ||
          organization.verification_status ===
            "VERIFIED" ||
          organization.verification_status ===
            "REJECTED"
        ) {
          organizationVerificationStatus =
            organization.verification_status;
        }

        organizationVerificationNotes =
          organization.verification_notes ?? null;
      }
    }
  }

  // --------------------------------------------------
  // 11. Final resolved user
  // --------------------------------------------------

  return {
    id: profile.id,

    email: profile.email,

    fullName:
      profile.full_name ?? "",

    role,

    organizationId,

    organizationName,

    organizationType,

    organizationVerificationStatus,

    organizationVerificationNotes,
  };
}