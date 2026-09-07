"use server";

import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";

/* =========================================================
   TYPES
   ========================================================= */

interface UpdateMyProfileInput {
  fullName: string;
  email: string;

  organization: {
    name: string;
    phone: string | null;
    email: string | null;
    address: string | null;
  } | null;

  hospital: {
    hospitalType: string | null;
    licenseNumber: string | null;
    emergencyService: boolean;
    bloodStorageAvailable: boolean;
    totalBeds: number | null;
    icuAvailable: boolean;
  } | null;

  bloodBank: {
    licenseNumber: string | null;
    storageCapacity: number | null;
    coldStorageAvailable: boolean;
    bloodProcessingAvailable: boolean;
    operatingHours: string | null;
  } | null;
}

/* =========================================================
   UPDATE MY PROFILE
   ========================================================= */

export async function updateMyProfile(
  input: UpdateMyProfileInput,
): Promise<{
  success: boolean;
  error?: string;
}> {
  try {
    /*
     * ---------------------------------------------------------
     * 1. Verify authenticated user
     * ---------------------------------------------------------
     */

    const supabase = await createClient();

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return {
        success: false,
        error: "You are not authenticated.",
      };
    }

    const userId = user.id;

    /*
     * ---------------------------------------------------------
     * 2. Validate basic account information
     * ---------------------------------------------------------
     */

    const fullName =
      input.fullName?.trim();

    const email =
      input.email?.trim().toLowerCase();

    if (!fullName) {
      return {
        success: false,
        error: "Full name is required.",
      };
    }

    if (!email) {
      return {
        success: false,
        error: "Email address is required.",
      };
    }

    /*
     * Basic email validation.
     */

    const emailPattern =
      /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (!emailPattern.test(email)) {
      return {
        success: false,
        error:
          "Please enter a valid email address.",
      };
    }

    /*
     * ---------------------------------------------------------
     * 3. Load current application user
     * ---------------------------------------------------------
     *
     * We determine the user's actual role from the database.
     * The browser is never trusted for authorization.
     */

    const {
      data: profile,
      error: profileError,
    } = await supabase
      .from("users")
      .select(`
        id,
        email,
        full_name,
        role_id,
        is_active,
        is_verified,
        roles (
          id,
          name
        )
      `)
      .eq("id", userId)
      .is("deleted_at", null)
      .maybeSingle();

    if (profileError || !profile) {
      console.error(
        "PROFILE UPDATE - USER ERROR",
        profileError,
      );

      return {
        success: false,
        error:
          "Your LifeLynk account could not be found.",
      };
    }

    if (!profile.is_active) {
      return {
        success: false,
        error:
          "Your LifeLynk account is inactive.",
      };
    }

    /*
     * Resolve the nested role safely.
     */

    const roleData = Array.isArray(
      profile.roles,
    )
      ? profile.roles[0]
      : profile.roles;

    const roleName =
      roleData?.name;

    const allowedRoles = [
      "HOSPITAL_ADMIN",
      "BLOOD_BANK_ADMIN",
      "STAFF",
      "GOVERNMENT_ADMIN",
      "SUPER_ADMIN",
    ];

    if (
      !roleName ||
      !allowedRoles.includes(
        roleName,
      )
    ) {
      return {
        success: false,
        error:
          "Your account role is not authorized to update profile information.",
      };
    }

    /*
     * ---------------------------------------------------------
     * 4. Get organization membership
     * ---------------------------------------------------------
     */

    const {
      data: membership,
      error: membershipError,
    } = await supabase
      .from("organization_staff")
      .select(`
        organization_id,
        is_primary
      `)
      .eq("user_id", userId)
      .is("deleted_at", null)
      .order("is_primary", {
        ascending: false,
      })
      .limit(1)
      .maybeSingle();

    if (membershipError) {
      console.error(
        "PROFILE UPDATE - MEMBERSHIP ERROR",
        membershipError,
      );

      return {
        success: false,
        error:
          "Your organization membership could not be verified.",
      };
    }

    const organizationId =
      membership?.organization_id ??
      null;

    /*
     * ---------------------------------------------------------
     * 5. Create admin client
     * ---------------------------------------------------------
     *
     * The service-role key is used only on the server.
     * It is NEVER sent to the browser.
     */

    const admin = createAdminClient();

    /*
     * ---------------------------------------------------------
     * 6. Update application user
     * ---------------------------------------------------------
     */

    const { error: userUpdateError } =
      await admin
        .from("users")
        .update({
          full_name: fullName,
          email,
        })
        .eq("id", userId);

    if (userUpdateError) {
      console.error(
        "PROFILE UPDATE - USER UPDATE ERROR",
        userUpdateError,
      );

      return {
        success: false,
        error:
          "Your personal account information could not be updated.",
      };
    }

    /*
     * ---------------------------------------------------------
     * 7. Update Supabase Auth email
     * ---------------------------------------------------------
     *
     * Only update Auth if the email actually changed.
     *
     * Supabase may require email confirmation depending on
     * the project's authentication settings.
     */

    const currentAuthEmail =
      user.email
        ?.trim()
        .toLowerCase();

    if (
      currentAuthEmail !== email
    ) {
      const {
        error: authUpdateError,
      } =
        await admin.auth.admin.updateUserById(
          userId,
          {
            email,
          },
        );

      if (authUpdateError) {
        console.error(
          "PROFILE UPDATE - AUTH EMAIL ERROR",
          authUpdateError,
        );

        /*
         * Roll back the public users email so the two
         * account records do not remain inconsistent.
         */

        await admin
          .from("users")
          .update({
            email:
              user.email,
          })
          .eq("id", userId);

        return {
          success: false,
          error:
            authUpdateError.message ||
            "Your email address could not be updated.",
        };
      }
    }

    /*
     * ---------------------------------------------------------
     * 8. Government / Super Admin
     * ---------------------------------------------------------
     *
     * These accounts are not organization members.
     * Their personal account update is already complete.
     */

    const isPrivilegedRole =
      roleName === "GOVERNMENT_ADMIN" ||
      roleName === "SUPER_ADMIN";

    if (
      isPrivilegedRole ||
      !organizationId
    ) {
      return {
        success: true,
      };
    }

    /*
     * ---------------------------------------------------------
     * 9. Verify organization exists
     * ---------------------------------------------------------
     */

    const {
      data: organization,
      error: organizationError,
    } =
      await admin
        .from("organizations")
        .select(`
          id,
          organization_type,
          verification_status
        `)
        .eq(
          "id",
          organizationId,
        )
        .is("deleted_at", null)
        .maybeSingle();

    if (
      organizationError ||
      !organization
    ) {
      console.error(
        "PROFILE UPDATE - ORGANIZATION ERROR",
        organizationError,
      );

      return {
        success: false,
        error:
          "Your organization could not be found.",
      };
    }

    /*
     * ---------------------------------------------------------
     * 10. Update organization information
     * ---------------------------------------------------------
     *
     * Registration number and verification fields are
     * intentionally NOT updated here.
     *
     * Government controls verification.
     */

    if (input.organization) {
      const organizationName =
        input.organization.name?.trim();

      if (!organizationName) {
        return {
          success: false,
          error:
            "Organization name is required.",
        };
      }

      const { error: updateOrganizationError } =
        await admin
          .from("organizations")
          .update({
            name: organizationName,

            phone:
              input.organization.phone
                ?.trim() || null,

            email:
              input.organization.email
                ?.trim()
                .toLowerCase() || null,

            address:
              input.organization.address
                ?.trim() || null,
          })
          .eq(
            "id",
            organizationId,
          );

      if (updateOrganizationError) {
        console.error(
          "PROFILE UPDATE - ORGANIZATION UPDATE ERROR",
          updateOrganizationError,
        );

        return {
          success: false,
          error:
            "Organization information could not be updated.",
        };
      }
    }

    /*
     * ---------------------------------------------------------
     * 11. Update hospital information
     * ---------------------------------------------------------
     */

    if (
      organization.organization_type ===
        "HOSPITAL" &&
      input.hospital
    ) {
      const hospitalType =
        input.hospital.hospitalType
          ?.trim() || null;

      const licenseNumber =
        input.hospital.licenseNumber
          ?.trim() || null;

      const totalBeds =
        input.hospital.totalBeds;

      if (
        totalBeds !== null &&
        (!Number.isInteger(
          totalBeds,
        ) ||
          totalBeds < 0)
      ) {
        return {
          success: false,
          error:
            "Total beds must be a valid non-negative whole number.",
        };
      }

      const {
        data: hospital,
        error: hospitalLookupError,
      } =
        await admin
          .from("hospitals")
          .select("id")
          .eq(
            "organization_id",
            organizationId,
          )
          .is("deleted_at", null)
          .maybeSingle();

      if (hospitalLookupError) {
        console.error(
          "PROFILE UPDATE - HOSPITAL LOOKUP ERROR",
          hospitalLookupError,
        );

        return {
          success: false,
          error:
            "Hospital information could not be loaded.",
        };
      }

      if (hospital) {
        const {
          error: hospitalUpdateError,
        } =
          await admin
            .from("hospitals")
            .update({
              hospital_type:
                hospitalType,

              license_number:
                licenseNumber,

              emergency_service:
                Boolean(
                  input.hospital
                    .emergencyService,
                ),

              blood_storage_available:
                Boolean(
                  input.hospital
                    .bloodStorageAvailable,
                ),

              total_beds:
                totalBeds,

              icu_available:
                Boolean(
                  input.hospital
                    .icuAvailable,
                ),
            })
            .eq(
              "id",
              hospital.id,
            );

        if (hospitalUpdateError) {
          console.error(
            "PROFILE UPDATE - HOSPITAL UPDATE ERROR",
            hospitalUpdateError,
          );

          return {
            success: false,
            error:
              "Hospital information could not be updated.",
          };
        }
      } else {
        /*
         * If the hospital child record does not exist,
         * create it so incomplete organization registrations
         * can still have their missing profile information
         * completed.
         */

        const {
          error: hospitalInsertError,
        } =
          await admin
            .from("hospitals")
            .insert({
              organization_id:
                organizationId,

              hospital_type:
                hospitalType,

              license_number:
                licenseNumber,

              emergency_service:
                Boolean(
                  input.hospital
                    .emergencyService,
                ),

              blood_storage_available:
                Boolean(
                  input.hospital
                    .bloodStorageAvailable,
                ),

              total_beds:
                totalBeds,

              icu_available:
                Boolean(
                  input.hospital
                    .icuAvailable,
                ),
            });

        if (hospitalInsertError) {
          console.error(
            "PROFILE UPDATE - HOSPITAL INSERT ERROR",
            hospitalInsertError,
          );

          return {
            success: false,
            error:
              "Hospital information could not be created.",
          };
        }
      }
    }

    /*
     * ---------------------------------------------------------
     * 12. Update blood bank information
     * ---------------------------------------------------------
     */

    if (
      organization.organization_type ===
        "BLOOD_BANK" &&
      input.bloodBank
    ) {
      const licenseNumber =
        input.bloodBank.licenseNumber
          ?.trim() || null;

      const storageCapacity =
        input.bloodBank
          .storageCapacity;

      if (
        storageCapacity !== null &&
        (typeof storageCapacity !==
          "number" ||
          Number.isNaN(
            storageCapacity,
          ) ||
          storageCapacity < 0)
      ) {
        return {
          success: false,
          error:
            "Storage capacity must be a valid non-negative number.",
        };
      }

      const {
        data: bloodBank,
        error: bloodBankLookupError,
      } =
        await admin
          .from("blood_banks")
          .select("id")
          .eq(
            "organization_id",
            organizationId,
          )
          .is("deleted_at", null)
          .maybeSingle();

      if (bloodBankLookupError) {
        console.error(
          "PROFILE UPDATE - BLOOD BANK LOOKUP ERROR",
          bloodBankLookupError,
        );

        return {
          success: false,
          error:
            "Blood bank information could not be loaded.",
        };
      }

      if (bloodBank) {
        const {
          error: bloodBankUpdateError,
        } =
          await admin
            .from("blood_banks")
            .update({
              license_number:
                licenseNumber,

              storage_capacity:
                storageCapacity,

              cold_storage_available:
                Boolean(
                  input.bloodBank
                    .coldStorageAvailable,
                ),

              blood_processing_available:
                Boolean(
                  input.bloodBank
                    .bloodProcessingAvailable,
                ),

              operating_hours:
                input.bloodBank
                  .operatingHours
                  ?.trim() || null,
            })
            .eq(
              "id",
              bloodBank.id,
            );

        if (bloodBankUpdateError) {
          console.error(
            "PROFILE UPDATE - BLOOD BANK UPDATE ERROR",
            bloodBankUpdateError,
          );

          return {
            success: false,
            error:
              "Blood bank information could not be updated.",
          };
        }
      } else {
        /*
         * Create the child record if it does not exist.
         */

        const {
          error: bloodBankInsertError,
        } =
          await admin
            .from("blood_banks")
            .insert({
              organization_id:
                organizationId,

              license_number:
                licenseNumber,

              storage_capacity:
                storageCapacity,

              cold_storage_available:
                Boolean(
                  input.bloodBank
                    .coldStorageAvailable,
                ),

              blood_processing_available:
                Boolean(
                  input.bloodBank
                    .bloodProcessingAvailable,
                ),

              operating_hours:
                input.bloodBank
                  .operatingHours
                  ?.trim() || null,
            });

        if (bloodBankInsertError) {
          console.error(
            "PROFILE UPDATE - BLOOD BANK INSERT ERROR",
            bloodBankInsertError,
          );

          return {
            success: false,
            error:
              "Blood bank information could not be created.",
          };
        }
      }
    }

    /*
     * ---------------------------------------------------------
     * 13. Success
     * ---------------------------------------------------------
     */

    return {
      success: true,
    };
  } catch (error) {
    console.error(
      "Unexpected profile update error:",
      error,
    );

    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : "An unexpected error occurred while updating your profile.",
    };
  }
}

