import { createClient } from "@/lib/supabase/server";

import type {
  OrganizationType,
  OrganizationVerificationStatus,
  WebRole,
} from "@/lib/auth/get-current-user";

export interface ProfileData {
  user: {
    id: string;
    email: string;
    fullName: string;
    role: WebRole;
  };

  organization: {
    id: string;
    name: string;
    organizationType: OrganizationType;
    registrationNumber: string | null;
    phone: string | null;
    email: string | null;
    address: string | null;
    latitude: number | null;
    longitude: number | null;
    verificationStatus: OrganizationVerificationStatus;
    verificationNotes: string | null;
    verifiedAt: string | null;
    createdAt: string;
    updatedAt: string;
  } | null;

  location: {
    city: string | null;
    province: string | null;
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
   VALID WEB ROLES
   ========================================================= */

const WEB_ROLES: readonly WebRole[] = [
  "HOSPITAL_ADMIN",
  "BLOOD_BANK_ADMIN",
  "STAFF",
  "GOVERNMENT_ADMIN",
  "SUPER_ADMIN",
];

/* =========================================================
   PROFILE DATA
   ========================================================= */

export async function getProfileData(
  userId: string,
): Promise<ProfileData | null> {
  const supabase = await createClient();

  if (!userId?.trim()) {
    return null;
  }

  /* =======================================================
     1. LOAD APPLICATION USER
     ======================================================= */

  const {
    data: user,
    error: userError,
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

  if (userError || !user) {
    console.error(
      "PROFILE - USER ERROR",
      userError,
    );

    return null;
  }

  if (!user.is_active) {
    console.error(
      "PROFILE - USER INACTIVE",
      {
        userId,
      },
    );

    return null;
  }

  if (!user.is_verified) {
    console.error(
      "PROFILE - USER NOT VERIFIED",
      {
        userId,
      },
    );

    return null;
  }

  /*
   * Supabase nested relations can be returned either
   * as an object or an array depending on the generated
   * relationship shape.
   *
   * Handle both safely.
   */

  const roleData = Array.isArray(user.roles)
    ? user.roles[0]
    : user.roles;

  const roleName =
    roleData?.name as WebRole | undefined;

  if (
    !roleName ||
    !WEB_ROLES.includes(roleName)
  ) {
    console.error(
      "PROFILE - INVALID ROLE",
      {
        userId,
        roleId: user.role_id,
        role: roleName,
      },
    );

    return null;
  }

  const profileUser = {
    id: user.id,
    email: user.email,
    fullName: user.full_name ?? "",
    role: roleName,
  };

  /* =======================================================
     2. GOVERNMENT / SUPER ADMIN
     ======================================================= */

  /*
   * Government administrators and Super Administrators
   * are platform-level accounts.
   *
   * They do NOT require organization_staff membership.
   *
   * This must match getCurrentUser().
   */

  const isPrivilegedRole =
    roleName === "GOVERNMENT_ADMIN" ||
    roleName === "SUPER_ADMIN";

  if (isPrivilegedRole) {
    return {
      user: profileUser,

      organization: null,

      location: null,

      hospital: null,

      bloodBank: null,
    };
  }

  /* =======================================================
     3. RESOLVE ORGANIZATION MEMBERSHIP
     ======================================================= */

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
      "PROFILE - MEMBERSHIP ERROR",
      membershipError,
    );

    return null;
  }

  if (!membership?.organization_id) {
    /*
     * Organization-level users without an assigned
     * organization can still have a valid account profile.
     *
     * This is particularly useful during onboarding.
     */

    return {
      user: profileUser,

      organization: null,

      location: null,

      hospital: null,

      bloodBank: null,
    };
  }

  const organizationId =
    membership.organization_id;

  /* =======================================================
     4. ORGANIZATION
     ======================================================= */

  const {
    data: organization,
    error: organizationError,
  } = await supabase
    .from("organizations")
    .select(`
      id,
      name,
      organization_type,
      registration_number,
      phone,
      email,
      address,
      latitude,
      longitude,
      verification_status,
      verification_notes,
      verified_at,
      created_at,
      updated_at,
      city_id
    `)
    .eq("id", organizationId)
    .is("deleted_at", null)
    .maybeSingle();

  if (organizationError || !organization) {
    console.error(
      "PROFILE - ORGANIZATION ERROR",
      organizationError,
      {
        organizationId,
        userId,
      },
    );

    return null;
  }

  /* =======================================================
     5. LOCATION
     ======================================================= */

  let cityName: string | null = null;
  let provinceName: string | null = null;

  if (organization.city_id) {
    const {
      data: city,
      error: cityError,
    } = await supabase
      .from("cities")
      .select(`
        id,
        name,
        province_id
      `)
      .eq("id", organization.city_id)
      .maybeSingle();

    if (cityError) {
      console.error(
        "PROFILE - CITY ERROR",
        cityError,
      );
    }

    if (city) {
      cityName = city.name ?? null;

      if (city.province_id) {
        const {
          data: province,
          error: provinceError,
        } = await supabase
          .from("provinces")
          .select("name")
          .eq("id", city.province_id)
          .maybeSingle();

        if (provinceError) {
          console.error(
            "PROFILE - PROVINCE ERROR",
            provinceError,
          );
        }

        if (province) {
          provinceName =
            province.name ?? null;
        }
      }
    }
  }

  /* =======================================================
     6. HOSPITAL DETAILS
     ======================================================= */

  let hospital:
    ProfileData["hospital"] = null;

  if (
    organization.organization_type ===
    "HOSPITAL"
  ) {
    const {
      data,
      error,
    } = await supabase
      .from("hospitals")
      .select(`
        hospital_type,
        license_number,
        emergency_service,
        blood_storage_available,
        total_beds,
        icu_available
      `)
      .eq(
        "organization_id",
        organizationId,
      )
      .is("deleted_at", null)
      .maybeSingle();

    if (error) {
      console.error(
        "PROFILE - HOSPITAL ERROR",
        error,
      );
    }

    if (data) {
      hospital = {
        hospitalType:
          data.hospital_type ?? null,

        licenseNumber:
          data.license_number ?? null,

        emergencyService:
          data.emergency_service,

        bloodStorageAvailable:
          data.blood_storage_available,

        totalBeds:
          data.total_beds ?? null,

        icuAvailable:
          data.icu_available,
      };
    }
  }

  /* =======================================================
     7. BLOOD BANK DETAILS
     ======================================================= */

  let bloodBank:
    ProfileData["bloodBank"] = null;

  if (
    organization.organization_type ===
    "BLOOD_BANK"
  ) {
    const {
      data,
      error,
    } = await supabase
      .from("blood_banks")
      .select(`
        license_number,
        storage_capacity,
        cold_storage_available,
        blood_processing_available,
        operating_hours
      `)
      .eq(
        "organization_id",
        organizationId,
      )
      .is("deleted_at", null)
      .maybeSingle();

    if (error) {
      console.error(
        "PROFILE - BLOOD BANK ERROR",
        error,
      );
    }

    if (data) {
      bloodBank = {
        licenseNumber:
          data.license_number ?? null,

        storageCapacity:
          data.storage_capacity ?? null,

        coldStorageAvailable:
          data.cold_storage_available,

        bloodProcessingAvailable:
          data.blood_processing_available,

        operatingHours:
          data.operating_hours ?? null,
      };
    }
  }

  /* =======================================================
     8. RETURN COMPLETE PROFILE
     ======================================================= */

  return {
    user: profileUser,

    organization: {
      id: organization.id,

      name: organization.name,

      organizationType:
        organization.organization_type,

      registrationNumber:
        organization.registration_number ??
        null,

      phone:
        organization.phone ?? null,

      email:
        organization.email ?? null,

      address:
        organization.address ?? null,

      latitude:
        organization.latitude ?? null,

      longitude:
        organization.longitude ?? null,

      verificationStatus:
        organization.verification_status,

      verificationNotes:
        organization.verification_notes ??
        null,

      verifiedAt:
        organization.verified_at ?? null,

      createdAt:
        organization.created_at,

      updatedAt:
        organization.updated_at,
    },

    location: {
      city: cityName,
      province: provinceName,
    },

    hospital,

    bloodBank,
  };
}