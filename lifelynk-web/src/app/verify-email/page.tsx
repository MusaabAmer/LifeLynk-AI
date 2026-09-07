"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import Image from "next/image";
import "./verify-email.css";


import { createClient } from "@/lib/supabase/client";

export default function VerifyEmailPage() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const email = searchParams.get("email") ?? "";

  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function handleResend() {
    setError("");
    setMessage("");

    if (!email) {
      setError(
        "Your email address could not be determined. Please return to registration.",
      );
      return;
    }

    setResending(true);

    try {
      const supabase = createClient();

      const emailRedirectTo =
  `${window.location.origin}/auth/confirm?next=/onboarding`;

      const { error: resendError } =
        await supabase.auth.resend({
          type: "signup",
          email,
          options: {
            emailRedirectTo,
          },
        });

      if (resendError) {
        setError(
          getResendErrorMessage(
            resendError.message,
          ),
        );
        return;
      }

      setMessage(
        "A new verification email has been sent. Please check your inbox and spam folder.",
      );
    } catch {
      setError(
        "Unable to resend the verification email. Please try again.",
      );
    } finally {
      setResending(false);
    }
  }

  async function handleCheckVerification() {
    setError("");
    setMessage("");
    setLoading(true);

    try {
      const supabase = createClient();

      const {
        data: { user },
        error: userError,
      } = await supabase.auth.getUser();

      if (userError || !user) {
        setError(
          "Your verification session could not be found. Please sign in after verifying your email.",
        );
        return;
      }

      /*
       * IMPORTANT:
       *
       * A Supabase session alone does NOT mean
       * the email has been verified.
       *
       * We explicitly check email_confirmed_at.
       */
      if (!user.email_confirmed_at) {
        setError(
          "Your email has not been verified yet. Please click the verification link in your email.",
        );
        return;
      }

      /*
       * Only after confirmation do we
       * enter organization onboarding.
       */
      router.replace("/onboarding");
      router.refresh();
    } catch {
      setError(
        "Unable to check your verification status. Please try again.",
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="lifelynk-verify">
      <div className="lifelynk-verify__container">
        <section className="lifelynk-verify__card">

          {/* =================================================
              LOGO
              ================================================= */}

          <Image
  src="/images/lifelynk-logo.png"
  alt="LifeLynk AI"
  width={300}
  height={200}
  priority
  className="auth-logo-image"
/>

          {/* =================================================
              HEADING
              ================================================= */}

          <div className="lifelynk-verify__heading">
            <h1>Verify your email</h1>

            <p>
              We&apos;ve sent a verification link to your
              email address. Please verify it before
              continuing.
            </p>
          </div>

          {/* =================================================
              EMAIL
              ================================================= */}

          <div className="lifelynk-verify__email">
            <p className="lifelynk-verify__email-label">
              Verification email sent to
            </p>

            <p className="lifelynk-verify__email-address">
              {email || "your email address"}
            </p>
          </div>

          {/* =================================================
              INSTRUCTION
              ================================================= */}

          <div className="lifelynk-verify__instruction">
            <div className="lifelynk-verify__instruction-content">
              <div
                className="lifelynk-verify__instruction-icon"
                aria-hidden="true"
              >
                ✓
              </div>

              <div>
                <p className="lifelynk-verify__instruction-title">
                  Check your inbox
                </p>

                <p className="lifelynk-verify__instruction-text">
                  Open the email from LifeLynk AI and click
                  the verification link. Don&apos;t forget to
                  check your spam folder.
                </p>
              </div>
            </div>
          </div>

          {/* =================================================
              SUCCESS MESSAGE
              ================================================= */}

          {message && (
            <div
              className="lifelynk-verify__message"
              role="status"
            >
              <p>{message}</p>
            </div>
          )}

          {/* =================================================
              ERROR MESSAGE
              ================================================= */}

          {error && (
            <div
              className="lifelynk-verify__error"
              role="alert"
            >
              <p>{error}</p>
            </div>
          )}

          {/* =================================================
              PRIMARY ACTION
              ================================================= */}

          <button
            type="button"
            onClick={handleCheckVerification}
            disabled={loading}
            className="lifelynk-verify__primary"
          >
            {loading ? (
              <>
                <span
                  className="lifelynk-verify__spinner"
                  aria-hidden="true"
                />

                Checking verification...
              </>
            ) : (
              "I've verified my email"
            )}
          </button>

          {/* =================================================
              RESEND
              ================================================= */}

          <button
            type="button"
            onClick={handleResend}
            disabled={resending || loading}
            className="lifelynk-verify__secondary"
          >
            {resending ? (
              <>
                <span
                  className="lifelynk-verify__spinner lifelynk-verify__spinner--dark"
                  aria-hidden="true"
                />

                Sending verification email...
              </>
            ) : (
              "Resend verification email"
            )}
          </button>

          {/* =================================================
              DIVIDER
              ================================================= */}

          <div className="lifelynk-verify__divider">
            <span>OR</span>
          </div>

          {/* =================================================
              REGISTER
              ================================================= */}

          <div className="lifelynk-verify__register">
            <p>
              Wrong email?{" "}
              <Link href="/register">
                Create a new account
              </Link>
            </p>
          </div>
        </section>

        {/* =================================================
            FOOTER
            ================================================= */}

        <p className="lifelynk-verify__footer">
          LifeLynk AI · Secure healthcare connectivity
        </p>
      </div>
    </main>
  );
}

/* =========================================================
   RESEND ERROR HANDLING
   ========================================================= */

function getResendErrorMessage(
  message: string,
): string {
  const normalized = message.toLowerCase();

  if (
    normalized.includes("rate limit") ||
    normalized.includes("too many")
  ) {
    return "Too many email requests. Please wait a few minutes before trying again.";
  }

  if (
    normalized.includes("not found") ||
    normalized.includes("user")
  ) {
    return "Unable to find an account with this email address.";
  }

  return "Unable to resend the verification email. Please try again.";
}