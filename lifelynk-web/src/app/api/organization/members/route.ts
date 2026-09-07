import { NextResponse } from "next/server";

import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";

export async function GET() {
  try {
    const supabase = await createClient();

    /*
     * ------------------------------------------------------------
     * AUTH
     * ------------------------------------------------------------
     */
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return NextResponse.json(
        { error: "Unauthorized" },
        { status: 401 },
      );
    }

    /*
     * ------------------------------------------------------------
     * LOAD USER PROFILE
     * ------------------------------------------------------------
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
        is_verified
      `)
      .eq("id", user.id)
      .maybeSingle();

    if (profileError) {
      console.error(
        "ORGANIZATION MEMBERS PROFILE ERROR:",
        profileError,
      );

      return NextResponse.json(
        {
          error: "Unable to load user profile",
          details: profileError.message,
        },
        { status: 500 },
      );
    }

    if (!profile) {
      return NextResponse.json(
        {
          error: "User profile not found",
        },
        { status: 404 },
      );
    }

    /*
     * ------------------------------------------------------------
     * LOAD ROLE
     * ------------------------------------------------------------
     */
    const {
      data: roleRecord,
      error: roleError,
    } = await supabase
      .from("roles")
      .select("name")
      .eq("id", profile.role_id)
      .maybeSingle();

    if (roleError) {
      console.error(
        "ORGANIZATION MEMBERS ROLE ERROR:",
        roleError,
      );

      return NextResponse.json(
        {
          error: "Unable to load user role",
          details: roleError.message,
        },
        { status: 500 },
      );
    }

    const role = roleRecord?.name;

    /*
     * ------------------------------------------------------------
     * ORGANIZATION USERS ONLY
     * ------------------------------------------------------------
     */
    if (
      role !== "HOSPITAL_ADMIN" &&
      role !== "BLOOD_BANK_ADMIN"
    ) {
      return NextResponse.json(
        {
          error: "Forbidden",
        },
        { status: 403 },
      );
    }

    /*
     * ------------------------------------------------------------
     * ACCOUNT MUST BE ACTIVE + VERIFIED
     * ------------------------------------------------------------
     */
    if (
      profile.is_active !== true ||
      profile.is_verified !== true
    ) {
      return NextResponse.json(
        {
          error:
            "Account is not active or verified",
        },
        { status: 403 },
      );
    }

    /*
     * ------------------------------------------------------------
     * FIND ANY ACTIVE ORGANIZATION MEMBERSHIP
     * ------------------------------------------------------------
     *
     * IMPORTANT:
     *
     * Member 1:
     *   is_primary = true
     *
     * Member 2:
     *   is_primary = false
     *
     * Member 3:
     *   is_primary = false
     *
     * All of them still have organization_id and therefore
     * can view the organization member list.
     *
     * ------------------------------------------------------------
     */
    const {
      data: staffMemberships,
      error: staffError,
    } = await supabase
      .from("organization_staff")
      .select(`
        id,
        organization_id,
        user_id,
        is_primary,
        created_at
      `)
      .eq("user_id", user.id)
      .is("deleted_at", null)
      .order("is_primary", {
        ascending: false,
      })
      .order("created_at", {
        ascending: true,
      });

    if (staffError) {
      console.error(
        "ORGANIZATION MEMBERS STAFF ERROR:",
        staffError,
      );

      return NextResponse.json(
        {
          error:
            "Unable to determine organization membership",
          details: staffError.message,
        },
        { status: 500 },
      );
    }

    if (
      !staffMemberships ||
      staffMemberships.length === 0
    ) {
      return NextResponse.json(
        {
          error:
            "You are not currently a member of an organization.",
        },
        { status: 404 },
      );
    }

    /*
     * ------------------------------------------------------------
     * USE PRIMARY MEMBERSHIP IF AVAILABLE
     * OTHERWISE USE FIRST ACTIVE MEMBERSHIP
     * ------------------------------------------------------------
     */
    const primaryMembership =
      staffMemberships.find(
        (membership) =>
          membership.is_primary === true,
      );

    const staffMembership =
      primaryMembership ??
      staffMemberships[0];

    const isPrimaryAdministrator =
      staffMembership.is_primary === true;

    /*
     * ------------------------------------------------------------
     * LOAD ORGANIZATION
     * ------------------------------------------------------------
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
        city_id
      `)
      .eq(
        "id",
        staffMembership.organization_id,
      )
      .maybeSingle();

    if (organizationError) {
      console.error(
        "ORGANIZATION MEMBERS ORGANIZATION ERROR:",
        organizationError,
      );

      return NextResponse.json(
        {
          error:
            "Unable to load organization",
          details:
            organizationError.message,
        },
        { status: 500 },
      );
    }

    if (!organization) {
      return NextResponse.json(
        {
          error: "Organization not found",
        },
        { status: 404 },
      );
    }

    /*
     * ------------------------------------------------------------
     * ADMIN CLIENT
     * ------------------------------------------------------------
     */
    const admin = createAdminClient();

    /*
     * ------------------------------------------------------------
     * LOAD ALL ACTIVE ORGANIZATION MEMBERS
     * ------------------------------------------------------------
     *
     * Actual database FK:
     *
     * fk_organization_staff_user_id_users
     *
     * ------------------------------------------------------------
     */
    const {
      data: members,
      error: membersError,
    } = await admin
      .from("organization_staff")
      .select(`
        id,
        user_id,
        organization_id,
        is_primary,
        created_at,
        users!fk_organization_staff_user_id_users (
          id,
          email,
          full_name
        )
      `)
      .eq(
        "organization_id",
        organization.id,
      )
      .is("deleted_at", null)
      .order("is_primary", {
        ascending: false,
      })
      .order("created_at", {
        ascending: true,
      });

    if (membersError) {
      console.error(
        "ORGANIZATION MEMBERS QUERY ERROR:",
        membersError,
      );

      return NextResponse.json(
        {
          error:
            "Unable to load organization members",
          details:
            membersError.message,
        },
        { status: 500 },
      );
    }

    /*
     * ------------------------------------------------------------
     * NORMALIZE MEMBER DATA
     * ------------------------------------------------------------
     */
    const normalizedMembers =
      (members ?? []).map((member) => {
        const relatedUser =
          Array.isArray(member.users)
            ? member.users[0] ?? null
            : member.users ?? null;

        return {
          id: member.id,
          user_id: member.user_id,
          organization_id:
            member.organization_id,
          is_primary: member.is_primary,
          created_at: member.created_at,
          user: relatedUser,
        };
      });

    /*
     * ------------------------------------------------------------
     * RESPONSE
     * ------------------------------------------------------------
     */
    return NextResponse.json({
      success: true,

      organization: {
        id: organization.id,
        name: organization.name,
        type: organization.organization_type,
        organization_type:
          organization.organization_type,
        city_id: organization.city_id,
      },

      /*
       * Member 1 = true
       * Member 2/3 = false
       */
      is_primary:
        isPrimaryAdministrator,

      /*
       * Only the primary administrator can
       * approve/reject join requests.
       */
      can_manage:
        isPrimaryAdministrator,

      members: normalizedMembers,

      count: normalizedMembers.length,
    });
  } catch (error) {
    console.error(
      "ORGANIZATION MEMBERS UNEXPECTED ERROR:",
      error,
    );

    return NextResponse.json(
      {
        error:
          "Something went wrong while loading organization members",
      },
      { status: 500 },
    );
  }
}