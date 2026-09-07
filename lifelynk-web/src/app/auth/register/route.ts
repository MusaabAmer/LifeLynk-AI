import {
  NextRequest,
  NextResponse,
} from "next/server";

import { cookies } from "next/headers";
import { createServerClient } from "@supabase/ssr";

type RegistrationRole =
  | "HOSPITAL_ADMIN"
  | "BLOOD_BANK_ADMIN";

const ALLOWED_ROLES: RegistrationRole[] = [
  "HOSPITAL_ADMIN",
  "BLOOD_BANK_ADMIN",
];

export async function POST(
  request: NextRequest,
) {
  try {
    const body =
      await request.json();

    const fullName =
      typeof body.fullName === "string"
        ? body.fullName.trim()
        : "";

    const email =
      typeof body.email === "string"
        ? body.email.trim().toLowerCase()
        : "";

    const password =
      typeof body.password === "string"
        ? body.password
        : "";

    const role =
      typeof body.role === "string"
        ? body.role
        : "";

    /*
     * --------------------------------------------------
     * VALIDATION
     * --------------------------------------------------
     */

    if (
      !fullName ||
      fullName.length < 2
    ) {
      return NextResponse.json(
        {
          error:
            "Please enter a valid full name.",
        },
        {
          status: 400,
        },
      );
    }

    if (!email) {
      return NextResponse.json(
        {
          error:
            "Please enter your email address.",
        },
        {
          status: 400,
        },
      );
    }

    if (
      !ALLOWED_ROLES.includes(
        role as RegistrationRole,
      )
    ) {
      return NextResponse.json(
        {
          error:
            "Please select a valid account type.",
        },
        {
          status: 400,
        },
      );
    }

    if (password.length < 8) {
      return NextResponse.json(
        {
          error:
            "Password must contain at least 8 characters.",
        },
        {
          status: 400,
        },
      );
    }

    if (!/[A-Z]/.test(password)) {
      return NextResponse.json(
        {
          error:
            "Password must contain at least one uppercase letter.",
        },
        {
          status: 400,
        },
      );
    }

    if (!/\d/.test(password)) {
      return NextResponse.json(
        {
          error:
            "Password must contain at least one number.",
        },
        {
          status: 400,
        },
      );
    }

    /*
     * --------------------------------------------------
     * COOKIE STORAGE
     * --------------------------------------------------
     *
     * Supabase SSR can generate PKCE verifier cookies
     * during signUp().
     *
     * We capture those cookies first and then attach
     * them to the FINAL NextResponse returned below.
     */

    const cookieStore =
      await cookies();

    const cookiesToSet: Array<{
      name: string;
      value: string;
      options?: Record<
        string,
        unknown
      >;
    }> = [];

    /*
     * --------------------------------------------------
     * SUPABASE SERVER CLIENT
     * --------------------------------------------------
     */

    const supabase =
      createServerClient(
        process.env
          .NEXT_PUBLIC_SUPABASE_URL!,
        process.env
          .NEXT_PUBLIC_SUPABASE_ANON_KEY!,
        {
          cookies: {
            getAll() {
              return cookieStore.getAll();
            },

            setAll(
              newCookies,
            ) {
              cookiesToSet.push(
                ...newCookies,
              );
            },
          },
        },
      );

    /*
     * --------------------------------------------------
     * EMAIL CALLBACK
     * --------------------------------------------------
     */

    const origin =
      request.nextUrl.origin;

    const emailRedirectTo =
      `${origin}/auth/confirm?next=/onboarding`;

    /*
     * --------------------------------------------------
     * CREATE SUPABASE ACCOUNT
     * --------------------------------------------------
     */

    const {
      data: { user },
      error,
    } =
      await supabase.auth.signUp({
        email,
        password,

        options: {
          emailRedirectTo,

          data: {
            full_name:
              fullName,

            registration_role:
              role as RegistrationRole,
          },
        },
      });

    /*
     * --------------------------------------------------
     * SUPABASE ERROR
     * --------------------------------------------------
     */

    if (error) {
      console.error(
        "SERVER SUPABASE SIGNUP ERROR",
        {
          message:
            error.message,

          status:
            error.status,

          code:
            error.code,
        },
      );

      return NextResponse.json(
        {
          error:
            error.message,
        },
        {
          status: 400,
        },
      );
    }

    /*
     * --------------------------------------------------
     * USER CHECK
     * --------------------------------------------------
     */

    if (!user) {
      return NextResponse.json(
        {
          error:
            "Unable to create your account. Please try again.",
        },
        {
          status: 500,
        },
      );
    }

    /*
     * --------------------------------------------------
     * FINAL RESPONSE
     * --------------------------------------------------
     */

    const response =
      NextResponse.json(
        {
          success: true,

          userId:
            user.id,

          email:
            user.email,
        },
        {
          status: 200,
        },
      );

    /*
     * --------------------------------------------------
     * APPLY ALL SUPABASE COOKIES
     * --------------------------------------------------
     *
     * This is the critical part.
     *
     * The PKCE verifier generated during signUp()
     * must reach the browser.
     */

    for (
      const cookie of cookiesToSet
    ) {
      response.cookies.set(
        cookie.name,
        cookie.value,
        cookie.options,
      );
    }

    /*
     * --------------------------------------------------
     * REGISTRATION MARKER
     * --------------------------------------------------
     */

    response.cookies.set(
      "lifelynk-registration",
      "complete",
      {
        httpOnly: true,

        secure:
          process.env.NODE_ENV ===
          "production",

        sameSite: "lax",

        path: "/",

        maxAge: 600,
      },
    );

    /*
     * --------------------------------------------------
     * DEBUG
     * --------------------------------------------------
     *
     * Only cookie names are logged.
     * Cookie values are NEVER logged.
     */

    console.log(
      "AUTH REGISTER COOKIES APPLIED TO FINAL RESPONSE",
      response.cookies
        .getAll()
        .map(
          ({
            name,
            path,
          }) => ({
            name,
            path,
          }),
        ),
    );

    return response;
  } catch (error) {
    console.error(
      "SERVER REGISTRATION UNEXPECTED ERROR",
      error,
    );

    return NextResponse.json(
      {
        error:
          "Something went wrong while creating your account.",
      },
      {
        status: 500,
      },
    );
  }
}