/* =========================================================
   DELETE MY ACCOUNT
   ========================================================= */

export async function deleteMyAccount(): Promise<{
  success: boolean;
  error?: string;
}> {
  try {
    /*
     * ---------------------------------------------------------
     * 1. Verify the current authenticated user
     * ---------------------------------------------------------
     */

    const supabase = await createClient();

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return {
        success: false,
        error: "You are not authenticated.",
      };
    }

    const userId = user.id;

    /*
     * ---------------------------------------------------------
     * 2. Use the server-side Supabase Admin client
     * ---------------------------------------------------------
     *
     * The service-role key is NEVER exposed to the browser.
     */

    const admin = createAdminClient();

    /*
     * ---------------------------------------------------------
     * 3. Remove data that belongs exclusively to the account
     * ---------------------------------------------------------
     *
     * Most of these tables already use ON DELETE CASCADE.
     *
     * Blood requests are intentionally preserved as historical
     * healthcare records. Their requester_id is cleared by the
     * database's ON DELETE SET NULL constraint.
     */

    const { error: bloodRequestError } =
      await admin
        .from("blood_requests")
        .update({
          requester_id: null,
        })
        .eq(
          "requester_id",
          userId,
        );

    if (bloodRequestError) {
      console.error(
        "Failed to detach blood requests:",
        bloodRequestError,
      );

      return {
        success: false,
        error:
          "Your historical blood request records could not be detached from this account.",
      };
    }

    /*
     * ---------------------------------------------------------
     * 4. Remove other restrictive references if they exist
     * ---------------------------------------------------------
     *
     * Donor records use a restrictive relationship in the current
     * database. We do not silently delete donor history.
     *
     * If this account is a donor, remove the account's active
     * donor relationship before deleting the auth account.
     */

    const { error: donorError } =
      await admin
        .from("donors")
        .delete()
        .eq(
          "user_id",
          userId,
        );

    if (donorError) {
      console.error(
        "Failed to remove donor record:",
        donorError,
      );

      return {
        success: false,
        error:
          "Your donor profile could not be removed. The account was not deleted.",
      };
    }

    /*
     * ---------------------------------------------------------
     * 5. Delete the Supabase Auth account
     * ---------------------------------------------------------
     *
     * This is a PERMANENT Auth deletion.
     *
     * Because public.users references auth.users, the database
     * relationship will handle the application-user row according
     * to its configured foreign-key behavior.
     */

    const {
      error: deleteAuthError,
    } =
      await admin.auth.admin.deleteUser(
        userId,
      );

    if (deleteAuthError) {
      console.error(
        "Failed to permanently delete Auth user:",
        deleteAuthError,
      );

      return {
        success: false,
        error:
          deleteAuthError.message ||
          "The account could not be permanently deleted.",
      };
    }

    /*
     * ---------------------------------------------------------
     * 6. Sign out the current browser session
     * ---------------------------------------------------------
     */

    await supabase.auth.signOut();

    return {
      success: true,
    };
  } catch (error) {
    console.error(
      "Unexpected account deletion error:",
      error,
    );

    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : "An unexpected error occurred while deleting your account.",
    };
  }
}