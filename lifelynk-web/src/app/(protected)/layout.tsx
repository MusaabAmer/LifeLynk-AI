import { ReactNode } from "react";
import { redirect } from "next/navigation";

import DashboardShell from "@/components/dashboard/dashboard-shell";
import { getCurrentUser } from "@/lib/auth/get-current-user";

interface ProtectedLayoutProps {
  children: ReactNode;
}

export default async function ProtectedLayout({
  children,
}: ProtectedLayoutProps) {
  const currentUser = await getCurrentUser();

  // --------------------------------------------------
  // 1. Authentication
  // --------------------------------------------------

  if (!currentUser) {
    redirect("/login");
  }

  // --------------------------------------------------
  // 2. Web dashboard roles
  // --------------------------------------------------

  const allowedWebRoles = [
    "HOSPITAL_ADMIN",
    "BLOOD_BANK_ADMIN",
    "STAFF",
    "GOVERNMENT_ADMIN",
    "SUPER_ADMIN",
  ] as const;

  if (
    !allowedWebRoles.includes(
      currentUser.role,
    )
  ) {
    redirect("/login");
  }

  // --------------------------------------------------
  // 3. Verification pages are allowed to load before
  //    normal organization/dashboard routing.
  // --------------------------------------------------

  /*
   * These pages handle their own organization
   * verification state.
   *
   * Do NOT force them through the normal onboarding
   * redirect logic below.
   */
  const verificationPath =
    "/organization-verification";

  /*
   * The protected layout does not receive pathname
   * directly, so verification pages should remain
   * responsible for their own state checks.
   *
   * Organization assignment is therefore handled
   * below only for normal dashboard pages.
   */

  // --------------------------------------------------
  // 4. Roles that require an organization
  // --------------------------------------------------

  const requiresOrganization =
    currentUser.role ===
      "HOSPITAL_ADMIN" ||
    currentUser.role ===
      "BLOOD_BANK_ADMIN" ||
    currentUser.role === "STAFF";

  // --------------------------------------------------
  // 5. Organization assignment
  // --------------------------------------------------

  /*
   * Organization verification pages must be able to
   * render while the account is in the verification
   * flow.
   *
   * If the account has no organization at all, normal
   * protected pages still go through onboarding.
   */

  if (
    requiresOrganization &&
    !currentUser.organizationId
  ) {
    redirect("/onboarding");
  }

  // --------------------------------------------------
  // 6. Organization verification
  // --------------------------------------------------

  /*
   * Hospital and blood-bank accounts cannot use the
   * dashboard until their organization is verified.
   */

  const requiresOrganizationVerification =
    currentUser.role ===
      "HOSPITAL_ADMIN" ||
    currentUser.role ===
      "BLOOD_BANK_ADMIN" ||
    currentUser.role === "STAFF";

  if (
    requiresOrganizationVerification &&
    currentUser.organizationId
  ) {
    // ----------------------------------------------
    // PENDING
    // ----------------------------------------------

    if (
      currentUser.organizationVerificationStatus ===
      "PENDING"
    ) {
      redirect(
        "/organization-verification/pending",
      );
    }

    // ----------------------------------------------
    // REJECTED
    // ----------------------------------------------

    if (
      currentUser.organizationVerificationStatus ===
      "REJECTED"
    ) {
      redirect(
        "/organization-verification/rejected",
      );
    }

    // ----------------------------------------------
    // Unknown/missing status
    // ----------------------------------------------

    if (
      currentUser.organizationVerificationStatus !==
      "VERIFIED"
    ) {
      redirect(
        "/organization-verification/pending",
      );
    }
  }

  // --------------------------------------------------
  // 7. Verified / privileged users
  // --------------------------------------------------

  return (
    <DashboardShell
      currentUser={currentUser}
    >
      {children}
    </DashboardShell>
  );
}