"use client";

import {
  FormEvent,
  useEffect,
  useState,
} from "react";

import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";


export default function ResetPasswordPage() {
  const router = useRouter();

  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] =
    useState("");

  const [showPassword, setShowPassword] =
    useState(false);
  const [showConfirmPassword, setShowConfirmPassword] =
    useState(false);

  const [loading, setLoading] = useState(false);
  const [checkingSession, setCheckingSession] =
    useState(true);
  const [hasRecoverySession, setHasRecoverySession] =
    useState(false);

  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    let mounted = true;

    async function checkSession() {
      const {
        data: { user },
      } = await supabase.auth.getUser();

      if (!mounted) return;

      if (user) {
        setHasRecoverySession(true);
        setError("");
      } else {
        setHasRecoverySession(false);
        setError(
          "This password reset link is invalid or has expired. Please request a new one.",
        );
      }

      setCheckingSession(false);
    }

    checkSession();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(
      (event, session) => {
        if (!mounted) return;

        if (
          event === "PASSWORD_RECOVERY" &&
          session
        ) {
          setHasRecoverySession(true);
          setError("");
          setCheckingSession(false);
          return;
        }

        if (session) {
          setHasRecoverySession(true);
          setError("");
          setCheckingSession(false);
        }
      },
    );

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, []);

  async function handleResetPassword(
    event: FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault();

    setError("");

    if (!hasRecoverySession) {
      setError(
        "This password reset session is invalid or has expired. Please request a new reset link.",
      );
      return;
    }

    if (password.length < 8) {
      setError(
        "Password must contain at least 8 characters.",
      );
      return;
    }

    if (!/[A-Z]/.test(password)) {
      setError(
        "Password must contain at least one uppercase letter.",
      );
      return;
    }

    if (!/\d/.test(password)) {
      setError(
        "Password must contain at least one number.",
      );
      return;
    }

    if (password !== confirmPassword) {
      setError("Passwords do not match.");
      return;
    }

    setLoading(true);

    const supabase = createClient();

    const { error: updateError } =
      await supabase.auth.updateUser({
        password,
      });

    if (updateError) {
      setError(
        "Unable to update your password. Please request a new reset link and try again.",
      );
      setLoading(false);
      return;
    }

    /*
     * Password has been successfully changed.
     */
    setSuccess(true);
    setLoading(false);

    /*
     * Sign out the recovery session so the user must
     * authenticate again with the new password.
     */
    await supabase.auth.signOut();

    window.setTimeout(() => {
      router.replace(
        "/login?passwordReset=success",
      );
    }, 1800);
  }

  if (checkingSession) {
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
            <p className="lifelynk-auth__eyebrow">
              ACCOUNT RECOVERY
            </p>

            <h1>Verifying reset link</h1>

            <p>
              Please wait while we verify your password
              reset session.
            </p>
          </div>

          <div
            className="lifelynk-loading__spinner"
            aria-label="Verifying password reset session"
          />
        </section>
      </main>
    );
  }

  return (
    <main className="lifelynk-auth">
      <section className="lifelynk-auth__card">
        <div className="lifelynk-auth__logo">
          <Image
            src="/images/lifelynk-logo.png"
            alt="LifeLynk AI"
            width={220}
            height={60}
          />
        </div>

        {success ? (
          <div className="lifelynk-auth__heading">
            <div className="lifelynk-auth__verify-icon">
              <svg
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path
                  d="M5 12.5 9.5 17 19 7.5"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </div>

            <p className="lifelynk-auth__eyebrow">
              PASSWORD UPDATED
            </p>

            <h1>Password changed</h1>

            <p>
              Your password has been updated
              successfully. Redirecting you to
              sign in...
            </p>
          </div>
        ) : hasRecoverySession ? (
          <>
            <div className="lifelynk-auth__heading">
              <p className="lifelynk-auth__eyebrow">
                ACCOUNT RECOVERY
              </p>

              <h1>Set a new password</h1>

              <p>
                Create a new secure password for your
                LifeLynk AI account.
              </p>
            </div>

            <form
              className="lifelynk-auth__form"
              onSubmit={handleResetPassword}
            >
              <div className="lifelynk-auth__field">
                <label htmlFor="password">
                  New password
                </label>

                <div className="lifelynk-auth__input-wrap">
                  <svg
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <rect
                      x="4"
                      y="10"
                      width="16"
                      height="11"
                      rx="2"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="1.8"
                    />

                    <path
                      d="M8 10V7a4 4 0 0 1 8 0v3"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="1.8"
                    />
                  </svg>

                  <input
                    id="password"
                    type={
                      showPassword
                        ? "text"
                        : "password"
                    }
                    value={password}
                    onChange={(event) =>
                      setPassword(event.target.value)
                    }
                    placeholder="Create a new password"
                    autoComplete="new-password"
                    required
                  />

                  <button
                    type="button"
                    className="lifelynk-auth__password-toggle"
                    onClick={() =>
                      setShowPassword(
                        (value) => !value,
                      )
                    }
                    aria-label={
                      showPassword
                        ? "Hide password"
                        : "Show password"
                    }
                  >
                    {showPassword ? "◉" : "◉"}
                  </button>
                </div>
              </div>

              <div className="lifelynk-auth__field">
                <label htmlFor="confirmPassword">
                  Confirm password
                </label>

                <div className="lifelynk-auth__input-wrap">
                  <svg
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <rect
                      x="4"
                      y="10"
                      width="16"
                      height="11"
                      rx="2"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="1.8"
                    />

                    <path
                      d="M8 10V7a4 4 0 0 1 8 0v3"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="1.8"
                    />
                  </svg>

                  <input
                    id="confirmPassword"
                    type={
                      showConfirmPassword
                        ? "text"
                        : "password"
                    }
                    value={confirmPassword}
                    onChange={(event) =>
                      setConfirmPassword(
                        event.target.value,
                      )
                    }
                    placeholder="Confirm your new password"
                    autoComplete="new-password"
                    required
                  />

                  <button
                    type="button"
                    className="lifelynk-auth__password-toggle"
                    onClick={() =>
                      setShowConfirmPassword(
                        (value) => !value,
                      )
                    }
                    aria-label={
                      showConfirmPassword
                        ? "Hide password"
                        : "Show password"
                    }
                  >
                    {showConfirmPassword
                      ? "◉"
                      : "◉"}
                  </button>
                </div>
              </div>

              <div className="lifelynk-auth__requirements">
                <span
                  className={
                    password.length >= 8
                      ? "is-valid"
                      : ""
                  }
                >
                  • At least 8 characters
                </span>

                <span
                  className={
                    /[A-Z]/.test(password)
                      ? "is-valid"
                      : ""
                  }
                >
                  • One uppercase letter
                </span>

                <span
                  className={
                    /\d/.test(password)
                      ? "is-valid"
                      : ""
                  }
                >
                  • One number
                </span>
              </div>

              {error && (
                <div
                  className="lifelynk-auth__error"
                  role="alert"
                >
                  {error}
                </div>
              )}

              <button
                type="submit"
                className="lifelynk-auth__submit"
                disabled={loading}
              >
                {loading
                  ? "Updating password..."
                  : "Update password"}
              </button>
            </form>

            <p className="lifelynk-auth__register">
              Remember your password?{" "}
              <Link href="/login">
                Sign in
              </Link>
            </p>
          </>
        ) : (
          <div className="lifelynk-auth__heading">
            <div className="lifelynk-auth__verify-icon">
              <svg
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path
                  d="M12 8v5"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                />

                <circle
                  cx="12"
                  cy="17"
                  r="1"
                  fill="currentColor"
                />

                <path
                  d="M10.3 4.5 2.8 18a2 2 0 0 0 1.7 3h15a2 2 0 0 0 1.7-3L13.7 4.5a2 2 0 0 0-3.4 0Z"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.8"
                  strokeLinejoin="round"
                />
              </svg>
            </div>

            <p className="lifelynk-auth__eyebrow">
              ACCOUNT RECOVERY
            </p>

            <h1>Reset link expired</h1>

            <p>
              This password reset link is invalid or
              has expired. Please request a new reset
              link to continue.
            </p>

            <Link
              href="/forgot-password"
              className="lifelynk-auth__back"
            >
              Request a new reset link
            </Link>

            <br />

            <Link
              href="/login"
              className="lifelynk-auth__back"
            >
              ← Back to sign in
            </Link>
          </div>
        )}
      </section>
    </main>
  );
}