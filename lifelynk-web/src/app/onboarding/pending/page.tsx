import { redirect } from "next/navigation";

import "../onboarding.css";

import { getCurrentUser } from "@/lib/auth/get-current-user";

export default async function PendingVerificationPage() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect("/login");
  }

  if (
    currentUser.role === "SUPER_ADMIN" ||
    currentUser.role === "GOVERNMENT_ADMIN"
  ) {
    redirect("/dashboard");
  }

  if (!currentUser.organizationId) {
    redirect("/onboarding");
  }

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
    redirect("/onboarding/rejected");
  }

  return (
    <div className="dashboard-page onboarding-page">
      <section className="onboarding-welcome">
        <div className="onboarding-welcome__content">
          <div className="onboarding-welcome__icon">
            !
          </div>

          <div>
            <p className="dashboard-page__eyebrow">
              ORGANIZATION VERIFICATION
            </p>

            <h2>
              Verification pending
            </h2>

            <p>
              Your organization registration has
              been submitted successfully and is
              currently waiting for verification.
            </p>
          </div>
        </div>

        <div className="onboarding-welcome__status">
          <span />
          Pending review
        </div>
      </section>

      <section className="onboarding-info-grid">
        <div className="onboarding-info-card">
          <div className="onboarding-info-card__icon">
            ✓
          </div>

          <div>
            <strong>
              Registration submitted
            </strong>

            <span>
              Your organization information has
              been submitted to LifeLynk AI.
            </span>
          </div>
        </div>

        <div className="onboarding-info-card">
          <div className="onboarding-info-card__icon">
            !
          </div>

          <div>
            <strong>
              Under administrator review
            </strong>

            <span>
              A LifeLynk administrator will review
              your organization details.
            </span>
          </div>
        </div>

        <div className="onboarding-info-card">
          <div className="onboarding-info-card__icon">
            →
          </div>

          <div>
            <strong>
              Dashboard access
            </strong>

            <span>
              Full organization dashboard access
              will become available after approval.
            </span>
          </div>
        </div>
      </section>

      <section className="onboarding-selection">
        <div className="onboarding-selection__header">
          <div>
            <p className="onboarding-selection__eyebrow">
              ORGANIZATION
            </p>

            <h3>
              {currentUser.organizationName ??
                "Your organization"}
            </h3>

            <p>
              Your organization is currently
              awaiting verification.
            </p>
          </div>

          <div className="onboarding-selection__count">
            <strong>
              PENDING
            </strong>

            <span>
              Verification status
            </span>
          </div>
        </div>

        {currentUser.organizationVerificationNotes && (
          <div className="onboarding-form__error">
            <span>!</span>

            <p>
              {currentUser.organizationVerificationNotes}
            </p>
          </div>
        )}
      </section>
    </div>
  );
}