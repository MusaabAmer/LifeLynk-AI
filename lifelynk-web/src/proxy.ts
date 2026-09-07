import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";

const protectedRoutes = [
  "/dashboard",
  "/onboarding",
  "/blood-inventory",
  "/blood-requests",
  "/donors",
  "/emergency-sos",
  "/hospitals",
  "/locations",
  "/notifications",
  "/settings",
  "/organization-verification",
];

function isProtectedRoute(pathname: string) {
  return protectedRoutes.some(
    (route) =>
      pathname === route ||
      pathname.startsWith(`${route}/`),
  );
}

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;

  const publicSystemPaths = [
    "/manifest.webmanifest",
    "/robots.txt",
    "/sitemap.xml",
  ];

  if (publicSystemPaths.includes(pathname)) {
    return NextResponse.next();
  }

  /*
   * --------------------------------------------------------
   * AUTH ROUTES
   * --------------------------------------------------------
   *
   * Do NOT run the authentication proxy lifecycle on:
   *
   * /auth/register
   * /auth/confirm
   * /auth/callback
   * /auth/error
   *
   * These routes must be allowed to handle Supabase
   * authentication cookies directly.
   *
   * This is especially important for the PKCE
   * code-verifier used during email confirmation.
   */
  if (pathname.startsWith("/auth")) {
    return NextResponse.next();
  }

  /*
   * --------------------------------------------------------
   * SUPABASE SSR RESPONSE
   * --------------------------------------------------------
   */

  let response = NextResponse.next({
    request,
  });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },

        setAll(cookiesToSet) {
          cookiesToSet.forEach(
            ({
              name,
              value,
            }) => {
              request.cookies.set(
                name,
                value,
              );
            },
          );

          cookiesToSet.forEach(
            ({
              name,
              value,
              options,
            }) => {
              response.cookies.set(
                name,
                value,
                options,
              );
            },
          );
        },
      },
    },
  );

  /*
   * --------------------------------------------------------
   * REFRESH / VALIDATE SUPABASE SESSION
   * --------------------------------------------------------
   */

  const {
    data: {
      user,
    },
  } = await supabase.auth.getUser();

  /*
   * --------------------------------------------------------
   * PROTECTED ROUTES
   * --------------------------------------------------------
   */

  if (
    isProtectedRoute(pathname) &&
    !user
  ) {
    const loginUrl =
      request.nextUrl.clone();

    loginUrl.pathname = "/login";
    loginUrl.search = "";

    loginUrl.searchParams.set(
      "redirectTo",
      pathname,
    );

    return NextResponse.redirect(
      loginUrl,
    );
  }

  /*
   * --------------------------------------------------------
   * AUTHENTICATED USERS
   * --------------------------------------------------------
   */

  if (
    pathname === "/login" &&
    user
  ) {
    const dashboardUrl =
      request.nextUrl.clone();

    dashboardUrl.pathname =
      "/dashboard";

    dashboardUrl.search = "";

    return NextResponse.redirect(
      dashboardUrl,
    );
  }

  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
  ],
};