import { NextResponse } from "next/server";

import { createClient } from "@supabase/supabase-js";

import { createClient as createServerClient } from "@/lib/supabase/server";

import { randomUUID } from "crypto";

/*
 * ============================================================
 * RATE LIMITING
 * ============================================================
 */

const rateLimitMap = new Map<
  string,
  {
    count: number;
    resetAt: number;
  }
>();

const RATE_LIMIT_WINDOW_MS =
  15 * 60 * 1000;

const RATE_LIMIT_MAX_REQUESTS = 5;

function isRateLimited(
  ip: string,
): boolean {
  const now = Date.now();

  const entry =
    rateLimitMap.get(ip);

  if (
    !entry ||
    now > entry.resetAt
  ) {
    rateLimitMap.set(ip, {
      count: 1,
      resetAt:
        now +
        RATE_LIMIT_WINDOW_MS,
    });

    return false;
  }

  entry.count += 1;

  return (
    entry.count >
    RATE_LIMIT_MAX_REQUESTS
  );
}

setInterval(() => {
  const now = Date.now();

  for (
    const [key, value] of rateLimitMap
  ) {
    if (now > value.resetAt) {
      rateLimitMap.delete(key);
    }
  }
}, 60 * 1000);

/*
 * ============================================================
 * EMAIL VALIDATION
 * ============================================================
 */

const EMAIL_REGEX =
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function isValidEmail(
  email: string,
): boolean {
  return EMAIL_REGEX.test(email);
}

/*
 * ============================================================
 * TYPES
 * ============================================================
 */

type OrganizationType =
  | "HOSPITAL"
  | "BLOOD_BANK";

type RegistrationBody = {
  /*
   * organizationType is treated only as a requested UI value.
   * The server derives the real type from the authenticated
   * user's application role.
   */
  organizationType: OrganizationType;

  organizationName: string;
  registrationNumber: string;
  phone: string;
  email?: string;

  provinceId: string;
  cityId: string;
  address: string;

  latitude?: string;
  longitude?: string;

  hospitalType?: string;
  hospitalLicenseNumber?: string;
  emergencyService?: boolean;
  bloodStorageAvailable?: boolean;
  totalBeds?: string;
  icuAvailable?: boolean;

  licenseNumber?: string;
  storageCapacity?: string;
  coldStorageAvailable?: boolean;
  bloodProcessingAvailable?: boolean;
  operatingHours?: string;
};

/*
 * ============================================================
 * SERVER-ONLY ADMIN CLIENT
 * ============================================================
 */

function createAdminClient() {
  const supabaseUrl =
    process.env
      .NEXT_PUBLIC_SUPABASE_URL;

  const serviceRoleKey =
    process.env
      .SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl) {
    throw new Error(
      "NEXT_PUBLIC_SUPABASE_URL is not configured.",
    );
  }

  if (!serviceRoleKey) {
    throw new Error(
      "SUPABASE_SERVICE_ROLE_KEY is not configured.",
    );
  }

  return createClient(
    supabaseUrl,
    serviceRoleKey,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );
}

/*
 * ============================================================
 * HELPERS
 * ============================================================
 */

function isValidOrganizationType(
  value: unknown,
): value is OrganizationType {
  return (
    value === "HOSPITAL" ||
    value === "BLOOD_BANK"
  );
}

function parseOptionalNumber(
  value: unknown,
): number | null {
  if (
    value === undefined ||
    value === null ||
    value === ""
  ) {
    return null;
  }

  const parsed = Number(value);

  if (!Number.isFinite(parsed)) {
    return null;
  }

  return parsed;
}

function isValidLatitude(
  value: number | null,
): boolean {
  return (
    value === null ||
    (value >= -90 &&
      value <= 90)
  );
}

function isValidLongitude(
  value: number | null,
): boolean {
  return (
    value === null ||
    (value >= -180 &&
      value <= 180)
  );
}

