import { createClient } from "@/lib/supabase/server";

export interface DashboardBloodGroup {
  code: string;
  name: string;
  availableUnits: number;
  totalUnits: number;
  reservedUnits: number;
}

export interface DashboardProvinceInventory {
  id: string;
  code: string;
  name: string;
  availableUnits: number;
  totalUnits: number;
  reservedUnits: number;
}

export interface DashboardData {
  bloodInventory: {
    totalUnits: number;
    availableUnits: number;
    reservedUnits: number;
    totalRecords: number;
    bloodGroupCount: number;
    groupSummaries: DashboardBloodGroup[];
  };

  provinceInventory: DashboardProvinceInventory[];

  emergencySos: {
    active: number;
  };

  donors: {
    total: number;
    available: number;
  };

  healthcareFacilities: {
    total: number;
  };
}

export async function getDashboardData(
  userId: string,
  role: string,
  organizationId: string | null,
): Promise<DashboardData> {
  const supabase = await createClient();

  const isGlobalRole =
    role === "SUPER_ADMIN" ||
    role === "GOVERNMENT_ADMIN";

  /*
   * --------------------------------------------------
   * BLOOD INVENTORY
   * --------------------------------------------------
   *
   * Global administrators:
   *   SUPER_ADMIN
   *   GOVERNMENT_ADMIN
   *
   * see the complete network inventory.
   *
   * Organization users:
   *   HOSPITAL_ADMIN
   *   BLOOD_BANK_ADMIN
   *   STAFF
   *
   * are scoped to their organization.
   *
   * Supabase RLS remains the primary security boundary.
   */

  let inventoryQuery = supabase
    .from("blood_inventory")
    .select(`
      total_units,
      available_units,
      reserved_units,
      blood_group_id,
      organization_id,
      blood_groups(
        id,
        code,
        name
      ),
      organizations(
        id,
        city_id,
        cities(
          id,
          name,
          province_id,
          provinces(
            id,
            name,
            code
          )
        )
      )
    `);

  if (!isGlobalRole && organizationId) {
    inventoryQuery = inventoryQuery.eq(
      "organization_id",
      organizationId,
    );
  }

  const {
    data: inventory,
    error: inventoryError,
  } = await inventoryQuery;

  if (inventoryError) {
    console.error(
      "DASHBOARD - INVENTORY ERROR",
      inventoryError,
    );
  }

  /*
   * --------------------------------------------------
   * INVENTORY SUMMARY
   * --------------------------------------------------
   */

  const totalUnits =
    inventory?.reduce(
      (sum, row) =>
        sum + (row.total_units ?? 0),
      0,
    ) ?? 0;

  const availableUnits =
    inventory?.reduce(
      (sum, row) =>
        sum + (row.available_units ?? 0),
      0,
    ) ?? 0;

  const reservedUnits =
    inventory?.reduce(
      (sum, row) =>
        sum + (row.reserved_units ?? 0),
      0,
    ) ?? 0;

  /*
   * --------------------------------------------------
   * BLOOD GROUP BREAKDOWN
   * --------------------------------------------------
   */

  const groupMap = new Map<
    string,
    DashboardBloodGroup
  >();

  for (const row of inventory ?? []) {
    const bloodGroup = Array.isArray(row.blood_groups)
      ? row.blood_groups[0] ?? null
      : row.blood_groups ?? null;

    const key =
      bloodGroup?.id ??
      row.blood_group_id;

    const existing = groupMap.get(key);

    if (existing) {
      existing.availableUnits +=
        row.available_units ?? 0;

      existing.totalUnits +=
        row.total_units ?? 0;

      existing.reservedUnits +=
        row.reserved_units ?? 0;
    } else {
      groupMap.set(key, {
        code:
          bloodGroup?.code ??
          "Unknown",

        name:
          bloodGroup?.name ??
          "Unknown",

        availableUnits:
          row.available_units ?? 0,

        totalUnits:
          row.total_units ?? 0,

        reservedUnits:
          row.reserved_units ?? 0,
      });
    }
  }

  const groupSummaries =
    Array.from(groupMap.values()).sort(
      (a, b) =>
        a.code.localeCompare(b.code),
    );

  const bloodInventory = {
    totalUnits,
    availableUnits,
    reservedUnits,
    totalRecords:
      inventory?.length ?? 0,
    bloodGroupCount:
      groupSummaries.length,
    groupSummaries,
  };

  /*
   * --------------------------------------------------
   * PROVINCE INVENTORY
   * --------------------------------------------------
   *
   * Inventory is connected to:
   *
   * blood_inventory
   *      ↓
   * organizations
   *      ↓
   * cities
   *      ↓
   * provinces
   *
   * This gives the Pakistan map a real database
   * source for province-level inventory.
   */

  const provinceMap = new Map<
    string,
    DashboardProvinceInventory
  >();

  for (const row of inventory ?? []) {
    const organization = Array.isArray(
      row.organizations,
    )
      ? row.organizations[0] ?? null
      : row.organizations ?? null;

    const city = organization
      ? Array.isArray(organization.cities)
        ? organization.cities[0] ?? null
        : organization.cities ?? null
      : null;

    const province = city
      ? Array.isArray(city.provinces)
        ? city.provinces[0] ?? null
        : city.provinces ?? null
      : null;

    /*
     * Inventory without a valid province cannot
     * be displayed on the geographic map.
     */
    if (!province?.id) {
      continue;
    }

    const existing =
      provinceMap.get(province.id);

    if (existing) {
      existing.availableUnits +=
        row.available_units ?? 0;

      existing.totalUnits +=
        row.total_units ?? 0;

      existing.reservedUnits +=
        row.reserved_units ?? 0;
    } else {
      provinceMap.set(province.id, {
        id: province.id,
        code: province.code,
        name: province.name,
        availableUnits:
          row.available_units ?? 0,
        totalUnits:
          row.total_units ?? 0,
        reservedUnits:
          row.reserved_units ?? 0,
      });
    }
  }

  const provinceInventory =
    Array.from(
      provinceMap.values(),
    ).sort((a, b) =>
      a.name.localeCompare(b.name),
    );

  /*
   * --------------------------------------------------
   * EMERGENCY SOS
   * --------------------------------------------------
   *
   * emergency_sos intentionally has no
   * organization_id.
   *
   * Visibility is controlled by Supabase RLS.
   */

  const {
    count: sosCount,
    error: sosError,
  } = await supabase
    .from("emergency_sos")
    .select("id", {
      count: "exact",
      head: true,
    })
    .in("status", [
      "pending",
      "active",
    ]);

  if (sosError) {
    console.error(
      "DASHBOARD - SOS ERROR",
      sosError,
    );
  }

  /*
   * --------------------------------------------------
   * DONORS
   * --------------------------------------------------
   */

  const {
    count: donorCount,
    error: donorError,
  } = await supabase
    .from("donors")
    .select("id", {
      count: "exact",
      head: true,
    });

  if (donorError) {
    console.error(
      "DASHBOARD - DONOR ERROR",
      donorError,
    );
  }

  const {
    count: availableDonorCount,
    error: availableDonorError,
  } = await supabase
    .from("donors")
    .select("id", {
      count: "exact",
      head: true,
    })
    .eq("is_available", true);

  if (availableDonorError) {
    console.error(
      "DASHBOARD - AVAILABLE DONOR ERROR",
      availableDonorError,
    );
  }

  /*
   * --------------------------------------------------
   * HEALTHCARE FACILITIES
   * --------------------------------------------------
   *
   * organizations contains both hospitals and
   * blood banks.
   *
   * Only verified, non-deleted organizations
   * are counted.
   */

  const {
    count: facilityCount,
    error: facilityError,
  } = await supabase
    .from("organizations")
    .select("id", {
      count: "exact",
      head: true,
    })
    .eq(
      "verification_status",
      "VERIFIED",
    )
    .is("deleted_at", null);

  if (facilityError) {
    console.error(
      "DASHBOARD - FACILITIES ERROR",
      facilityError,
    );
  }

  /*
   * --------------------------------------------------
   * RETURN
   * --------------------------------------------------
   */

  return {
    bloodInventory,

    provinceInventory,

    emergencySos: {
      active: sosCount ?? 0,
    },

    donors: {
      total: donorCount ?? 0,
      available:
        availableDonorCount ?? 0,
    },

    healthcareFacilities: {
      total: facilityCount ?? 0,
    },
  };
}