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

export interface BloodInventoryRecord {
  id: string;
  organization_id: string;
  blood_group_id: string;
  total_units: number;
  available_units: number;
  reserved_units: number;
  donation_date: string;
  expiry_date: string;
  storage_location: string | null;
  status: string;
  created_at: string;
  updated_at: string;
  reservation_count: number;
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
}

export interface BloodGroupSummary {
  code: string;
  name: string;
  availableUnits: number;
  totalUnits: number;
  reservedUnits: number;
  recordCount: number;
}

export interface BloodInventorySummary {
  totalRecords: number;
  totalAvailableUnits: number;
  totalReservedUnits: number;
  totalUnits: number;
  bloodGroupCount: number;
  organizationCount: number;
}

export interface AvailableOrganization {
  id: string;
  name: string;
  organization_type: string;
}

export interface BloodInventoryData {
  records: BloodInventoryRecord[];
  bloodGroups: BloodGroup[];
  groupSummaries: BloodGroupSummary[];
  summary: BloodInventorySummary;
  /*
   * Follows the get-hospitals-data.ts pattern: the flag lets
   * the page distinguish a failed fetch (error state) from a
   * legitimately empty inventory (empty state).
   */
  error: boolean;
  /*
   * VERIFIED organizations eligible for blood inventory.
   * Only populated for SUPER_ADMIN — other roles are scoped
   * to their own organization automatically.
   */
  availableOrganizations?: AvailableOrganization[];
}

/* =========================================================
   EMPTY PAYLOAD
   ========================================================= */

const EMPTY_SUMMARY: BloodInventorySummary = {
  totalRecords: 0,
  totalAvailableUnits: 0,
  totalReservedUnits: 0,
  totalUnits: 0,
  bloodGroupCount: 0,
  organizationCount: 0,
};

/* =========================================================
   DATA FETCHER
   ========================================================= */

export async function getBloodInventoryData(
  role: WebRole,
  organizationId: string | null,
): Promise<BloodInventoryData> {
  const supabase = await createClient();

  /*
   * --------------------------------------------------
   * 1. Blood group reference data
   * --------------------------------------------------
   *
   * blood_groups supports soft delete (deleted_at), so
   * soft-deleted groups are excluded from the reference
   * list. RLS allows all authenticated users to read it.
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
      "BLOOD INVENTORY - BLOOD GROUPS QUERY ERROR",
      bloodGroupsError,
    );
  }

  /*
   * --------------------------------------------------
   * 2. Inventory records
   * --------------------------------------------------
   *
   * blood_inventory has NO deleted_at column (records are
   * physically deleted), so no soft-delete filter is applied.
   *
   * RLS is the PRIMARY scoping mechanism:
   *   - SUPER_ADMIN / GOVERNMENT_ADMIN see all organizations
   *   - org members (HOSPITAL_ADMIN, BLOOD_BANK_ADMIN,
   *     STAFF) see only their own organization
   *
   * The explicit organization filter below is defense-in-depth
   * only — it mirrors the get-hospitals-data.ts pattern and
   * always matches what RLS already returns.
   */

  let query = supabase
  .from("blood_inventory")
  .select(`
    *,
    blood_groups(id, code, name),
    organizations(
      id,
      name,
      organization_type,
      cities(
        id,
        name,
        provinces(
          id,
          name
        )
      )
    ),
    blood_reservations!fk_blood_reservations_blood_inventory_id_blood_inventory(
      id
    )
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

  const { data, error } = await query.order(
    "expiry_date",
    { ascending: true },
  );

  if (error) {
    console.error(
      "BLOOD INVENTORY - QUERY ERROR",
      error,
    );

    return {
      records: [],
      bloodGroups: [],
      groupSummaries: [],
      summary: EMPTY_SUMMARY,
      error: true,
    };
  }

  /*
   * --------------------------------------------------
   * 3. Cast rows
   * --------------------------------------------------
   */

 const records: BloodInventoryRecord[] = (
  data ?? []
).map((row) => {
  const rawRow = row as typeof row & {
    blood_reservations?: Array<{ id: string }>;
  };

  return {
    ...(rawRow as unknown as Omit<
      BloodInventoryRecord,
      "reservation_count"
    >),
    reservation_count:
      rawRow.blood_reservations?.length ?? 0,
  };
});

  /*
   * Order by blood group code, then expiry date ascending.
   * The query already orders by expiry_date; the stable sort
   * below groups rows by blood group code while preserving
   * the expiry order inside each group.
   */

  records.sort((a, b) => {
    const codeA = a.blood_groups?.code ?? "";
    const codeB = b.blood_groups?.code ?? "";
    return codeA.localeCompare(codeB);
  });

  /*
   * --------------------------------------------------
   * 4. Per-group summaries
   * --------------------------------------------------
   */

  const summaryMap = new Map<
    string,
    BloodGroupSummary
  >();

  for (const record of records) {
    const existing = summaryMap.get(
      record.blood_group_id,
    );

    if (existing) {
      existing.availableUnits +=
        record.available_units;
      existing.totalUnits += record.total_units;
      existing.reservedUnits +=
        record.reserved_units;
      existing.recordCount += 1;
    } else {
      summaryMap.set(record.blood_group_id, {
        code: record.blood_groups?.code ?? "Unknown",
        name: record.blood_groups?.name ?? "Unknown",
        availableUnits: record.available_units,
        totalUnits: record.total_units,
        reservedUnits: record.reserved_units,
        recordCount: 1,
      });
    }
  }

  const groupSummaries = Array.from(
    summaryMap.values(),
  );

  /*
   * --------------------------------------------------
   * 5. Summary stats
   * --------------------------------------------------
   */

  const summary: BloodInventorySummary = {
    totalRecords: records.length,

    totalAvailableUnits: records.reduce(
      (sum, r) => sum + r.available_units,
      0,
    ),

    totalReservedUnits: records.reduce(
      (sum, r) => sum + r.reserved_units,
      0,
    ),

    totalUnits: records.reduce(
      (sum, r) => sum + r.total_units,
      0,
    ),

    bloodGroupCount: groupSummaries.length,

    organizationCount: new Set(
      records.map((r) => r.organization_id),
    ).size,
  };

  /*
   * --------------------------------------------------
   * 6. Eligible organizations (SUPER_ADMIN only)
   * --------------------------------------------------
   *
   * SUPER_ADMIN has no organization of their own, so the
   * Add Inventory form needs a list of target orgs. The
   * blood_inventory.organization_id FK references
   * organizations(id) with no type restriction, so both
   * HOSPITAL and BLOOD_BANK types are eligible.
   *
   * RLS on the organizations table allows authenticated
   * users to see VERIFIED orgs (or their own via
   * membership), so this query returns all VERIFIED,
   * non-deleted organizations visible to the SUPER_ADMIN.
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
        "BLOOD INVENTORY - ORGANIZATIONS QUERY ERROR",
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
    groupSummaries,
    summary,
    /*
     * A failed blood_groups lookup only degrades the reference
     * list (filters / add form) — the inventory records can
     * still render — so only an inventory query failure is
     * treated as a hard error above.
     */
    error: bloodGroupsError ? true : false,
    availableOrganizations,
  };
}
