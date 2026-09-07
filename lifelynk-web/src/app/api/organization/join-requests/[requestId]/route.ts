import { NextResponse } from "next/server";

import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

interface RouteContext {
  params: Promise<{
    requestId: string;
  }>;
}

export async function PATCH(
  request: Request,
  context: RouteContext,
) {
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

    const { requestId } =
      await context.params;

    if (!requestId) {
      return NextResponse.json(
        {
          error: "Invalid join request.",
        },
        { status: 400 },
      );
    }

    const body = await request.json();

    const action = body?.action;

    if (
      action !== "APPROVE" &&
      action !== "REJECT"
    ) {
      return NextResponse.json(
        {
          error: "Invalid action.",
        },
        { status: 400 },
      );
    }

    /*
     * ------------------------------------------------
     * Load current user role
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

    if (
      profileError ||
      !profile
    ) {
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
     * Only organization administrators can
     * approve/reject members.
     */

    if (
      role !== "HOSPITAL_ADMIN" &&
      role !== "BLOOD_BANK_ADMIN"
    ) {
      return NextResponse.json(
        {
          error:
            "Only organization administrators can manage join requests.",
        },
        { status: 403 },
      );
    }

    /*
     * ------------------------------------------------
     * Verify this user is PRIMARY ADMIN
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
            "You are not authorized to manage organization members.",
        },
        { status: 403 },
      );
    }

    const organization =
      Array.isArray(
        membership.organizations,
      )
        ? membership.organizations[0]
        : membership.organizations;

    if (!organization) {
      return NextResponse.json(
        {
          error:
            "Organization could not be found.",
        },
        { status: 404 },
      );
    }

    /*
     * ------------------------------------------------
     * Load requested membership
     * ------------------------------------------------
     */

    const admin =
      createAdminClient();

    const {
      data: joinRequest,
      error: joinRequestError,
    } = await admin
      .from(
        "organization_join_requests",
      )
      .select(`
        id,
        organization_id,
        user_id,
        status
      `)
      .eq("id", requestId)
      .maybeSingle();

    if (
      joinRequestError ||
      !joinRequest
    ) {
      return NextResponse.json(
        {
          error:
            "Join request not found.",
        },
        { status: 404 },
      );
    }

    /*
     * ------------------------------------------------
     * CRITICAL SECURITY CHECK
     *
     * The request must belong to THIS admin's
     * organization.
     * ------------------------------------------------
     */

    if (
      joinRequest.organization_id !==
      membership.organization_id
    ) {
      return NextResponse.json(
        {
          error:
            "You are not authorized to manage this organization's request.",
        },
        { status: 403 },
      );
    }

    if (
      joinRequest.status !==
      "PENDING"
    ) {
      return NextResponse.json(
        {
          error:
            "This request has already been processed.",
        },
        { status: 409 },
      );
    }

    /*
     * ------------------------------------------------
     * APPROVE
     * ------------------------------------------------
     */

    if (action === "APPROVE") {
      /*
       * Prevent duplicate membership.
       */

      const {
        data: existingMembership,
        error:
          existingMembershipError,
      } = await admin
        .from("organization_staff")
        .select("id")
        .eq(
          "organization_id",
          membership.organization_id,
        )
        .eq(
          "user_id",
          joinRequest.user_id,
        )
        .is("deleted_at", null)
        .maybeSingle();

      if (existingMembershipError) {
        console.error(
          "EXISTING MEMBERSHIP CHECK ERROR:",
          existingMembershipError,
        );

        return NextResponse.json(
          {
            error:
              "Unable to verify existing membership.",
          },
          { status: 500 },
        );
      }

      /*
       * If the member already exists, simply mark
       * the join request as approved.
       *
       * No new approval notification is required
       * because the user already has access.
       */

      if (existingMembership) {
        const {
          error: existingApprovalError,
        } = await admin
          .from(
            "organization_join_requests",
          )
          .update({
            status: "APPROVED",
            reviewed_at:
              new Date().toISOString(),
            reviewed_by: user.id,
          })
          .eq("id", requestId)
          .eq("status", "PENDING");

        if (existingApprovalError) {
          console.error(
            "EXISTING MEMBERSHIP APPROVAL ERROR:",
            existingApprovalError,
          );

          return NextResponse.json(
            {
              error:
                "Unable to complete the approval.",
            },
            { status: 500 },
          );
        }

        return NextResponse.json({
          success: true,
          message:
            "The member was already connected to this organization.",
        });
      }

      /*
       * IMPORTANT:
       *
       * Approved members become STAFF.
       * They are NOT primary.
       */

      const {
        error: staffInsertError,
      } = await admin
        .from("organization_staff")
        .insert({
          organization_id:
            membership.organization_id,
          user_id:
            joinRequest.user_id,
          is_primary: false,
        });

      if (staffInsertError) {
        console.error(
          "STAFF INSERT ERROR:",
          staffInsertError,
        );

        return NextResponse.json(
          {
            error:
              "Unable to add the member to the organization.",
          },
          { status: 500 },
        );
      }

      /*
       * ------------------------------------------------
       * Mark request approved.
       * ------------------------------------------------
       */

      const {
        error: approvalUpdateError,
      } = await admin
        .from(
          "organization_join_requests",
        )
        .update({
          status: "APPROVED",
          reviewed_at:
            new Date().toISOString(),
          reviewed_by: user.id,
        })
        .eq("id", requestId)
        .eq(
          "status",
          "PENDING",
        );

      if (approvalUpdateError) {
        /*
         * Roll back membership if request
         * could not be marked approved.
         */

        await admin
          .from("organization_staff")
          .delete()
          .eq(
            "organization_id",
            membership.organization_id,
          )
          .eq(
            "user_id",
            joinRequest.user_id,
          )
          .eq(
            "is_primary",
            false,
          );

        console.error(
          "APPROVAL UPDATE ERROR:",
          approvalUpdateError,
        );

        return NextResponse.json(
          {
            error:
              "Unable to complete the approval.",
          },
          { status: 500 },
        );
      }

      /*
       * ------------------------------------------------
       * Notify approved member
       * ------------------------------------------------
       *
       * At this point:
       *
       * 1. organization_staff exists
       * 2. join request is APPROVED
       *
       * Therefore the notification is only sent after
       * the member actually has organization access.
       */

      const {
        error: notificationError,
      } = await admin
        .from("notifications")
        .insert({
          id: crypto.randomUUID(),
          user_id:
            joinRequest.user_id,
          title:
            "Organization access approved",
          message:
            `Your request to join ${organization.name} has been approved. ` +
            "You are now a member of the organization.",
          notification_type:
            "organization_member_approved",
          is_read: false,
          created_at:
            new Date().toISOString(),
        });

      /*
       * Notification failure must NOT undo the
       * successful membership approval.
       */

      if (notificationError) {
        console.error(
          "JOIN REQUEST APPROVAL NOTIFICATION ERROR:",
          notificationError,
        );
      }

      return NextResponse.json({
        success: true,
        message:
          "Member approved successfully.",
      });
    }

    /*
     * ------------------------------------------------
     * REJECT
     * ------------------------------------------------
     */

    const {
      error: rejectionError,
    } = await admin
      .from(
        "organization_join_requests",
      )
      .update({
        status: "REJECTED",
        reviewed_at:
          new Date().toISOString(),
        reviewed_by: user.id,
        rejection_reason:
          typeof body?.reason ===
          "string"
            ? body.reason.trim() ||
              null
            : null,
      })
      .eq("id", requestId)
      .eq(
        "status",
        "PENDING",
      );

    if (rejectionError) {
      console.error(
        "REJECTION ERROR:",
        rejectionError,
      );

      return NextResponse.json(
        {
          error:
            "Unable to reject this request.",
        },
        { status: 500 },
      );
    }

    return NextResponse.json({
      success: true,
      message:
        "Join request rejected.",
    });
  } catch (error) {
    console.error(
      "JOIN REQUEST PATCH ERROR:",
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

