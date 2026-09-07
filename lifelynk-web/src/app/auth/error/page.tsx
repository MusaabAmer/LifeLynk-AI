"use client";

import "./auth-error.css";


import Image from "next/image";
import Link from "next/link";
import { useSearchParams } from "next/navigation";

const SAFE_ERROR_MESSAGES: Record<string, string> = {
  invalid_link:
    "The authentication link is invalid. Please request a new link and try again.",
  session_not_created:
    "Authentication completed, but your session could not be created. Please sign in and try again.",
  otp_expired:
    "The authentication link has expired. Please request a new one.",
  otp_already_used:
    "This authentication link has already been used. Please request a new one.",
  invalid_token:
    "The authentication link is invalid. Please request a new link and try again.",
  validation_failed:
    "The authentication link is invalid. Please request a new link and try again.",
  session_not_found:
    "Your session could not be established. Please try again.",
};

const DEFAULT_ERROR_MESSAGE =
  "An authentication error occurred. The link may be invalid or expired.";

export default function AuthErrorPage() {
  const searchParams = useSearchParams();

  const errorCode = searchParams.get("error");

  const message =
    (errorCode && SAFE_ERROR_MESSAGES[errorCode]) ||
    DEFAULT_ERROR_MESSAGE;

  return (
  <main className="lifelynk-auth">
    <section className="lifelynk-auth__card lifelynk-auth__card--verify">
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

      <div className="lifelynk-auth__verify-icon">
          <span>!</span>
        </div>

        <div className="lifelynk-auth__heading">
          <p className="lifelynk-auth__eyebrow">
            AUTHENTICATION ERROR
          </p>

          <h1>Link unavailable</h1>

          <p>{message}</p>
        </div>

        <div className="lifelynk-auth__verify-message">
          <p>
            The authentication link may have
            expired or already been used.
          </p>

          <p>
            Please request a new link and try
            again.
          </p>
        </div>

        <Link
          href="/login"
          className="lifelynk-auth__submit"
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            textDecoration: "none",
          }}
        >
          Back to sign in
        </Link>
      </section>
    </main>
  );
}