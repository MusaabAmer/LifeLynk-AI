"use client";

import {
  FormEvent,
  useState,
} from "react";

import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";

type RegistrationRole =
  | "HOSPITAL_ADMIN"
  | "BLOOD_BANK_ADMIN";

export default function RegisterPage() {
  const router = useRouter();

  const [fullName, setFullName] =
    useState("");

  const [email, setEmail] =
    useState("");

  const [password, setPassword] =
    useState("");

  const [confirmPassword, setConfirmPassword] =
    useState("");

  const [role, setRole] =
    useState<RegistrationRole>(
      "HOSPITAL_ADMIN",
    );

  const [showPassword, setShowPassword] =
    useState(false);

  const [showConfirmPassword, setShowConfirmPassword] =
    useState(false);

  const [loading, setLoading] =
    useState(false);

  const [error, setError] =
    useState("");

  async function handleRegister(
    event: FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault();

    setError("");

    const normalizedName =
      fullName.trim();

    const normalizedEmail =
      email.trim().toLowerCase();

    /*
     * --------------------------------------------------
     * VALIDATION
     * --------------------------------------------------
     */

    if (!normalizedName) {
      setError(
        "Please enter your full name.",
      );
      return;
    }

    if (normalizedName.length < 2) {
      setError(
        "Please enter a valid full name.",
      );
      return;
    }

    if (!normalizedEmail) {
      setError(
        "Please enter your email address.",
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

    if (
      password !== confirmPassword
    ) {
      setError(
        "Passwords do not match.",
      );
      return;
    }

    setLoading(true);

    try {
      /*
       * ------------------------------------------------
       * SERVER-SIDE REGISTRATION
       * ------------------------------------------------
       *
       * The actual Supabase signUp() happens inside
       * /auth/register.
       *
       * This is important because the server route
       * captures and returns the PKCE verifier cookie.
       */

      const response =
        await fetch(
          "/auth/register",
          {
            method: "POST",

            headers: {
              "Content-Type":
                "application/json",
            },

            body: JSON.stringify({
              fullName:
                normalizedName,

              email:
                normalizedEmail,

              password,

              role,
            }),
          },
        );

      /*
       * ------------------------------------------------
       * RESPONSE
       * ------------------------------------------------
       */

      let result:
        | {
            success?: boolean;
            userId?: string;
            email?: string;
            error?: string;
          }
        | null = null;

      try {
        result =
          await response.json();
      } catch {
        result = null;
      }

      /*
       * ------------------------------------------------
       * SERVER ERROR
       * ------------------------------------------------
       */

      if (!response.ok) {
        if (
          process.env.NODE_ENV ===
          "development"
        ) {
          console.error(
            "WEB REGISTRATION ERROR",
            result,
          );
        }

        setError(
          getRegistrationErrorMessage(
            result?.error ??
              "Unable to create your account.",
          ),
        );

        return;
      }

      /*
       * ------------------------------------------------
       * SUCCESS VALIDATION
       * ------------------------------------------------
       */

      if (
        !result?.success ||
        !result?.userId
      ) {
        setError(
          "Unable to create your account. Please try again.",
        );

        return;
      }

      /*
       * ------------------------------------------------
       * EMAIL VERIFICATION
       * ------------------------------------------------
       *
       * Do NOT check for a session here.
       *
       * The user must verify the email first.
       */

      router.replace(
        `/verify-email?email=${encodeURIComponent(
          normalizedEmail,
        )}`,
      );
    } catch (registrationError) {
      if (
        process.env.NODE_ENV ===
        "development"
      ) {
        console.error(
          "WEB REGISTRATION UNEXPECTED ERROR",
          registrationError,
        );
      }

      setError(
        "Something went wrong while creating your account. Please try again.",
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="lifelynk-auth">
      <section className="lifelynk-auth__card">
        <Image
          src="/images/lifelynk-logo.png"
          alt="LifeLynk AI"
          width={300}
          height={200}
          priority
          className="auth-logo-image"
        />

        {/* Heading */}
        <div className="lifelynk-auth__heading">
          <h1>
            Create your account
          </h1>

          <p>
            Join the LifeLynk healthcare
            network.
          </p>
        </div>

        <form
          className="lifelynk-auth__form"
          onSubmit={handleRegister}
          noValidate
        >
          {/* Full name */}
          <div className="lifelynk-auth__field">
            <label htmlFor="fullName">
              Full name
            </label>

            <div className="lifelynk-auth__input-wrap">
              <svg
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <circle
                  cx="12"
                  cy="8"
                  r="4"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.8"
                />

                <path
                  d="M4 21c.8-4 3.5-6 8-6s7.2 2 8 6"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.8"
                  strokeLinecap="round"
                />
              </svg>

              <input
                id="fullName"
                type="text"
                value={fullName}
                onChange={(event) =>
                  setFullName(
                    event.target.value,
                  )
                }
                placeholder="Enter your full name"
                autoComplete="name"
                required
                disabled={loading}
              />
            </div>
          </div>

          {/* Account type */}
          <div className="lifelynk-auth__field">
            <label htmlFor="role">
              Account type
            </label>

            <div className="lifelynk-auth__input-wrap">
              <select
                id="role"
                value={role}
                onChange={(event) =>
                  setRole(
                    event.target
                      .value as RegistrationRole,
                  )
                }
                disabled={loading}
                required
              >
                <option value="HOSPITAL_ADMIN">
                  Hospital Administrator
                </option>

                <option value="BLOOD_BANK_ADMIN">
                  Blood Bank Administrator
                </option>
              </select>
            </div>
          </div>

          {/* Email */}
          <div className="lifelynk-auth__field">
            <label htmlFor="email">
              Email address
            </label>

            <div className="lifelynk-auth__input-wrap">
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
                id="email"
                type="email"
                value={email}
                onChange={(event) =>
                  setEmail(
                    event.target.value,
                  )
                }
                placeholder="you@example.com"
                autoComplete="email"
                required
                disabled={loading}
              />
            </div>
          </div>

          {/* Password */}
          <div className="lifelynk-auth__field">
            <label htmlFor="password">
              Password
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
                  setPassword(
                    event.target.value,
                  )
                }
                placeholder="Create a password"
                autoComplete="new-password"
                required
                disabled={loading}
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
                disabled={loading}
              >
                ◉
              </button>
            </div>
          </div>

          {/* Confirm password */}
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
                value={
                  confirmPassword
                }
                onChange={(event) =>
                  setConfirmPassword(
                    event.target.value,
                  )
                }
                placeholder="Confirm your password"
                autoComplete="new-password"
                required
                disabled={loading}
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
                disabled={loading}
              >
                ◉
              </button>
            </div>
          </div>

          {/* Password requirements */}
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

          {/* Error */}
          {error && (
            <div
              className="lifelynk-auth__error"
              role="alert"
            >
              {error}
            </div>
          )}

          {/* Submit */}
          <button
            type="submit"
            className="lifelynk-auth__submit"
            disabled={loading}
          >
            {loading
              ? "Creating account..."
              : "Create account"}
          </button>
        </form>

        {/* Login */}
        <p className="lifelynk-auth__register">
          Already have an account?{" "}
          <Link href="/login">
            Sign in
          </Link>
        </p>
      </section>
    </main>
  );
}

function getRegistrationErrorMessage(
  message: string,
): string {
  const normalized =
    message.toLowerCase();

  if (
    normalized.includes(
      "already registered",
    ) ||
    normalized.includes(
      "user already exists",
    )
  ) {
    return "An account with this email already exists. Please sign in instead.";
  }

  if (
    normalized.includes("password") &&
    normalized.includes("weak")
  ) {
    return "This password is too weak. Please choose a stronger password.";
  }

  if (
    normalized.includes("rate limit") ||
    normalized.includes("too many")
  ) {
    return "Too many registration attempts. Please wait a moment and try again.";
  }

  if (
    normalized.includes("email") &&
    normalized.includes("invalid")
  ) {
    return "Please enter a valid email address.";
  }

  return "Unable to create your account. Please check your information and try again.";
}