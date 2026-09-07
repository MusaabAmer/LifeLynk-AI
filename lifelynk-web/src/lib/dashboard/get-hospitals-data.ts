import { createClient } from "@/lib/supabase/server";
import type { WebRole } from "@/lib/auth/get-current-user";

/* =========================================================
   TYPES
   ========================================================= */

export type HealthcareFacilityType =
  | "HOSPITAL"
  | "BLOOD_BANK";

export interface FacilityOrganization {
  id: string;
  name: string;
  phone: string;
  email: string | null;
  address: string;
  organization_type: HealthcareFacilityType;
  verification_status: string;
  cities: {
    id: string;
    name: string;
    provinces: {
      id: string;
      name: string;
    };
  };
}

export interface HospitalWithDetails {
  id: string;
  organization_id: string;
  facility_type: "HOSPITAL";
  hospital_type: string;
  license_number: string;
  emergency_service: boolean;
  blood_storage_available: boolean;
  total_beds: number | null;
  icu_available: boolean;
  cold_storage_available: null;
  blood_processing_available: null;
  storage_capacity: null;
  operating_hours: null;
  created_at: string;
  organizations: FacilityOrganization;
}

export interface BloodBankWithDetails {
  id: string;
  organization_id: string;
  facility_type: "BLOOD_BANK";
  hospital_type: null;
  license_number: string;
  emergency_service: null;
  blood_storage_available: boolean;
  total_beds: null;
  icu_available: null;
  cold_storage_available: boolean;
  blood_processing_available: boolean;
  storage_capacity: number | null;
  operating_hours: string | null;
  created_at: string;
  organizations: FacilityOrganization;
}

export type HealthcareFacility =
  | HospitalWithDetails
  | BloodBankWithDetails;

/*
 * Backward-compatible alias.
 *
 * The page historically called these "hospitals".
 * The actual returned collection now contains both
 * hospitals and blood banks.
 */
export type HospitalFacility = HealthcareFacility;

export interface HospitalStats {
  totalHospitals: number;
  totalBloodBanks: number;
  totalFacilities: number;
  emergencyService: number;
  icuAvailable: number;
  bloodStorageAvailable: number;
}

export interface HospitalsData {
  hospitals: HealthcareFacility[];
  stats: HospitalStats;
  error: boolean;
}

/* =========================================================
   EMPTY PAYLOAD
   ========================================================= */

const EMPTY_STATS: HospitalStats = {
  totalHospitals: 0,
  totalBloodBanks: 0,
  totalFacilities: 0,
  emergencyService: 0,
  icuAvailable: 0,
  bloodStorageAvailable: 0,
};

/* =========================================================
   HELPERS
   ========================================================= */

function normalizeHospitalRow(
  row: Record<string, unknown>,
): HospitalWithDetails {
  return {
    id: String(row.id),
    organization_id: String(row.organization_id),
    facility_type: "HOSPITAL",

    hospital_type:
      typeof row.hospital_type === "string"
        ? row.hospital_type
        : "",

    license_number:
      typeof row.license_number === "string"
        ? row.license_number
        : "",

    emergency_service:
      Boolean(row.emergency_service),

    blood_storage_available:
      Boolean(row.blood_storage_available),

    total_beds:
      typeof row.total_beds === "number"
        ? row.total_beds
        : null,

    icu_available:
      Boolean(row.icu_available),

    cold_storage_available: null,
    blood_processing_available: null,
    storage_capacity: null,
    operating_hours: null,

    created_at:
      typeof row.created_at === "string"
        ? row.created_at
        : new Date().toISOString(),

    organizations:
      row.organizations as FacilityOrganization,
  };
}

function normalizeBloodBankRow(
  row: Record<string, unknown>,
): BloodBankWithDetails {
  const coldStorageAvailable =
    Boolean(row.cold_storage_available);

  const storageCapacity =
    typeof row.storage_capacity === "number"
      ? row.storage_capacity
      : null;

  /*
   * A blood bank is considered to have blood storage when
   * either cold storage is available or it has a positive
   * configured storage capacity.
   */
  const bloodStorageAvailable =
    coldStorageAvailable ||
    (storageCapacity !== null &&
      storageCapacity > 0);

  return {
    id: String(row.id),
    organization_id: String(row.organization_id),
    facility_type: "BLOOD_BANK",

    hospital_type: null,

    license_number:
      typeof row.license_number === "string"
        ? row.license_number
        : "",

    emergency_service: null,

    blood_storage_available:
      bloodStorageAvailable,

    total_beds: null,
    icu_available: null,

    cold_storage_available:
      coldStorageAvailable,

    blood_processing_available:
      Boolean(row.blood_processing_available),

    storage_capacity: storageCapacity,

    operating_hours:
      typeof row.operating_hours === "string"
        ? row.operating_hours
        : null,

    created_at:
      typeof row.created_at === "string"
        ? row.created_at
        : new Date().toISOString(),

    organizations:
      row.organizations as FacilityOrganization,
  };
}

/* =========================================================
   DATA FETCHER
   ========================================================= */

