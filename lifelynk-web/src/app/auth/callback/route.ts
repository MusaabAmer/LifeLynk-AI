import {
  NextRequest,
  NextResponse,
} from "next/server";

import {
  createClient,
} from "@/lib/supabase/server";

const ALLOWED_NEXT_ROUTES = [
  "/onboarding",
  "/dashboard",
  "/reset-password",
  "/organization-verification/pending",
  "/organization-verification/rejected",
];

function getSafeNextPath(
  requestedNext: string | null,
): string {
  if (
    requestedNext &&
    requestedNext.startsWith("/") &&
    !requestedNext.startsWith("//") &&
    ALLOWED_NEXT_ROUTES.includes(requestedNext)
  ) {
    return requestedNext;
  }

  return "/dashboard";
}

function redirectToAuthError(
  request: NextRequest,
  errorCode: string,
) {
  const errorUrl =
    request.nextUrl.clone();

  errorUrl.pathname = "/auth/error";
  errorUrl.search = "";

  errorUrl.searchParams.set(
    "error",
    errorCode,
  );

  return NextResponse.redirect(
    errorUrl,
  );
}

function getSafeAuthErrorMessage(
  code: string | undefined,
): string {
  switch (code) {
    case "otp_expired":
      return "The authentication link has expired. Please request a new one.";

    case "otp_already_used":
      return "This authentication link has already been used. Please request a new one.";

    case "invalid_token":
    case "validation_failed":
      return "The authentication link is invalid. Please request a new link and try again.";

    case "session_not_found":
      return "Your session could not be established. Please try again.";

    default:
      return "The authentication link is invalid or has expired.";
  }
}

export async function GET(
  request: NextRequest,
) {
  const searchParams =
    request.nextUrl.searchParams;

  /*
   * --------------------------------------------------------
   * CURRENT SUPABASE PKCE FLOW
   * --------------------------------------------------------
   *
   * Fresh Supabase confirmation emails arrive as:
   *
   * /auth/confirm?code=...&next=/onboarding
   *
   * The code must be exchanged for a session.
   */
  const code =
    searchParams.get("code");

  const requestedNext =
    searchParams.get("next");

  /*
   * --------------------------------------------------------
   * LEGACY TOKEN-HASH FLOW
   * --------------------------------------------------------
   *
   * Keep support for older Supabase links that contain:
   *
   * token_hash=...&type=email
   */
  const tokenHash =
    searchParams.get("token_hash");

  const type =
    searchParams.get("type");

  /*
   * We need either:
   *
   * 1. code
   * 2. token_hash + type
   */
  if (
    !code &&
    (!tokenHash || !type)
  ) {
    return redirectToAuthError(
      request,
      "invalid_link",
    );
  }

  const nextPath =
    getSafeNextPath(
      requestedNext,
    );

  const supabase =
    await createClient();

  /*
   * --------------------------------------------------------
   * MODERN PKCE CODE FLOW
   * --------------------------------------------------------
   */
  if (code) {
    const {
      error: exchangeError,
    } =
      await supabase.auth.exchangeCodeForSession(
        code,
      );

    if (exchangeError) {
      console.error(
        "AUTH CONFIRM CODE EXCHANGE ERROR",
        {
          message:
            exchangeError.message,
          status:
            exchangeError.status,
          code:
            exchangeError.code,
        },
      );

      return redirectToAuthError(
        request,
        "auth_callback_failed",
      );
    }
  }

  /*
   * --------------------------------------------------------
   * LEGACY TOKEN-HASH FLOW
   * --------------------------------------------------------
   */
  if (
    !code &&
    tokenHash &&
    type
  ) {
    const {
      error: verifyError,
    } =
      await supabase.auth.verifyOtp({
        token_hash: tokenHash,
        type:
          type as
            | "email"
            | "signup"
            | "invite"
            | "recovery"
            | "email_change",
      });

    if (verifyError) {
      console.error(
        "AUTH CONFIRM OTP ERROR",
        {
          message:
            verifyError.message,
          status:
            verifyError.status,
          code:
            verifyError.code,
          type,
        },
      );

      return redirectToAuthError(
        request,
        getSafeAuthErrorMessage(
          verifyError.code,
        ),
      );
    }
  }

  /*
   * --------------------------------------------------------
   * VERIFY SESSION
   * --------------------------------------------------------
   */
  const {
    data: {
      user,
    },
  } =
    await supabase.auth.getUser();

  if (!user) {
    console.error(
      "AUTH CONFIRM: SESSION NOT CREATED",
    );

    return redirectToAuthError(
      request,
      "session_not_created",
    );
  }

  /*
   * --------------------------------------------------------
   * EMAIL VERIFICATION CHECK
   * --------------------------------------------------------
   *
   * Supabase should now have email_confirmed_at
   * for a successfully confirmed signup.
   */
  if (!user.email_confirmed_at) {
    console.error(
      "AUTH CONFIRM: EMAIL NOT VERIFIED",
      {
        userId: user.id,
      },
    );

    return redirectToAuthError(
      request,
      "email_not_verified",
    );
  }

  /*
   * --------------------------------------------------------
   * SUCCESS
   * --------------------------------------------------------
   */
  const successUrl =
    request.nextUrl.clone();

  successUrl.pathname =
    nextPath;

  successUrl.search = "";

  return NextResponse.redirect(
    successUrl,
  );
}