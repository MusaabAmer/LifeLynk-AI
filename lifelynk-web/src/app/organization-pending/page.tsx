import { redirect } from "next/navigation";
import "./organization-pending.css";

import { getCurrentUser } from "@/lib/auth/get-current-user";

export default async function OrganizationPendingPage() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect("/login");
  }

  if (
    currentUser.role !== "HOSPITAL_ADMIN" &&
    currentUser.role !== "BLOOD_BANK_ADMIN"
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
  redirect("/organization-verification/rejected");
}

  return (
    <main className="lifelynk-auth">
      <section className="lifelynk-auth__card">
        <div className="lifelynk-auth__heading">
          <p className="dashboard-page__eyebrow">
            ORGANIZATION VERIFICATION
          </p>

          <h1>
            Verification in progress
          </h1>

          <p>
            Your organization registration has been
            submitted successfully.
          </p>

          <p>
            <strong>
              {currentUser.organizationName}
            </strong>{" "}
            is currently waiting for verification by
            a LifeLynk government or Super Admin.
          </p>

          <p>
            You will be able to access the dashboard
            once your organization has been verified.
          </p>
        </div>
      </section>
    </main>
  );
}