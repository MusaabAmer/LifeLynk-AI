import {
  NextRequest,
  NextResponse,
} from "next/server";

import { createClient } from "@/lib/supabase/server";

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

function redirectToError(
  request: NextRequest,
  error: string,
) {
  const errorUrl =
    request.nextUrl.clone();

  errorUrl.pathname =
    "/auth/error";

  errorUrl.search = "";

  errorUrl.searchParams.set(
    "error",
    error,
  );

  return NextResponse.redirect(
    errorUrl,
  );
}

function getFlowIdFromCookies(
  request: NextRequest,
): string | null {
  const flowCookieName =
    "sb-aybwxfhcqnpojhjybrmr-auth-token-flows-code-verifier";

  const flowCookie =
    request.cookies.get(
      flowCookieName,
    )?.value;

  if (!flowCookie) {
    return null;
  }

  try {
    /*
     * Supabase stores the active flow IDs
     * as a base64-encoded JSON array.
     *
     * Example:
     *
     * base64-["flow-id-1","flow-id-2"]
     */

    const encoded =
      flowCookie.startsWith("base64-")
        ? flowCookie.slice(7)
        : flowCookie;

    const decoded =
      Buffer.from(
        encoded,
        "base64",
      ).toString("utf8");

    const flowIds =
      JSON.parse(decoded);

    if (
      Array.isArray(flowIds) &&
      flowIds.length > 0
    ) {
      /*
       * The most recently created flow is
       * the last item in the array.
       */
      return String(
        flowIds[flowIds.length - 1],
      );
    }
  } catch (error) {
    console.error(
      "AUTH CONFIRM FLOW COOKIE PARSE ERROR",
      error,
    );
  }

  return null;
}

export async function GET(
  request: NextRequest,
) {
  const searchParams =
    request.nextUrl.searchParams;

  const code =
    searchParams.get("code");

  const requestedNext =
    searchParams.get("next");

  if (!code) {
    return redirectToError(
      request,
      "invalid_link",
    );
  }

  /*
   * --------------------------------------------------------
   * DEBUG / PKCE COOKIE INSPECTION
   * --------------------------------------------------------
   */

  const cookieNames =
    request.cookies
      .getAll()
      .map(
        (cookie) =>
          cookie.name,
      );

  console.log(
    "AUTH CONFIRM REQUEST COOKIES",
    cookieNames.filter(
      (name) =>
        name.includes(
          "auth-token",
        ),
    ),
  );

  const flowId =
    getFlowIdFromCookies(
      request,
    );

  console.log(
    "AUTH CONFIRM PKCE FLOW ID",
    flowId,
  );

  /*
   * --------------------------------------------------------
   * SUPABASE
   * --------------------------------------------------------
   */

  const supabase =
    await createClient();

  let exchangeResult;

  if (flowId) {
    exchangeResult =
      await supabase.auth.exchangeCodeForSession(
        code,
        {
          flowId,
        },
      );
  } else {
    exchangeResult =
      await supabase.auth.exchangeCodeForSession(
        code,
      );
  }

  const {
    error: exchangeError,
  } =
    exchangeResult;

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
        flowId,
      },
    );

    return redirectToError(
      request,
      "auth_callback_failed",
    );
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

    return redirectToError(
      request,
      "session_not_created",
    );
  }

  if (!user.email_confirmed_at) {
    console.error(
      "AUTH CONFIRM: EMAIL NOT VERIFIED",
      {
        userId: user.id,
      },
    );

    return redirectToError(
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
    getSafeNextPath(
      requestedNext,
    );

  successUrl.search = "";

  return NextResponse.redirect(
    successUrl,
  );
}