/*
 * ============================================================
 * POST /api/organizations/register
 *
 * IMPORTANT:
 *
 * This endpoint NO LONGER creates an Auth user.
 *
 * The authenticated browser session identifies the existing
 * user. That existing user's auth.uid() becomes the primary
 * organization administrator.
 * ============================================================
 */

export async function POST(
  request: Request,
) {
  /*
   * ----------------------------------------------------------
   * RATE LIMIT
   * ----------------------------------------------------------
   */

  const forwardedFor =
    request.headers.get(
      "x-forwarded-for",
    );

  const ip =
    forwardedFor
      ?.split(",")[0]
      ?.trim() ||
    request.headers.get(
      "x-real-ip",
    ) ||
    "unknown";

  if (isRateLimited(ip)) {
    console.warn(
      `RATE LIMIT EXCEEDED for IP: ${ip}`,
    );

    return NextResponse.json(
      {
        error:
          "Too many registration attempts. Please try again later.",
      },
      {
        status: 429,
      },
    );
  }

  let createdOrganizationId:
    | string
    | null = null;

  try {
    /*
     * ========================================================
     * 1. AUTHENTICATE EXISTING USER
     * ========================================================
     */

    const supabase =
      await createServerClient();

    const {
      data: {
        user,
      },
      error: authError,
    } =
      await supabase.auth.getUser();

    if (
      authError ||
      !user
    ) {
      return NextResponse.json(
        {
          error:
            "You must be signed in before registering an organization.",
        },
        {
          status: 401,
        },
      );
    }

    /*
     * Email must already be verified.
     */

    if (!user.email_confirmed_at) {
      return NextResponse.json(
        {
          error:
            "Please verify your email address before registering an organization.",
        },
        {
          status: 403,
        },
      );
    }

    /*
     * ========================================================
     * 2. LOAD EXISTING APPLICATION USER
     * ========================================================
     */

    const admin =
      createAdminClient();

    const {
      data: profile,
      error: profileError,
    } =
      await admin
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
        .eq(
          "id",
          user.id,
        )
        .is(
          "deleted_at",
          null,
        )
        .maybeSingle();

    if (
      profileError
    ) {
      console.error(
        "APPLICATION USER LOOKUP ERROR",
        profileError,
      );

      return NextResponse.json(
        {
          error:
            "Unable to load your LifeLynk account.",
        },
        {
          status: 500,
        },
      );
    }

    if (!profile) {
      return NextResponse.json(
        {
          error:
            "Your LifeLynk application profile was not found.",
        },
        {
          status: 404,
        },
      );
    }

    if (!profile.is_active) {
      return NextResponse.json(
        {
          error:
            "Your LifeLynk account is inactive.",
        },
        {
          status: 403,
        },
      );
    }

    if (!profile.is_verified) {
      return NextResponse.json(
        {
          error:
            "Your LifeLynk account has not been verified.",
        },
        {
          status: 403,
        },
      );
    }

    const roleData =
      Array.isArray(profile.roles)
        ? profile.roles[0]
        : profile.roles;

    const role =
      roleData?.name;

    /*
     * ========================================================
     * 3. DERIVE ORGANIZATION TYPE FROM EXISTING ROLE
     * ========================================================
     *
     * SECURITY:
     *
     * The browser is NOT trusted to decide the user's
     * administrator role.
     *
     * HOSPITAL_ADMIN -> HOSPITAL
     * BLOOD_BANK_ADMIN -> BLOOD_BANK
     * ========================================================
     */

    let requiredType:
      | OrganizationType
      | null = null;

    if (
      role ===
      "HOSPITAL_ADMIN"
    ) {
      requiredType =
        "HOSPITAL";
    }

    if (
      role ===
      "BLOOD_BANK_ADMIN"
    ) {
      requiredType =
        "BLOOD_BANK";
    }

    if (!requiredType) {
      return NextResponse.json(
        {
          error:
            "Your account type is not permitted to create an organization through onboarding.",
        },
        {
          status: 403,
        },
      );
    }

    /*
     * ========================================================
     * 4. PARSE REQUEST
     * ========================================================
     */

    let body: RegistrationBody;

    try {
      body =
        await request.json();
    } catch {
      return NextResponse.json(
        {
          error:
            "Invalid registration request.",
        },
        {
          status: 400,
        },
      );
    }

    /*
     * ========================================================
     * 5. VALIDATE REQUESTED TYPE
     * ========================================================
     */

    if (
      !isValidOrganizationType(
        body.organizationType,
      )
    ) {
      return NextResponse.json(
        {
          error:
            "Invalid organization type.",
        },
        {
          status: 400,
        },
      );
    }

    /*
     * Client-selected type must agree with the authenticated
     * user's role.
     */

    if (
      body.organizationType !==
      requiredType
    ) {
      return NextResponse.json(
        {
          error:
            "The selected organization type does not match your account role.",
        },
        {
          status: 403,
        },
      );
    }

    /*
     * ========================================================
     * 6. NORMALIZE INPUT
     * ========================================================
     */

    const organizationName =
      String(
        body.organizationName ??
          "",
      ).trim();

    const registrationNumber =
      String(
        body.registrationNumber ??
          "",
      ).trim();

    const phone =
      String(
        body.phone ?? "",
      ).trim();

    const organizationEmail =
      String(
        body.email ?? "",
      )
        .trim()
        .toLowerCase();

    const provinceId =
      String(
        body.provinceId ?? "",
      ).trim();

    const cityId =
      String(
        body.cityId ?? "",
      ).trim();

    const address =
      String(
        body.address ?? "",
      ).trim();

    const latitude =
      parseOptionalNumber(
        body.latitude,
      );

    const longitude =
      parseOptionalNumber(
        body.longitude,
      );

    /*
     * ========================================================
     * 7. BASIC VALIDATION
     * ========================================================
     */

    if (!organizationName) {
      return NextResponse.json(
        {
          error:
            "Organization name is required.",
        },
        {
          status: 400,
        },
      );
    }

    if (!registrationNumber) {
      return NextResponse.json(
        {
          error:
            "Registration number is required.",
        },
        {
          status: 400,
        },
      );
    }

    if (!phone) {
      return NextResponse.json(
        {
          error:
            "Organization phone number is required.",
        },
        {
          status: 400,
        },
      );
    }

    if (!provinceId) {
      return NextResponse.json(
        {
          error:
            "Province is required.",
        },
        {
          status: 400,
        },
      );
    }

    if (!cityId) {
      return NextResponse.json(
        {
          error:
            "City is required.",
        },
        {
          status: 400,
        },
      );
    }

    if (!address) {
      return NextResponse.json(
        {
          error:
            "Organization address is required.",
        },
        {
          status: 400,
        },
      );
    }

    if (
      !organizationEmail ||
      !isValidEmail(
        organizationEmail,
      )
    ) {
      return NextResponse.json(
        {
          error:
            "Please provide a valid organization email address.",
        },
        {
          status: 400,
        },
      );
    }

    /*
     * ========================================================
     * 8. GPS VALIDATION
     * ========================================================
     */

    if (
      !isValidLatitude(
        latitude,
      ) ||
      !isValidLongitude(
        longitude,
      )
    ) {
      return NextResponse.json(
        {
          error:
            "Invalid organization GPS coordinates.",
        },
        {
          status: 400,
        },
      );
    }

    /*
     * ========================================================
     * 9. VERIFY PROVINCE
     * ========================================================
     */

    const {
      data: province,
      error: provinceError,
    } = await admin
      .from("provinces")
      .select(`
        id,
        name,
        is_active
      `)
      .eq(
        "id",
        provinceId,
      )
      .is(
        "deleted_at",
        null,
      )
      .maybeSingle();

    if (provinceError) {
      console.error(
        "PROVINCE LOOKUP ERROR",
        provinceError,
      );

      return NextResponse.json(
        {
          error:
            "Unable to verify the selected province.",
        },
        {
          status: 500,
        },
      );
    }

    if (
      !province ||
      !province.is_active
    ) {
      return NextResponse.json(
        {
          error:
            "The selected province is invalid or inactive.",
        },
        {
          status: 400,
        },
      );
    }

    /*
     * ========================================================
     * 10. VERIFY CITY
     * ========================================================
     */

    const {
      data: city,
      error: cityError,
    } = await admin
      .from("cities")
      .select(`
        id,
        name,
        province_id,
        is_active
      `)
      .eq(
        "id",
        cityId,
      )
      .eq(
        "province_id",
        provinceId,
      )
      .is(
        "deleted_at",
        null,
      )
      .maybeSingle();

    if (cityError) {
      console.error(
        "CITY LOOKUP ERROR",
        cityError,
      );

      return NextResponse.json(
        {
          error:
            "Unable to verify the selected city.",
        },
        {
          status: 500,
        },
      );
    }

    if (
      !city ||
      !city.is_active
    ) {
      return NextResponse.json(
        {
          error:
            "The selected city is invalid, inactive, or does not belong to the selected province.",
        },
        {
          status: 400,
        },
      );
    }

    /*
     * ========================================================
     * 11. PREVENT EXISTING ORGANIZATION MEMBERSHIP
     * ========================================================
     *
     * One primary organization is the onboarding model.
     * ========================================================
     */

    const {
      data: existingMembership,
      error:
        membershipError,
    } = await admin
      .from(
        "organization_staff",
      )
      .select("id")
      .eq(
        "user_id",
        user.id,
      )
      .is(
        "deleted_at",
        null,
      )
      .limit(1)
      .maybeSingle();

    if (membershipError) {
      console.error(
        "EXISTING MEMBERSHIP LOOKUP ERROR",
        membershipError,
      );

      return NextResponse.json(
        {
          error:
            "Unable to verify your organization assignment.",
        },
        {
          status: 500,
        },
      );
    }

    if (existingMembership) {
      return NextResponse.json(
        {
          code:
            "ALREADY_ASSIGNED",
          error:
            "Your account is already assigned to an organization.",
        },
        {
          status: 409,
        },
      );
    }

    /*
     * ========================================================
     * 12. CHECK ORGANIZATION REGISTRATION NUMBER
     * ========================================================
     */

    const {
      data: existingOrganization,
      error:
        existingOrganizationError,
    } = await admin
      .from(
        "organizations",
      )
      .select(`
        id,
        name,
        registration_number
      `)
      .eq(
        "registration_number",
        registrationNumber,
      )
      .is(
        "deleted_at",
        null,
      )
      .maybeSingle();

    if (
      existingOrganizationError
    ) {
      console.error(
        "DUPLICATE ORGANIZATION LOOKUP ERROR",
        existingOrganizationError,
      );

      return NextResponse.json(
        {
          error:
            "Unable to verify organization registration number.",
        },
        {
          status: 500,
        },
      );
    }

    if (existingOrganization) {
      return NextResponse.json(
        {
          code:
            "ORGANIZATION_ALREADY_EXISTS",
          error:
            "An organization with this registration number already exists.",
        },
        {
          status: 409,
        },
      );
    }

    /*
     * ========================================================
     * 13. HOSPITAL-SPECIFIC VALIDATION
     * ========================================================
     */

    let hospitalType = "";
    let hospitalLicenseNumber =
      "";
    let totalBeds:
      | number
      | null = null;

    if (
      requiredType ===
      "HOSPITAL"
    ) {
      hospitalType =
        String(
          body.hospitalType ??
            "",
        ).trim();

      hospitalLicenseNumber =
        String(
          body.hospitalLicenseNumber ??
            "",
        ).trim();

      if (!hospitalType) {
        return NextResponse.json(
          {
            error:
              "Hospital type is required.",
          },
          {
            status: 400,
          },
        );
      }

      if (
        !hospitalLicenseNumber
      ) {
        return NextResponse.json(
          {
            error:
              "Hospital license number is required.",
          },
          {
            status: 400,
          },
        );
      }

      if (
        body.totalBeds ===
          undefined ||
        body.totalBeds === ""
      ) {
        return NextResponse.json(
          {
            error:
              "Total beds is required.",
          },
          {
            status: 400,
          },
        );
      }

      totalBeds = Number(
        body.totalBeds,
      );

      if (
        !Number.isInteger(
          totalBeds,
        ) ||
        totalBeds < 0
      ) {
        return NextResponse.json(
          {
            error:
              "Total beds must be a valid non-negative integer.",
          },
          {
            status: 400,
          },
        );
      }

      /*
       * Check duplicate hospital license.
       */

      const {
        data: existingHospital,
        error:
          hospitalLookupError,
      } = await admin
        .from("hospitals")
        .select("id")
        .eq(
          "license_number",
          hospitalLicenseNumber,
        )
        .limit(1)
        .maybeSingle();

      if (hospitalLookupError) {
        console.error(
          "HOSPITAL LICENSE LOOKUP ERROR",
          hospitalLookupError,
        );

        return NextResponse.json(
          {
            error:
              "Unable to verify the hospital license number.",
          },
          {
            status: 500,
          },
        );
      }

      if (existingHospital) {
        return NextResponse.json(
          {
            code:
              "HOSPITAL_LICENSE_ALREADY_EXISTS",
            error:
              "A hospital with this license number already exists.",
          },
          {
            status: 409,
          },
        );
      }
    }

    /*
     * ========================================================
     * 14. BLOOD BANK-SPECIFIC VALIDATION
     * ========================================================
     */

    let licenseNumber = "";
    let storageCapacity:
      | number
      | null = null;

    if (
      requiredType ===
      "BLOOD_BANK"
    ) {
      licenseNumber =
        String(
          body.licenseNumber ??
            "",
        ).trim();

      if (!licenseNumber) {
        return NextResponse.json(
          {
            error:
              "Blood bank license number is required.",
          },
          {
            status: 400,
          },
        );
      }

      if (
        body.storageCapacity ===
          undefined ||
        body.storageCapacity ===
          ""
      ) {
        return NextResponse.json(
          {
            error:
              "Storage capacity is required.",
          },
          {
            status: 400,
          },
        );
      }

      storageCapacity =
        Number(
          body.storageCapacity,
        );

      if (
        !Number.isInteger(
          storageCapacity,
        ) ||
        storageCapacity < 0
      ) {
        return NextResponse.json(
          {
            error:
              "Storage capacity must be a valid non-negative integer.",
          },
          {
            status: 400,
          },
        );
      }

      /*
       * Check duplicate blood-bank license.
       */

      const {
        data: existingBloodBank,
        error:
          bloodBankLookupError,
      } = await admin
        .from(
          "blood_banks",
        )
        .select("id")
        .eq(
          "license_number",
          licenseNumber,
        )
        .limit(1)
        .maybeSingle();

      if (bloodBankLookupError) {
        console.error(
          "BLOOD BANK LICENSE LOOKUP ERROR",
          bloodBankLookupError,
        );

        return NextResponse.json(
          {
            error:
              "Unable to verify the blood bank license number.",
          },
          {
            status: 500,
          },
        );
      }

      if (existingBloodBank) {
        return NextResponse.json(
          {
            code:
              "BLOOD_BANK_LICENSE_ALREADY_EXISTS",
            error:
              "A blood bank with this license number already exists.",
          },
          {
            status: 409,
          },
        );
      }
    }

    /*
     * ========================================================
     * 15. CREATE ORGANIZATION
     * ========================================================
     *
     * IMPORTANT:
     *
     * This creates ONLY the organization.
     * It does NOT create an Auth account.
     *
     * The organization is PENDING until verified.
     * ========================================================
     */

    const {
      data: organization,
      error:
        organizationError,
    } = await admin
      .from(
        "organizations",
      )
      .insert({
        city_id:
          cityId,

        organization_type:
          requiredType,

        name:
          organizationName,

        registration_number:
          registrationNumber,

        phone:
          phone,

        email:
          organizationEmail,

        address:
          address,

        latitude:
          latitude,

        longitude:
          longitude,

        verification_status:
          "PENDING",
      })
      .select(`
        id,
        name,
        organization_type,
        verification_status
      `)
      .single();

    if (
      organizationError
    ) {
      console.error(
        "ORGANIZATION INSERT ERROR",
        organizationError,
      );

      throw organizationError;
    }

    if (!organization) {
      throw new Error(
        "Organization was not created.",
      );
    }

    createdOrganizationId =
      organization.id;

    /*
     * ========================================================
     * 16. CREATE HOSPITAL
     * ========================================================
     */

    if (
      requiredType ===
      "HOSPITAL"
    ) {
      const {
        error:
          hospitalError,
      } = await admin
        .from("hospitals")
        .insert({
          id:
            randomUUID(),

          organization_id:
            organization.id,

          hospital_type:
            hospitalType,

          license_number:
            hospitalLicenseNumber,

          emergency_service:
            body.emergencyService ??
            true,

          blood_storage_available:
            body.bloodStorageAvailable ??
            true,

          total_beds:
            totalBeds,

          icu_available:
            body.icuAvailable ??
            true,
        });

      if (hospitalError) {
        console.error(
          "HOSPITAL INSERT ERROR",
          hospitalError,
        );

        throw hospitalError;
      }
    }

    /*
     * ========================================================
     * 17. CREATE BLOOD BANK
     * ========================================================
     */

    if (
      requiredType ===
      "BLOOD_BANK"
    ) {
      const {
        error:
          bloodBankError,
      } = await admin
        .from(
          "blood_banks",
        )
        .insert({
          id:
            randomUUID(),

          organization_id:
            organization.id,

          license_number:
            licenseNumber,

          storage_capacity:
            storageCapacity,

          cold_storage_available:
            body.coldStorageAvailable ??
            true,

          blood_processing_available:
            body.bloodProcessingAvailable ??
            true,

          operating_hours:
            String(
              body.operatingHours ??
                "",
            ).trim() ||
            null,
        });

      if (bloodBankError) {
        console.error(
          "BLOOD BANK INSERT ERROR",
          bloodBankError,
        );

        throw bloodBankError;
      }
    }

    /*
     * ========================================================
     * 18. CREATE PRIMARY STAFF USING EXISTING AUTH USER
     * ========================================================
     *
     * THIS IS THE CORE FIX.
     *
     * user.id is the ID of the account that already exists.
     *
     * NO createUser()
     * NO signUp()
     * NO password
     * NO second email
     * ========================================================
     */

    const {
      error:
        staffError,
    } = await admin
      .from(
        "organization_staff",
      )
      .insert({
        organization_id:
          organization.id,

        user_id:
          user.id,

        is_primary:
          true,
      });

    if (staffError) {
      console.error(
        "ORGANIZATION STAFF INSERT ERROR",
        staffError,
      );

      throw staffError;
    }

    /*
     * ========================================================
     * 19. SUCCESS
     * ========================================================
     */

    return NextResponse.json(
      {
        success: true,

        message:
          "Organization registration submitted successfully.",

        organization: {
          id:
            organization.id,

          name:
            organization.name,

          type:
            organization.organization_type,

          verificationStatus:
            organization.verification_status,
        },

        user: {
          id:
            user.id,

          email:
            user.email,

          role,
        },
      },
      {
        status: 201,
      },
    );
  } catch (
    error: unknown
  ) {
    /*
     * ========================================================
     * CLEANUP
     * ========================================================
     *
     * Since the Auth account already existed before this
     * request, we NEVER delete the Auth user.
     *
     * We only clean up organization-related records created
     * by this request.
     * ========================================================
     */

    console.error(
      "ORGANIZATION ONBOARDING FAILED",
      error,
    );

    if (
      createdOrganizationId
    ) {
      await createAdminClient()
        .from(
          "hospitals",
        )
        .delete()
        .eq(
          "organization_id",
          createdOrganizationId,
        );

      await createAdminClient()
        .from(
          "blood_banks",
        )
        .delete()
        .eq(
          "organization_id",
          createdOrganizationId,
        );

      await createAdminClient()
        .from(
          "organization_staff",
        )
        .delete()
        .eq(
          "organization_id",
          createdOrganizationId,
        );

      await createAdminClient()
        .from(
          "organizations",
        )
        .delete()
        .eq(
          "id",
          createdOrganizationId,
        );
    }

    /*
     * ========================================================
     * FRIENDLY ERROR HANDLING
     * ========================================================
     */

    const rawMessage =
      error instanceof Error
        ? error.message
        : "";

    const lowerMessage =
      rawMessage.toLowerCase();

    /*
     * Duplicate organization registration number
     */

    if (
      lowerMessage.includes(
        "organizations_registration_number_key",
      ) ||
      lowerMessage.includes(
        "uq_organizations_registration_number",
      )
    ) {
      return NextResponse.json(
        {
          code:
            "ORGANIZATION_ALREADY_EXISTS",

          error:
            "An organization with this registration number already exists.",
        },
        {
          status: 409,
        },
      );
    }

    /*
     * Duplicate hospital license
     */

    if (
      lowerMessage.includes(
        "hospitals_license_number_key",
      ) ||
      lowerMessage.includes(
        "uq_hospitals_license_number",
      )
    ) {
      return NextResponse.json(
        {
          code:
            "HOSPITAL_LICENSE_ALREADY_EXISTS",

          error:
            "A hospital with this license number already exists.",
        },
        {
          status: 409,
        },
      );
    }

    /*
     * Duplicate blood-bank license
     */

    if (
      lowerMessage.includes(
        "blood_banks_license_number_key",
      ) ||
      lowerMessage.includes(
        "uq_blood_banks_license_number",
      )
    ) {
      return NextResponse.json(
        {
          code:
            "BLOOD_BANK_LICENSE_ALREADY_EXISTS",

          error:
            "A blood bank with this license number already exists.",
        },
        {
          status: 409,
        },
      );
    }

    /*
     * Duplicate hospital organization relation
     */

    if (
      lowerMessage.includes(
        "uq_hospitals_organization_id",
      )
    ) {
      return NextResponse.json(
        {
          code:
            "HOSPITAL_ALREADY_EXISTS",

          error:
            "This organization already has a hospital record.",
        },
        {
          status: 409,
        },
      );
    }

    /*
     * Duplicate blood-bank organization relation
     */

    if (
      lowerMessage.includes(
        "uq_blood_banks_organization_id",
      )
    ) {
      return NextResponse.json(
        {
          code:
            "BLOOD_BANK_ALREADY_EXISTS",

          error:
            "This organization already has a blood bank record.",
        },
        {
          status: 409,
        },
      );
    }

    /*
     * Catch-all.
     */

    if (
      process.env.NODE_ENV !==
      "production"
    ) {
      console.error(
        "UNHANDLED ORGANIZATION ONBOARDING ERROR:",
        rawMessage,
      );
    }

    return NextResponse.json(
      {
        error:
          "An unexpected error occurred while registering the organization. Please try again or contact support.",
      },
      {
        status: 500,
      },
    );
  }
}