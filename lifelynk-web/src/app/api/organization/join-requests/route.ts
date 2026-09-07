import { NextResponse } from "next/server";

import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

export async function GET() {
  try {
    const supabase = await createClient();

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return NextResponse.json(
        {
          error: "You must be signed in.",
        },
        { status: 401 },
      );
    }

    /*
     * ------------------------------------------------
     * Load current application user
     * ------------------------------------------------
     */
    const {
      data: profile,
      error: profileError,
    } = await supabase
      .from("users")
      .select(`
        id,
        role_id,
        is_active,
        is_verified,
        roles (
          id,
          name
        )
      `)
      .eq("id", user.id)
      .is("deleted_at", null)
      .maybeSingle();

    if (profileError || !profile) {
      return NextResponse.json(
        {
          error:
            "Application profile not found.",
        },
        { status: 404 },
      );
    }

    if (
      !profile.is_active ||
      !profile.is_verified
    ) {
      return NextResponse.json(
        {
          error:
            "Your account is not active and verified.",
        },
        { status: 403 },
      );
    }

    const roleData = Array.isArray(
      profile.roles,
    )
      ? profile.roles[0]
      : profile.roles;

    const role = roleData?.name;

    /*
     * ------------------------------------------------
     * Organization administrator only
     * ------------------------------------------------
     */
    if (
      role !== "HOSPITAL_ADMIN" &&
      role !== "BLOOD_BANK_ADMIN"
    ) {
      return NextResponse.json(
        {
          error:
            "Only organization administrators can view join requests.",
        },
        { status: 403 },
      );
    }

    /*
     * ------------------------------------------------
     * Find the organization where this user is the
     * PRIMARY administrator.
     * ------------------------------------------------
     */
    const {
      data: membership,
      error: membershipError,
    } = await supabase
      .from("organization_staff")
      .select(`
        organization_id,
        is_primary,
        organizations (
          id,
          name,
          organization_type
        )
      `)
      .eq("user_id", user.id)
      .eq("is_primary", true)
      .is("deleted_at", null)
      .limit(1)
      .maybeSingle();

    if (
      membershipError ||
      !membership
    ) {
      return NextResponse.json(
        {
          error:
            "You are not the primary administrator of an organization.",
        },
        { status: 403 },
      );
    }

    const organization = Array.isArray(
      membership.organizations,
    )
      ? membership.organizations[0]
      : membership.organizations;

    if (!organization) {
      return NextResponse.json(
        {
          error:
            "Your organization could not be found.",
        },
        { status: 404 },
      );
    }

    /*
     * ------------------------------------------------
     * Load pending requests
     * ------------------------------------------------
     */
    const admin = createAdminClient();

    const {
  data: requests,
  error: requestsError,
} = await admin
  .from("organization_join_requests")
  .select(`
    id,
    organization_id,
    user_id,
    status,
    requested_at,
    users!organization_join_requests_user_fkey (
      id,
      email,
      full_name
    )
  `)
  .eq(
    "organization_id",
    organization.id,
  )
  .eq("status", "PENDING")
  .order("requested_at", {
    ascending: false,
  });

    if (requestsError) {
      console.error(
        "JOIN REQUESTS LOAD ERROR:",
        requestsError,
      );

      return NextResponse.json(
        {
          error:
            "Unable to load organization join requests.",
        },
        { status: 500 },
      );
    }

    return NextResponse.json({
      success: true,
      organization: {
        id: organization.id,
        name: organization.name,
        type: organization.organization_type,
      },
      requests: requests ?? [],
    });
  } catch (error) {
    console.error(
      "JOIN REQUESTS GET ERROR:",
      error,
    );

    return NextResponse.json(
      {
        error:
          "Unexpected server error.",
      },
      { status: 500 },
    );
  }
}