import { createClient } from "@/lib/supabase/server";
import type { WebRole } from "@/lib/auth/get-current-user";

/* =========================================================
   TYPES
   ========================================================= */

export interface BloodGroup {
  id: string;
  code: string;
  name: string;
}

export interface PatientRecord {
  id: string;
  user_id: string;
  blood_group_id: string | null;
  date_of_birth: string | null;
  gender: string | null;
  emergency_contact: string | null;
  medical_notes: string | null;
  created_at: string;
  deleted_at: string | null;
}

export interface BloodRequestRecord {
  id: string;
  requester_id: string;
  organization_id: string;
  blood_group_id: string;
  patient_id: string;
  units_required: number;
  urgency: string;
  status: string;
  required_date: string;
  notes: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
  blood_groups: {
    id: string;
    code: string;
    name: string;
  };
  organizations: {
    id: string;
    name: string;
    organization_type: string;
    cities: {
      id: string;
      name: string;
      provinces: {
        id: string;
        name: string;
      };
    };
  };
  patients: {
    id: string;
    user_id: string;
    blood_group_id: string | null;
    date_of_birth: string | null;
    gender: string | null;
  } | null;
}

export interface BloodRequestSummary {
  totalRequests: number;
  pendingCount: number;
  urgentCount: number;
  fulfilledCount: number;
}

export interface AvailableOrganization {
  id: string;
  name: string;
  organization_type: string;
}

export interface BloodRequestsData {
  records: BloodRequestRecord[];
  bloodGroups: BloodGroup[];
  patients: PatientRecord[];
  summary: BloodRequestSummary;
  error: boolean;
  availableOrganizations?: AvailableOrganization[];
}

/* =========================================================
   EMPTY PAYLOAD
   ========================================================= */

const EMPTY_SUMMARY: BloodRequestSummary = {
  totalRequests: 0,
  pendingCount: 0,
  urgentCount: 0,
  fulfilledCount: 0,
};

/* =========================================================
   DATA FETCHER
   ========================================================= */

