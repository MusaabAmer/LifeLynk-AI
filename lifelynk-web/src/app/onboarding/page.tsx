import { redirect } from "next/navigation";

import "./onboarding.css";

import { getCurrentUser } from "@/lib/auth/get-current-user";
import { createClient } from "@/lib/supabase/server";
import OrganizationOnboardingForm from "./organization-onboarding-form";

export default async function OnboardingPage() {
  const currentUser = await getCurrentUser();

  /*
   * Authentication protection.
   */
  if (!currentUser) {
    redirect("/login");
  }

  /*
   * These roles do not require organization onboarding.
   */
  if (
    currentUser.role === "SUPER_ADMIN" ||
    currentUser.role === "GOVERNMENT_ADMIN"
  ) {
    redirect("/dashboard");
  }

  /*
   * Already assigned to an organization.
   */
  if (currentUser.organizationId) {
  if (
    currentUser.organizationVerificationStatus ===
    "VERIFIED"
  ) {
    redirect("/dashboard");
  }

  if (
    currentUser.organizationVerificationStatus ===
    "PENDING"
  ) {
    redirect("/organization-verification/pending");
  }

  if (
    currentUser.organizationVerificationStatus ===
    "REJECTED"
  ) {
    redirect("/organization-verification/rejected");
  }
}

  /*
   * STAFF cannot self-select an organization.
   */
  if (currentUser.role === "STAFF") {
    return (
      <div className="dashboard-page onboarding-page">
        <section className="onboarding-welcome">
          <div className="onboarding-welcome__content">
            <div className="onboarding-welcome__icon">
              !
            </div>

            <div>
              <p className="dashboard-page__eyebrow">
                ORGANIZATION SETUP
              </p>

              <h2>
                Organization assignment required
              </h2>

              <p>
                Your account has not yet been assigned
                to a healthcare organization. Please
                contact your organization administrator.
              </p>
            </div>
          </div>
        </section>
      </div>
    );
  }

  /*
   * Only these roles can select an organization
   * during onboarding.
   */
  const organizationType =
    currentUser.role === "HOSPITAL_ADMIN"
      ? "HOSPITAL"
      : currentUser.role === "BLOOD_BANK_ADMIN"
        ? "BLOOD_BANK"
        : null;

  /*
   * Defensive fallback.
   *
   * Any unexpected role should not be allowed to
   * enter organization selection.
   */
  if (!organizationType) {
    redirect("/dashboard");
  }

  const supabase = await createClient();

  /*
   * Load verified organizations matching the
   * authenticated user's organization type.
   *
   * organizations.city_id
   *        ↓
   *     cities.id
   */
  const {
    data: organizations,
    error,
  } = await supabase
    .from("organizations")
    .select(`
      id,
      name,
      organization_type,
      registration_number,
      phone,
      email,
      address,
      city_id,
      verification_status,
      cities (
        id,
        name
      )
    `)
    .eq(
      "organization_type",
      organizationType,
    )
    .eq(
      "verification_status",
      "VERIFIED",
    )
    .is("deleted_at", null)
    .order("name", {
      ascending: true,
    });

  if (error) {
    console.error(
      "Organization onboarding query error:",
      error,
    );

    throw new Error(
      "Unable to load organizations.",
    );
  }

  return (
    <div className="dashboard-page onboarding-page">
      <section className="onboarding-welcome">
        <div className="onboarding-welcome__content">
          <div className="onboarding-welcome__icon">
            {organizationType === "HOSPITAL"
              ? "H"
              : "B"}
          </div>

          <div>
            <p className="dashboard-page__eyebrow">
              ORGANIZATION SETUP
            </p>

            <h2>
              Connect your organization
            </h2>

            <p>
              Select the verified{" "}
              {organizationType === "HOSPITAL"
                ? "hospital"
                : "blood bank"}{" "}
              where you work. This organization
              will be connected to your LifeLynk
              account.
            </p>
          </div>
        </div>

        <div className="onboarding-welcome__status">
          <span />
          Verified organizations
        </div>
      </section>

      <section className="onboarding-info-grid">
        <div className="onboarding-info-card">
          <div className="onboarding-info-card__icon">
            ✓
          </div>

          <div>
            <strong>
              Verified organizations
            </strong>

            <span>
              Only verified healthcare organizations
              are available.
            </span>
          </div>
        </div>

        <div className="onboarding-info-card">
          <div className="onboarding-info-card__icon">
            {organizationType === "HOSPITAL"
              ? "H"
              : "B"}
          </div>

          <div>
            <strong>
              {organizationType === "HOSPITAL"
                ? "Hospital account"
                : "Blood bank account"}
            </strong>

            <span>
              Your account type determines which
              organizations you can select.
            </span>
          </div>
        </div>

        <div className="onboarding-info-card">
          <div className="onboarding-info-card__icon">
            →
          </div>

          <div>
            <strong>
              One organization
            </strong>

            <span>
              Your primary organization will be
              linked to your account.
            </span>
          </div>
        </div>
      </section>

      <OrganizationOnboardingForm
        organizations={organizations ?? []}
        organizationType={organizationType}
      />
    </div>
  );
}