export async function getHospitalsData(
  role: WebRole,
  organizationId: string | null,
): Promise<HospitalsData> {
  const supabase = await createClient();

  /*
   * --------------------------------------------------
   * 1. Hospitals
   * --------------------------------------------------
   */

  let hospitalsQuery = supabase
    .from("hospitals")
    .select(`
      id,
      organization_id,
      hospital_type,
      license_number,
      emergency_service,
      blood_storage_available,
      total_beds,
      icu_available,
      created_at,
      organizations!inner (
        id,
        name,
        phone,
        email,
        address,
        organization_type,
        verification_status,
        cities!inner (
          id,
          name,
          provinces!inner (
            id,
            name
          )
        )
      )
    `)
    .is("deleted_at", null)
    .eq("organizations.organization_type", "HOSPITAL");

  /*
   * --------------------------------------------------
   * 2. Blood banks
   * --------------------------------------------------
   */

  let bloodBanksQuery = supabase
    .from("blood_banks")
    .select(`
      id,
      organization_id,
      license_number,
      storage_capacity,
      cold_storage_available,
      blood_processing_available,
      operating_hours,
      created_at,
      organizations!inner (
        id,
        name,
        phone,
        email,
        address,
        organization_type,
        verification_status,
        cities!inner (
          id,
          name,
          provinces!inner (
            id,
            name
          )
        )
      )
    `)
    .is("deleted_at", null)
    .eq(
      "organizations.organization_type",
      "BLOOD_BANK",
    );

  /*
   * --------------------------------------------------
   * 3. Role-based organization scoping
   * --------------------------------------------------
   *
   * Government and Super Admin:
   *   - all visible hospitals
   *   - all visible blood banks
   *
   * Hospital Admin / Blood Bank Admin / Staff:
   *   - only their organization
   *
   * Using the same organization_id for both queries means
   * STAFF works correctly whether their organization is a
   * hospital or a blood bank.
   */

  const isScopedToOrg =
    (role === "HOSPITAL_ADMIN" ||
      role === "BLOOD_BANK_ADMIN" ||
      role === "STAFF") &&
    organizationId !== null;

  if (isScopedToOrg && organizationId) {
    hospitalsQuery = hospitalsQuery.eq(
      "organization_id",
      organizationId,
    );

    bloodBanksQuery = bloodBanksQuery.eq(
      "organization_id",
      organizationId,
    );
  }

  /*
   * --------------------------------------------------
   * 4. Execute both queries together
   * --------------------------------------------------
   */

  const [
    { data: hospitalsData, error: hospitalsError },
    { data: bloodBanksData, error: bloodBanksError },
  ] = await Promise.all([
    hospitalsQuery,
    bloodBanksQuery,
  ]);

  if (hospitalsError) {
    console.error(
      "HEALTHCARE FACILITIES - HOSPITALS QUERY ERROR",
      hospitalsError,
    );
  }

  if (bloodBanksError) {
    console.error(
      "HEALTHCARE FACILITIES - BLOOD BANKS QUERY ERROR",
      bloodBanksError,
    );
  }

  /*
   * --------------------------------------------------
   * 5. Hard error handling
   * --------------------------------------------------
   *
   * If either query fails, report an error rather than
   * silently presenting an incomplete healthcare network.
   */

  if (hospitalsError || bloodBanksError) {
    return {
      hospitals: [],
      stats: EMPTY_STATS,
      error: true,
    };
  }

  /*
   * --------------------------------------------------
   * 6. Normalize both facility types
   * --------------------------------------------------
   */

  const hospitals: HospitalWithDetails[] =
    (hospitalsData ?? []).map((row) =>
      normalizeHospitalRow(
        row as unknown as Record<string, unknown>,
      ),
    );

  const bloodBanks: BloodBankWithDetails[] =
    (bloodBanksData ?? []).map((row) =>
      normalizeBloodBankRow(
        row as unknown as Record<string, unknown>,
      ),
    );

  /*
   * --------------------------------------------------
   * 7. Combine healthcare facilities
   * --------------------------------------------------
   */

  const facilities: HealthcareFacility[] = [
    ...hospitals,
    ...bloodBanks,
  ];

  /*
   * Keep the directory deterministic:
   *
   * 1. Organization name
   * 2. Facility type
   */

  facilities.sort((a, b) => {
    const nameCompare =
      (a.organizations?.name ?? "").localeCompare(
        b.organizations?.name ?? "",
      );

    if (nameCompare !== 0) {
      return nameCompare;
    }

    return a.facility_type.localeCompare(
      b.facility_type,
    );
  });

  /*
   * --------------------------------------------------
   * 8. Summary stats
   * --------------------------------------------------
   */

  const stats: HospitalStats = {
    totalHospitals: hospitals.length,

    totalBloodBanks: bloodBanks.length,

    totalFacilities: facilities.length,

    /*
     * Emergency service is a hospital-specific metric.
     */
    emergencyService: hospitals.filter(
      (hospital) =>
        hospital.emergency_service,
    ).length,

    /*
     * ICU is a hospital-specific metric.
     */
    icuAvailable: hospitals.filter(
      (hospital) =>
        hospital.icu_available,
    ).length,

    /*
     * Blood storage applies to both hospitals and blood
     * banks.
     */
    bloodStorageAvailable:
      facilities.filter(
        (facility) =>
          facility.blood_storage_available,
      ).length,
  };

  return {
    hospitals: facilities,
    stats,
    error: false,
  };
}