export async function getBloodRequestsData(
  role: WebRole,
  organizationId: string | null,
  userId: string,
): Promise<BloodRequestsData> {
  const supabase = await createClient();

  /*
   * --------------------------------------------------
   * 1. Blood group reference data
   * --------------------------------------------------
   */

  const {
    data: bloodGroupsData,
    error: bloodGroupsError,
  } = await supabase
    .from("blood_groups")
    .select("id, code, name")
    .is("deleted_at", null)
    .order("code");

  if (bloodGroupsError) {
    console.error(
      "BLOOD REQUESTS - BLOOD GROUPS QUERY ERROR",
      bloodGroupsError,
    );
  }

  /*
   * --------------------------------------------------
   * 2. Blood request records
   * --------------------------------------------------
   *
   * RLS is the PRIMARY scoping mechanism:
   *   - requester_id = auth.uid()
   *   - patient_id IN (patients where user_id = auth.uid())
   *   - is_super_admin()
   *   - is_government_admin()
   *   - is_organization_member(organization_id)
   *
   * The explicit organization filter below is defense-in-depth
   * only for non-global roles.
   */

  let query = supabase
    .from("blood_requests")
    .select(`
      *,
      blood_groups(id, code, name),
      organizations(id, name, organization_type, cities(id, name, provinces(id, name))),
      patients(id, user_id, blood_group_id, date_of_birth, gender)
    `);

  const isScopedToOrg =
    (role === "HOSPITAL_ADMIN" ||
      role === "BLOOD_BANK_ADMIN" ||
      role === "STAFF") &&
    organizationId !== null;

  if (isScopedToOrg && organizationId) {
    query = query.eq(
      "organization_id",
      organizationId,
    );
  }

  const { data, error } = await query
    .is("deleted_at", null)
    .order("created_at", { ascending: false });

  if (error) {
    console.error(
      "BLOOD REQUESTS - QUERY ERROR",
      error,
    );

    return {
      records: [],
      bloodGroups: [],
      patients: [],
      summary: EMPTY_SUMMARY,
      error: true,
    };
  }

  /*
   * --------------------------------------------------
   * 3. Cast rows
   * --------------------------------------------------
   */

  const records = (data ?? []) as unknown as BloodRequestRecord[];

  /*
   * --------------------------------------------------
   * 4. Summary stats
   * --------------------------------------------------
   *
   * status and urgency are free-text. Derive counts
   * dynamically from whatever values exist.
   */

  let pendingCount = 0;
  let urgentCount = 0;
  let fulfilledCount = 0;

  for (const record of records) {
    const statusLower = record.status.toLowerCase();

    if (
      statusLower.includes("pending") ||
      statusLower.includes("waiting") ||
      statusLower.includes("requested")
    ) {
      pendingCount++;
    }

    if (
      statusLower.includes("fulfill") ||
      statusLower.includes("complete") ||
      statusLower.includes("delivered") ||
      statusLower.includes("closed")
    ) {
      fulfilledCount++;
    }

    const urgencyLower = record.urgency.toLowerCase();

    if (
      urgencyLower.includes("urgent") ||
      urgencyLower.includes("critical") ||
      urgencyLower.includes("emergency")
    ) {
      urgentCount++;
    }
  }

  const summary: BloodRequestSummary = {
    totalRequests: records.length,
    pendingCount,
    urgentCount,
    fulfilledCount,
  };

  /*
   * --------------------------------------------------
   * 5. Patients (for the create/edit form selector)
   * --------------------------------------------------
   *
   * patients table has NO RLS enabled, so all authenticated
   * users can read all patients. We filter to non-deleted
   * patients. SUPER_ADMIN and org admins see all patients
   * to select from. Regular requesters see patients they
   * own (user_id = auth.uid()).
   */

  let patientsQuery = supabase
    .from("patients")
    .select("id, user_id, blood_group_id, date_of_birth, gender, emergency_contact, medical_notes, created_at, deleted_at")
    .is("deleted_at", null);

  /*
   * Non-privileged roles only see their own patients.
   * SUPER_ADMIN and GOVERNMENT_ADMIN see all patients.
   */
  if (
  role !== "SUPER_ADMIN" &&
  role !== "GOVERNMENT_ADMIN" &&
  role !== "HOSPITAL_ADMIN" &&
  role !== "BLOOD_BANK_ADMIN" &&
  role !== "STAFF"
) {
  patientsQuery = patientsQuery.eq("user_id", userId);
}

  const {
    data: patientsData,
    error: patientsError,
  } = await patientsQuery.order("created_at", {
    ascending: false,
  });

  if (patientsError) {
    console.error(
      "BLOOD REQUESTS - PATIENTS QUERY ERROR",
      patientsError,
    );
  }

  const patients = (patientsData ?? []) as unknown as PatientRecord[];

  /*
   * --------------------------------------------------
   * 6. Eligible organizations (SUPER_ADMIN only)
   * --------------------------------------------------
   */

  let availableOrganizations:
    | AvailableOrganization[]
    | undefined;

  if (role === "SUPER_ADMIN") {
    const {
      data: orgsData,
      error: orgsError,
    } = await supabase
      .from("organizations")
      .select("id, name, organization_type")
      .eq("verification_status", "VERIFIED")
      .is("deleted_at", null)
      .order("name");

    if (orgsError) {
      console.error(
        "BLOOD REQUESTS - ORGANIZATIONS QUERY ERROR",
        orgsError,
      );
    }

    availableOrganizations =
      (orgsData ?? []) as unknown as AvailableOrganization[];
  }

  return {
    records,
    bloodGroups:
      (bloodGroupsData ?? []) as unknown as BloodGroup[],
    patients,
    summary,
    error: bloodGroupsError ? true : false,
    availableOrganizations,
  };
}
