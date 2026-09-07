"use client";

import {
  FormEvent,
  useState,
} from "react";
import Link from "next/link";
import {
  useRouter,
  useSearchParams,
} from "next/navigation";
import Image from "next/image";

import { createClient } from "@/lib/supabase/client";

import "./login.css";

export default function LoginPage() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(() => {
    const callbackError = searchParams.get("error");

    switch (callbackError) {
      case "missing_code":
        return "The authentication link is incomplete. Please request a new link and try again.";

      case "auth_callback_failed":
        return "The authentication link is invalid or has expired. Please request a new link and try again.";

      default:
        return "";
    }
  });

  const [message, setMessage] = useState(() => {
    const passwordReset =
      searchParams.get("passwordReset");

    if (passwordReset === "success") {
      return "Your password has been changed successfully. Please sign in with your new password.";
    }

    return "";
  });

  const requestedRedirect =
    searchParams.get("redirectTo");

  const redirectTo =
    requestedRedirect &&
    requestedRedirect.startsWith("/") &&
    !requestedRedirect.startsWith("//")
      ? requestedRedirect
      : "/dashboard";

  async function handleLogin(
    event: FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault();

    setLoading(true);
    setError("");
    setMessage("");

    const normalizedEmail = email.trim();

    if (!normalizedEmail) {
      setError(
        "Please enter your email address.",
      );
      setLoading(false);
      return;
    }

    if (!password) {
      setError(
        "Please enter your password.",
      );
      setLoading(false);
      return;
    }

    const supabase = createClient();

    const {
      data,
      error: signInError,
    } =
      await supabase.auth.signInWithPassword({
        email: normalizedEmail,
        password,
      });

    if (signInError) {
      if (
        signInError.message
          .toLowerCase()
          .includes("email not confirmed")
      ) {
        setError(
          "Please verify your email address before signing in.",
        );

        setLoading(false);
        return;
      }

      setError(
        "Unable to sign in. Please check your email and password.",
      );

      setLoading(false);
      return;
    }

    if (!data.session) {
      setError(
        "Sign-in completed, but no active session was created. Please try again.",
      );

      setLoading(false);
      return;
    }

    router.replace(redirectTo);
  }

  return (
    <main className="login-page">
      <section className="login-card">

        {/* ==================================================
            LOGO
        ================================================== */}

        <Image
  src="/images/lifelynk-logo.png"
  alt="LifeLynk AI"
  width={300}
  height={200}
  priority
  className="auth-logo-image"
/>

        {/* ==================================================
            HEADER
        ================================================== */}

        <div className="login-heading">
          <h1>
            Welcome back
          </h1>

          <p>
            Sign in to manage the LifeLynk
            healthcare network.
          </p>
        </div>

        {/* ==================================================
            SUCCESS MESSAGE
        ================================================== */}

        {message && (
          <div
            className="login-alert login-alert--success"
            role="status"
          >
            <span className="login-alert__icon">
              ✓
            </span>

            <span>{message}</span>
          </div>
        )}

        {/* ==================================================
            FORM
        ================================================== */}

        <form
          className="login-form"
          onSubmit={handleLogin}
        >

          {/* Email */}

          <div className="login-field">
            <label htmlFor="login-email">
              Email address
            </label>

            <div className="login-input-wrap">
              <svg
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path
                  d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2Z"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.8"
                />

                <path
                  d="m3 6 9 7 9-7"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.8"
                />
              </svg>

              <input
                id="login-email"
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

          {/* Password */}

          <div className="login-field">

            <div className="login-label-row">
              <label htmlFor="login-password">
                Password
              </label>

              <Link href="/forgot-password">
                Forgot password?
              </Link>
            </div>

            <div className="login-input-wrap">
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
                id="login-password"
                type={
                  showPassword
                    ? "text"
                    : "password"
                }
                value={password}
                onChange={(event) =>
                  setPassword(
                    event.target.value,
                  )
                }
                placeholder="Enter your password"
                autoComplete="current-password"
                required
              />

              <button
                type="button"
                className="login-password-toggle"
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
                {showPassword ? (
                  <svg
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <path
                      d="M3 3l18 18"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="1.8"
                      strokeLinecap="round"
                    />

                    <path
                      d="M10.6 10.6a2 2 0 0 0 2.8 2.8"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="1.8"
                    />

                    <path
                      d="M9.9 5.1A10.8 10.8 0 0 1 12 5c5 0 8.5 4.2 9.5 6-.4.7-1.2 1.8-2.4 2.9"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="1.8"
                      strokeLinecap="round"
                    />

                    <path
                      d="M6.5 7.1C4.4 8.5 3.1 10.3 2.5 11c1 1.8 4.5 6 9.5 6 1.1 0 2.1-.2 3-.5"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="1.8"
                      strokeLinecap="round"
                    />
                  </svg>
                ) : (
                  <svg
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <path
                      d="M2.5 12S6 6 12 6s9.5 6 9.5 6-3.5 6-9.5 6-9.5-6-9.5-6Z"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="1.8"
                    />

                    <circle
                      cx="12"
                      cy="12"
                      r="2.5"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="1.8"
                    />
                  </svg>
                )}
              </button>
            </div>
          </div>

          {/* Error */}

          {error && (
            <div
              className="login-alert login-alert--error"
              role="alert"
            >
              <span className="login-alert__icon">
                !
              </span>

              <span>{error}</span>
            </div>
          )}

          {/* Submit */}

          <button
            type="submit"
            className="login-submit"
            disabled={loading}
          >
            {loading ? (
              <>
                <span className="login-spinner" />
                Signing in...
              </>
            ) : (
              "Sign in"
            )}
          </button>
        </form>

        {/* ==================================================
            REGISTER
        ================================================== */}

        <p className="login-register">
          Don&apos;t have an account?{" "}
          <Link href="/register">
            Create an account
          </Link>
        </p>

      </section>
    </main>
  );
}