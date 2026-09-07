import { redirect } from "next/navigation";
import "./verification-pending.css";

import Image from "next/image";

import { getCurrentUser } from "@/lib/auth/get-current-user";
import VerificationPendingRealtime from "./verification-pending-realtime";

export default async function VerificationPendingPage() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect("/login");
  }

  const isOrganizationRole =
    currentUser.role === "HOSPITAL_ADMIN" ||
    currentUser.role === "BLOOD_BANK_ADMIN" ||
    currentUser.role === "STAFF";

  if (!isOrganizationRole) {
    redirect("/dashboard");
  }

  /*
   * A registered organization must have an organization
   * membership. If it does not, this is a genuine onboarding
   * case.
   */
  if (!currentUser.organizationId) {
    redirect("/onboarding");
  }

  /*
   * Server-side protection:
   * If verification has already happened before this page
   * renders, redirect immediately.
   */
  if (
    currentUser.organizationVerificationStatus ===
    "VERIFIED"
  ) {
    redirect("/dashboard");
  }

  if (
    currentUser.organizationVerificationStatus ===
    "REJECTED"
  ) {
    redirect("/organization-verification/rejected");
  }

  /*
   * Do NOT redirect an existing organization to onboarding
   * because of a temporary/unknown status.
   *
   * The account already has an organization, so keep it in
   * the verification flow and expose the state instead.
   */
  const isPending =
    currentUser.organizationVerificationStatus ===
    "PENDING";

  return (
    <main className="lifelynk-auth">
      <section className="lifelynk-auth__card">
        <div className="lifelynk-auth__logo">
          <Image
            src="/images/lifelynk-logo.png"
            alt="LifeLynk AI"
            width={300}
            height={200}
            priority
          />
        </div>

        <div className="lifelynk-auth__heading">
          <h1>
            {isPending
              ? "Verification Pending"
              : "Verification In Progress"}
          </h1>

          <p>
            Your organization registration has been
            submitted successfully.
          </p>
        </div>

        <div
          className="lifelynk-auth__success"
          role="status"
        >
          <strong>
            {currentUser.organizationName ??
              "Your organization"}
          </strong>

          <p>
            Your organization is currently awaiting
            verification by a Government Administrator
            or Super Administrator.
          </p>

          <p>
            You will be able to access the LifeLynk
            healthcare dashboard once your organization
            has been verified.
          </p>
        </div>

        <VerificationPendingRealtime
          organizationId={currentUser.organizationId}
        />
      </section>
    </main>
  );
}