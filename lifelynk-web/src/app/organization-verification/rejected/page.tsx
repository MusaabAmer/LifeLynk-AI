import { redirect } from "next/navigation";
import "./verification-rejected.css";

import Image from "next/image";

import { getCurrentUser } from "@/lib/auth/get-current-user";
import VerificationRejectedRealtime from "./verification-rejected-realtime";

export default async function VerificationRejectedPage() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect("/login");
  }

  if (!currentUser.organizationId) {
    redirect("/onboarding");
  }

  /*
   * ---------------------------------------------------------
   * SERVER-SIDE STATUS PROTECTION
   * ---------------------------------------------------------
   *
   * These checks handle the case where the status changed
   * before this page was rendered.
   */

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
    redirect(
      "/organization-verification/pending",
    );
  }

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
            className="auth-logo-image"
          />
        </div>

        <div className="lifelynk-auth__heading">
          <h1>
            Organization Verification Rejected
          </h1>

          <p>
            Your organization could not be
            verified at this time.
          </p>
        </div>

        <div
          className="lifelynk-auth__error"
          role="alert"
        >
          <strong>
            {currentUser.organizationName ??
              "Your organization"}
          </strong>

          {currentUser.organizationVerificationNotes && (
            <p>
              <strong>Reason:</strong>{" "}
              {currentUser.organizationVerificationNotes}
            </p>
          )}

          <p>
            Please contact the LifeLynk
            administration team for further
            assistance.
          </p>
        </div>

        <VerificationRejectedRealtime
          organizationId={currentUser.organizationId}
        />
      </section>
    </main>
  );
}