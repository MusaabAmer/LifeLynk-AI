"use client";

import { FormEvent, useState } from "react";
import Link from "next/link";
import Image from "next/image";


import { createClient } from "@/lib/supabase/client";

import "./forgot-password.css";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function handleSubmit(
    event: FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault();

    setLoading(true);
    setError("");
    setMessage("");

    const normalizedEmail = email.trim();

    if (!normalizedEmail) {
      setError("Please enter your email address.");
      setLoading(false);
      return;
    }

    const supabase = createClient();

    const { error: resetError } =
      await supabase.auth.resetPasswordForEmail(
        normalizedEmail,
        {
          redirectTo:
            `${window.location.origin}/auth/confirm`,
        },
      );

    if (resetError) {
      setError(
        "Unable to send the password reset email. Please try again.",
      );
      setLoading(false);
      return;
    }

    setMessage(
      "If an account exists for this email, a password reset link has been sent. Please check your inbox.",
    );

    setLoading(false);
  }

  return (
    <main className="forgot-password-page">
      <section className="forgot-password-card">

        <Image
  src="/images/lifelynk-logo.png"
  alt="LifeLynk AI"
  width={300}
  height={200}
  priority
  className="auth-logo-image"
/>

        {/* Heading */}
        <div className="forgot-password-heading">
          <p className="forgot-password-eyebrow">
            ACCOUNT RECOVERY
          </p>

          <h1>Forgot your password?</h1>

          <p>
            Enter your email address and we&apos;ll send you
            a secure link to reset your password.
          </p>
        </div>

        {/* Form */}
        <form
          className="forgot-password-form"
          onSubmit={handleSubmit}
        >
          <div className="forgot-password-field">
            <label htmlFor="forgot-password-email">
              Email address
            </label>

            <div className="forgot-password-input-wrap">
              <svg
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <rect
                  x="2.5"
                  y="4"
                  width="19"
                  height="16"
                  rx="2"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.8"
                />

                <path
                  d="m3.5 6 8.5 6.5L20.5 6"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.8"
                />
              </svg>

              <input
                id="forgot-password-email"
                type="email"
                value={email}
                onChange={(event) =>
                  setEmail(event.target.value)
                }
                placeholder="you@example.com"
                autoComplete="email"
                required
              />
            </div>
          </div>

          {/* Error */}
          {error && (
            <div
              className="forgot-password-alert forgot-password-alert--error"
              role="alert"
            >
              <span className="forgot-password-alert__icon">
                !
              </span>

              <span>{error}</span>
            </div>
          )}

          {/* Success */}
          {message && (
            <div
              className="forgot-password-alert forgot-password-alert--success"
              role="status"
            >
              <span className="forgot-password-alert__icon">
                ✓
              </span>

              <span>{message}</span>
            </div>
          )}

          {/* Submit */}
          <button
            type="submit"
            className="forgot-password-submit"
            disabled={loading}
          >
            {loading ? (
              <>
                <span className="forgot-password-spinner" />
                Sending reset link...
              </>
            ) : (
              "Send reset link"
            )}
          </button>
        </form>

        {/* Back */}
        <p className="forgot-password-back">
          Remember your password?{" "}
          <Link href="/login">
            Sign in
          </Link>
        </p>

      </section>
    </main>
  );
}