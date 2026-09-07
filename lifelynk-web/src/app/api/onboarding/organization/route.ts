import { NextResponse } from "next/server";

import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

export async function POST(request: Request) {
  try {
    /*
     * ------------------------------------------------
     * 1. Verify authenticated user
     * ------------------------------------------------
     */
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
     * 2. Read requested organization
     * ------------------------------------------------
     */
    const body = await request.json();

    const organizationId = body?.organizationId;

    if (typeof organizationId !== "string") {
      return NextResponse.json(
        {
          error: "Invalid organization.",
        },
        { status: 400 },
      );
    }

    /*
     * ------------------------------------------------
     * 3. Load application user + role
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
          error: "Application profile not found.",
        },
        { status: 404 },
      );
    }

    if (!profile.is_active) {
      return NextResponse.json(
        {
          error: "Your account is inactive.",
        },
        { status: 403 },
      );
    }

    if (!profile.is_verified) {
      return NextResponse.json(
        {
          error:
            "Your account has not been verified.",
        },
        { status: 403 },
      );
    }

    /*
     * ------------------------------------------------
     * 4. Determine role
     * ------------------------------------------------
     */
    const roleData = Array.isArray(profile.roles)
      ? profile.roles[0]
      : profile.roles;

    const role = roleData?.name;

    if (
      role !== "HOSPITAL_ADMIN" &&
      role !== "BLOOD_BANK_ADMIN"
    ) {
      return NextResponse.json(
        {
          error:
            "Your role cannot request organization access through onboarding.",
        },
        { status: 403 },
      );
    }

    /*
     * ------------------------------------------------
     * 5. Determine required organization type
     * ------------------------------------------------
     */
    const requiredType =
      role === "HOSPITAL_ADMIN"
        ? "HOSPITAL"
        : "BLOOD_BANK";

    /*
     * ------------------------------------------------
     * 6. Verify selected organization
     * ------------------------------------------------
     */
    const {
      data: organization,
      error: organizationError,
    } = await supabase
      .from("organizations")
      .select(`
        id,
        name,
        organization_type,
        verification_status
      `)
      .eq("id", organizationId)
      .is("deleted_at", null)
      .maybeSingle();

    if (
      organizationError ||
      !organization
    ) {
      return NextResponse.json(
        {
          error: "Organization not found.",
        },
        { status: 404 },
      );
    }

    /*
     * ------------------------------------------------
     * 7. Only verified organizations can receive
     *    join requests.
     * ------------------------------------------------
     */
    if (
      organization.verification_status !==
      "VERIFIED"
    ) {
      return NextResponse.json(
        {
          error:
            "This organization has not been verified.",
        },
        { status: 403 },
      );
    }

    /*
     * ------------------------------------------------
     * 8. Organization type must match account role
     * ------------------------------------------------
     */
    if (
      organization.organization_type !==
      requiredType
    ) {
      return NextResponse.json(
        {
          error:
            "This organization is not compatible with your account role.",
        },
        { status: 403 },
      );
    }

    /*
     * ------------------------------------------------
     * 9. Use admin client for the controlled write.
     *
     * IMPORTANT:
     * We NEVER create organization_staff here.
     * We NEVER create another account.
     * We NEVER make this user primary.
     * ------------------------------------------------
     */
    const admin = createAdminClient();

    /*
     * ------------------------------------------------
     * 10. Check whether the user is already a member
     * ------------------------------------------------
     */
    const {
      data: existingMembership,
      error: membershipError,
    } = await admin
      .from("organization_staff")
      .select(`
        id,
        organization_id
      `)
      .eq("user_id", user.id)
      .is("deleted_at", null)
      .limit(1)
      .maybeSingle();

    if (membershipError) {
      console.error(
        "Organization membership lookup error:",
        membershipError,
      );

      return NextResponse.json(
        {
          error:
            "Unable to verify your organization membership.",
        },
        { status: 500 },
      );
    }

    if (existingMembership) {
      return NextResponse.json(
        {
          error:
            "Your account is already assigned to an organization.",
        },
        { status: 409 },
      );
    }

    /*
     * ------------------------------------------------
     * 11. Check existing pending request
     * ------------------------------------------------
     */
    const {
      data: existingRequest,
      error: requestLookupError,
    } = await admin
      .from("organization_join_requests")
      .select(`
        id,
        organization_id,
        status
      `)
      .eq("user_id", user.id)
      .eq(
        "organization_id",
        organization.id,
      )
      .eq("status", "PENDING")
      .maybeSingle();

    if (requestLookupError) {
      console.error(
        "Organization join request lookup error:",
        requestLookupError,
      );

      return NextResponse.json(
        {
          error:
            "Unable to check your existing access request.",
        },
        { status: 500 },
      );
    }

    if (existingRequest) {
      return NextResponse.json(
        {
          success: true,
          pending: true,
          message:
            "Your request to join this organization is already pending.",
          organization: {
            id: organization.id,
            name: organization.name,
            type:
              organization.organization_type,
          },
        },
        { status: 200 },
      );
    }

    /*
     * ------------------------------------------------
     * 12. Prevent a pending request to another
     *     organization.
     *
     * One admin account should not simultaneously
     * request access to multiple organizations.
     * ------------------------------------------------
     */
    const {
      data: anotherPendingRequest,
      error: pendingLookupError,
    } = await admin
      .from("organization_join_requests")
      .select(`
        id,
        organization_id,
        organizations (
          id,
          name
        )
      `)
      .eq("user_id", user.id)
      .eq("status", "PENDING")
      .limit(1)
      .maybeSingle();

    if (pendingLookupError) {
      console.error(
        "Pending organization request lookup error:",
        pendingLookupError,
      );

      return NextResponse.json(
        {
          error:
            "Unable to verify your pending organization requests.",
        },
        { status: 500 },
      );
    }

    if (anotherPendingRequest) {
      const pendingOrganization =
        Array.isArray(
          anotherPendingRequest.organizations,
        )
          ? anotherPendingRequest
              .organizations[0]
          : anotherPendingRequest.organizations;

      return NextResponse.json(
        {
          error:
            `You already have a pending request for ${
              pendingOrganization?.name ??
              "another organization"
            }.`,
        },
        { status: 409 },
      );
    }

    /*
     * ------------------------------------------------
     * 13. Create PENDING join request.
     *
     * THIS IS THE ONLY WRITE.
     *
     * No organization_staff row is created.
     * ------------------------------------------------
     */
    const {
      data: joinRequest,
      error: insertError,
    } = await admin
      .from("organization_join_requests")
      .insert({
        organization_id:
          organization.id,
        user_id: user.id,
        status: "PENDING",
      })
      .select(`
        id,
        organization_id,
        user_id,
        status,
        requested_at
      `)
      .single();

    if (insertError || !joinRequest) {
      console.error(
        "Organization join request insert error:",
        insertError,
      );

      return NextResponse.json(
        {
          error:
            "Unable to submit your organization access request.",
        },
        { status: 500 },
      );
    }

    /*
     * ------------------------------------------------
     * 14. Return pending status.
     * ------------------------------------------------
     */
    return NextResponse.json({
      success: true,
      pending: true,
      message:
        "Your request has been submitted. The organization administrator must approve it before you can access the dashboard.",
      organization: {
        id: organization.id,
        name: organization.name,
        type:
          organization.organization_type,
      },
    });
  } catch (error) {
    console.error(
      "Organization onboarding error:",
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