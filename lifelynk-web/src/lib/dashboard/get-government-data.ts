import { createClient } from "@/lib/supabase/server";

export type GovernmentOrganizationStatus =
  | "PENDING"
  | "VERIFIED"
  | "REJECTED";

export type AlertSeverity =
  | "critical"
  | "warning"
  | "info";

export type GovernmentAnalyticsSource =
  | "LIVE"
  | "HISTORICAL";

export interface GovernmentOrganization {
  id: string;
  cityId: string | null;
  cityName: string;
  provinceName: string;
  organizationType: "HOSPITAL" | "BLOOD_BANK";
  name: string;
  registrationNumber: string | null;
  phone: string;
  email: string | null;
  address: string;
  latitude: number | null;
  longitude: number | null;
  verificationStatus: GovernmentOrganizationStatus;
  createdAt: string;
  verifiedAt: string | null;
  verifiedBy: string | null;
  verificationNotes: string | null;
  licenseNumber: string | null;
  hospitalType: string | null;
  emergencyService: boolean | null;
  bloodStorageAvailable: boolean | null;
  totalBeds: number | null;
  icuAvailable: boolean | null;
  storageCapacity: number | null;
  coldStorageAvailable: boolean | null;
  bloodProcessingAvailable: boolean | null;
  operatingHours: string | null;
}

export interface GovernmentLiveAnalytics {
  metricName: string;
  value: number;
  region: string | null;
  generatedAt: string;
}

export interface GovernmentData {
  organizations: GovernmentOrganization[];

  summary: {
    totalOrganizations: number;
    pendingOrganizations: number;
    verifiedOrganizations: number;
    rejectedOrganizations: number;
    hospitals: number;
    bloodBanks: number;
  };

  bloodNetwork: {
    totalUnits: number;
    availableUnits: number;
    reservedUnits: number;
    bloodGroups: {
      id: string;
      code: string;
      name: string;
      totalUnits: number;
      availableUnits: number;
      reservedUnits: number;
      requestedUnits: number;
      shortageUnits: number;
    }[];
    risk: {
      lowStockGroups: number;
      expiredUnits: number;
      expiringSoonUnits: number;
      shortageGroups: number;
    };
  };

  bloodRequests: {
    total: number;
    pending: number;
    active: number;
    completed: number;
    cancelled: number;
    requestedUnits: number;
    byBloodGroup: {
      code: string;
      name: string;
      requests: number;
      unitsRequired: number;
    }[];
  };

  emergency: {
    total: number;
    pending: number;
    active: number;
    resolved: number;
    cancelled: number;
    requestedUnits: number;
    byUrgency: {
      urgency: string;
      count: number;
    }[];
    records: {
      id: string;
      cityName: string;
      provinceName: string;
      bloodGroup: string;
      unitsRequired: number;
      urgency: string;
      status: string;
      createdAt: string;
    }[];
  };

  donors: {
    total: number;
    available: number;
    unavailable: number;
    byBloodGroup: {
      code: string;
      name: string;
      total: number;
      available: number;
    }[];
    activity: {
      totalDonations: number;
      verifiedDonations: number;
      totalUnits: number;
      lastDonationAt: string | null;
      recent30Days: number;
      recent90Days: number;
      byBloodGroup: {
        code: string;
        name: string;
        donations: number;
        units: number;
      }[];
    };
  };

  facilityHealth: {
    verified: number;
    pending: number;
    rejected: number;
    hospitalsWithEmergency: number;
    hospitalsWithBloodStorage: number;
    hospitalsWithIcu: number;
    bloodBanksWithColdStorage: number;
    bloodBanksWithProcessing: number;
    citiesCovered: number;
    provincesCovered: number;
  };

  regional: {
    id: string;
    name: string;
    code: string;
    organizations: number;
    hospitals: number;
    bloodBanks: number;
    donors: number;
    availableDonors: number;
    bloodUnits: number;
    availableUnits: number;
    bloodRequests: number;
    requestedUnits: number;
    sos: number;
    activeSos: number;
  }[];

  cities: {
    id: string;
    name: string;
    provinceName: string;
    organizations: number;
    hospitals: number;
    bloodBanks: number;
    donors: number;
    availableDonors: number;
    availableUnits: number;
    requestedUnits: number;
    activeSos: number;
  }[];

  /**
   * Historical analytics are strictly read from
   * public.government_analytics.
   *
   * No historical data is generated here.
   */
  historical: {
    metricName: string;
    value: number;
    region: string | null;
    generatedAt: string;
  }[];

  /**
   * Live analytics are calculated directly from
   * the current Supabase source tables every time
   * getGovernmentData() executes.
   *
   * They do not write anything to government_analytics.
   */
  liveAnalytics: GovernmentLiveAnalytics[];

  /**
   * HISTORICAL means stored records exist in
   * government_analytics.
   *
   * LIVE means there are no stored historical
   * records and the current dashboard is using
   * live source-table calculations.
   */
  analyticsSource: GovernmentAnalyticsSource;

  /**
   * Exact timestamp for the current server-side
   * Government Dashboard snapshot.
   */
  lastUpdatedAt: string;

  alerts: {
    type: string;
    severity: AlertSeverity;
    title: string;
    message: string;
  }[];
}

type Row = Record<string, unknown>;

const num = (value: unknown): number =>
  Number.isFinite(Number(value))
    ? Number(value)
    : 0;

const low = (value: unknown): string =>
  String(value ?? "")
    .trim()
    .toLowerCase();

const bool = (value: unknown): boolean =>
  value === true;

const text = (value: unknown): string =>
  value == null ? "" : String(value);

function rows<T extends Row>(
  value: T[] | null | undefined,
): T[] {
  return Array.isArray(value) ? value : [];
}

/**
 * Create a one-row-per-organization map.
 *
 * hospitals and blood_banks are child/detail tables.
 * If duplicate detail rows exist for an organization,
 * only the first row is used for Government metrics.
 *
 * This prevents inflated facility counts.
 */
function uniqueOrganizationRows(
  source: Row[],
): Map<string, Row> {
  const result = new Map<string, Row>();

  for (const row of source) {
    const organizationId = text(
      row.organization_id,
    );

    if (!organizationId) {
      continue;
    }

    if (!result.has(organizationId)) {
      result.set(organizationId, row);
    }
  }

  return result;
}

/**
 * Build a latest-record map.
 *
 * Used for donor_availability so multiple availability
 * records for the same donor cannot inflate or conflict
 * with Government donor availability.
 */
function latestAvailabilityRows(
  source: Row[],
): Map<string, Row> {
  const result = new Map<string, Row>();

  for (const row of source) {
    const donorId = text(row.donor_id);

    if (!donorId) {
      continue;
    }

    const existing = result.get(donorId);

    if (!existing) {
      result.set(donorId, row);
      continue;
    }

    const currentDate = Date.parse(
      text(row.last_checked_at),
    );

    const existingDate = Date.parse(
      text(existing.last_checked_at),
    );

    if (
      Number.isFinite(currentDate) &&
      (!Number.isFinite(existingDate) ||
        currentDate > existingDate)
    ) {
      result.set(donorId, row);
    }
  }

  return result;
}

export async function getGovernmentData(): Promise<GovernmentData> {
  const supabase = await createClient();

  if (process.env.NODE_ENV === "development") {
  const {
    data: {
      user,
    },
  } = await supabase.auth.getUser();

  console.log(
    "GOVERNMENT SERVER AUTH USER",
    {
      id: user?.id ?? null,
      email: user?.email ?? null,
    },
  );

  const {
    data: debugOrganizations,
    error: debugOrganizationsError,
  } = await supabase
    .from("organizations")
    .select(
      "id,name,organization_type,verification_status,deleted_at",
    )
    .is("deleted_at", null)
    .order("created_at", {
      ascending: false,
    });

  console.log(
    "GOVERNMENT SERVER ORGANIZATIONS",
    {
      count:
        debugOrganizations?.length ?? 0,
      rows: debugOrganizations,
      error:
        debugOrganizationsError?.message ??
        null,
    },
  );
}

  /*
   * -------------------------------------------------------
   * LIVE SOURCE TABLES
   * -------------------------------------------------------
   *
   * These are the same tables monitored by the
   * Government Dashboard Realtime channel.
   *
   * Realtime event
   *      ↓
   * router.refresh()
   *      ↓
   * getGovernmentData()
   *      ↓
   * fresh Supabase snapshot
   */
  const [
    organizationsResult,
    hospitalsResult,
    bloodBanksResult,
    citiesResult,
    provincesResult,
    groupsResult,
    inventoryResult,
    requestsResult,
    donorsResult,
    availabilityResult,
    sosResult,
    donationsResult,
    analyticsResult,
  ] = await Promise.all([
    supabase
      .from("organizations")
      .select(
        "id,city_id,organization_type,name,registration_number,phone,email,address,latitude,longitude,verification_status,created_at,verified_at,verified_by,verification_notes",
      )
      .is("deleted_at", null)
      .order("created_at", {
        ascending: false,
      }),

    supabase
      .from("hospitals")
      .select(
        "organization_id,hospital_type,license_number,emergency_service,blood_storage_available,total_beds,icu_available",
      )
      .is("deleted_at", null),

    supabase
      .from("blood_banks")
      .select(
        "organization_id,license_number,storage_capacity,cold_storage_available,blood_processing_available,operating_hours",
      )
      .is("deleted_at", null),

    supabase
      .from("cities")
      .select(
        "id,name,province_id",
      )
      .is("deleted_at", null),

    supabase
      .from("provinces")
      .select(
        "id,name,code",
      )
      .is("deleted_at", null),

    supabase
      .from("blood_groups")
      .select(
        "id,code,name",
      )
      .is("deleted_at", null)
      .order("code"),

    supabase
      .from("blood_inventory")
      .select(
        "id,organization_id,blood_group_id,total_units,available_units,reserved_units,donation_date,expiry_date,status",
      ),

    supabase
      .from("blood_requests")
      .select(
        "id,organization_id,blood_group_id,units_required,urgency,status,created_at",
      )
      .is("deleted_at", null),

    supabase
      .from("donors")
      .select(
        "id,blood_group_id,city_id,is_available,last_donation_date",
      ),

    supabase
      .from("donor_availability")
      .select(
        "donor_id,is_available,last_checked_at,next_eligible_date",
      ),

    /*
     * IMPORTANT:
     *
     * emergency_sos is the source of truth for
     * emergency operations.
     *
     * No emergency_requests table is used.
     */
    supabase
      .from("emergency_sos")
      .select(
        "id,user_id,blood_group_id,city_id,units_required,urgency_level,status,created_at,latitude,longitude",
      ),

    supabase
      .from("donation_history")
      .select(
        "id,donor_id,organization_id,blood_group_id,units_donated,donation_date,verified",
      ),

    /*
     * Historical analytics only.
     *
     * Live analytics are calculated below from
     * the current operational source tables.
     */
    supabase
      .from("government_analytics")
      .select(
        "id,metric_name,metric_value,region,generated_at",
      )
      .order("generated_at", {
        ascending: false,
      })
      .limit(500),
  ]);

  const results = [
    organizationsResult,
    hospitalsResult,
    bloodBanksResult,
    citiesResult,
    provincesResult,
    groupsResult,
    inventoryResult,
    requestsResult,
    donorsResult,
    availabilityResult,
    sosResult,
    donationsResult,
    analyticsResult,
  ];

  const failed = results.find(
    (result) => result.error,
  );

  if (failed?.error) {
    console.error(
      "GOVERNMENT DASHBOARD DATA ERROR",
      failed.error,
    );

    throw new Error(
      "Unable to load government analytics.",
    );
  }

  const O = rows(
    organizationsResult.data as Row[],
  );

  const H = rows(
    hospitalsResult.data as Row[],
  );

  const B = rows(
    bloodBanksResult.data as Row[],
  );

  const C = rows(
    citiesResult.data as Row[],
  );

  const P = rows(
    provincesResult.data as Row[],
  );

  const G = rows(
    groupsResult.data as Row[],
  );

  const I = rows(
    inventoryResult.data as Row[],
  );

  const R = rows(
    requestsResult.data as Row[],
  );

  const D = rows(
    donorsResult.data as Row[],
  );

  const A = rows(
    availabilityResult.data as Row[],
  );

  const E = rows(
    sosResult.data as Row[],
  );

  const DH = rows(
    donationsResult.data as Row[],
  );

  const GA = rows(
    analyticsResult.data as Row[],
  );

  /*
   * -------------------------------------------------------
   * LIVE SNAPSHOT TIMESTAMP
   * -------------------------------------------------------
   *
   * Every fresh server execution gets a new timestamp.
   *
   * The client realtime layer calls router.refresh()
   * whenever a subscribed Supabase table changes.
   */
  const lastUpdatedAt =
    new Date().toISOString();

  /*
   * -------------------------------------------------------
   * LOOKUP MAPS
   * -------------------------------------------------------
   */

  const cityMap = new Map(
    C.map((city) => [
      text(city.id),
      city,
    ]),
  );

  const provinceMap = new Map(
    P.map((province) => [
      text(province.id),
      province,
    ]),
  );

  /*
   * IMPORTANT:
   *
   * Child facility tables are reduced to one row
   * per organization before any facility calculation.
   */
  const hospitalMap =
    uniqueOrganizationRows(H);

  const bankMap =
    uniqueOrganizationRows(B);

  /*
   * Donor availability can have multiple records.
   * Use the latest record for each donor.
   */
  const latestAvailabilityMap =
    latestAvailabilityRows(A);

  const groupMap = new Map(
    G.map((group) => [
      text(group.id),
      group,
    ]),
  );

  /*
   * -------------------------------------------------------
   * ORGANIZATIONS
   * -------------------------------------------------------
   */

  const orgs: GovernmentOrganization[] =
    O.map((organization) => {
      const organizationId =
        text(organization.id);

      const city = organization.city_id
        ? cityMap.get(
            text(
              organization.city_id,
            ),
          )
        : undefined;

      const province =
        city?.province_id
          ? provinceMap.get(
              text(city.province_id),
            )
          : undefined;

      const hospital =
        hospitalMap.get(
          organizationId,
        );

      const bank =
        bankMap.get(
          organizationId,
        );

      const rawStatus = text(
        organization.verification_status,
      );

      const verificationStatus: GovernmentOrganizationStatus =
        rawStatus === "VERIFIED"
          ? "VERIFIED"
          : rawStatus === "REJECTED"
            ? "REJECTED"
            : "PENDING";

      const organizationType =
        text(
          organization.organization_type,
        ) === "BLOOD_BANK"
          ? "BLOOD_BANK"
          : "HOSPITAL";

      return {
        id: organizationId,

        cityId: organization.city_id
          ? text(
              organization.city_id,
            )
          : null,

        cityName:
          text(city?.name) ||
          "Unknown",

        provinceName:
          text(province?.name) ||
          "Unknown",

        organizationType,

        name: text(
          organization.name,
        ),

        registrationNumber:
          organization.registration_number
            ? text(
                organization.registration_number,
              )
            : null,

        phone: text(
          organization.phone,
        ),

        email: organization.email
          ? text(organization.email)
          : null,

        address: text(
          organization.address,
        ),

        latitude:
          organization.latitude == null
            ? null
            : num(
                organization.latitude,
              ),

        longitude:
          organization.longitude == null
            ? null
            : num(
                organization.longitude,
              ),

        verificationStatus,

        createdAt: text(
          organization.created_at,
        ),

        verifiedAt:
          organization.verified_at
            ? text(
                organization.verified_at,
              )
            : null,

        verifiedBy:
          organization.verified_by
            ? text(
                organization.verified_by,
              )
            : null,

        verificationNotes:
          organization.verification_notes
            ? text(
                organization.verification_notes,
              )
            : null,

        /*
         * Hospital-specific metadata.
         */
        licenseNumber:
          hospital?.license_number != null
            ? text(
                hospital.license_number,
              )
            : bank?.license_number != null
              ? text(
                  bank.license_number,
                )
              : null,

        hospitalType:
          hospital?.hospital_type != null
            ? text(
                hospital.hospital_type,
              )
            : null,

        emergencyService:
          hospital?.emergency_service == null
            ? null
            : bool(
                hospital.emergency_service,
              ),

        bloodStorageAvailable:
          hospital?.blood_storage_available ==
          null
            ? null
            : bool(
                hospital.blood_storage_available,
              ),

        totalBeds:
          hospital?.total_beds == null
            ? null
            : num(
                hospital.total_beds,
              ),

        icuAvailable:
          hospital?.icu_available == null
            ? null
            : bool(
                hospital.icu_available,
              ),

        /*
         * Blood-bank-specific metadata.
         */
        storageCapacity:
          bank?.storage_capacity == null
            ? null
            : num(
                bank.storage_capacity,
              ),

        coldStorageAvailable:
          bank?.cold_storage_available ==
          null
            ? null
            : bool(
                bank.cold_storage_available,
              ),

        bloodProcessingAvailable:
          bank?.blood_processing_available ==
          null
            ? null
            : bool(
                bank.blood_processing_available,
              ),

        operatingHours:
          bank?.operating_hours != null
            ? text(
                bank.operating_hours,
              )
            : null,
      };
    });

  /*
   * -------------------------------------------------------
   * SUMMARY
   * -------------------------------------------------------
   *
   * Organization counts come from the organizations
   * source table, which is the authoritative parent
   * table for facilities.
   */
  const summary = {
    totalOrganizations:
      orgs.length,

    pendingOrganizations:
      orgs.filter(
        (organization) =>
          organization.verificationStatus ===
          "PENDING",
      ).length,

    verifiedOrganizations:
      orgs.filter(
        (organization) =>
          organization.verificationStatus ===
          "VERIFIED",
      ).length,

    rejectedOrganizations:
      orgs.filter(
        (organization) =>
          organization.verificationStatus ===
          "REJECTED",
      ).length,

    hospitals:
      orgs.filter(
        (organization) =>
          organization.organizationType ===
          "HOSPITAL",
      ).length,

    bloodBanks:
      orgs.filter(
        (organization) =>
          organization.organizationType ===
          "BLOOD_BANK",
      ).length,
  };

  /*
   * -------------------------------------------------------
   * INVENTORY
   * -------------------------------------------------------
   */

  const now = Date.now();

  const soon =
    now +
    7 * 24 * 60 * 60 * 1000;

  let expiredUnits = 0;
  let expiringSoonUnits = 0;

  for (const item of I) {
    const expiry = Date.parse(
      text(item.expiry_date),
    );

    const availableUnits =
      Math.max(
        0,
        num(item.available_units),
      );

    if (!Number.isFinite(expiry)) {
      continue;
    }

    if (expiry < now) {
      expiredUnits +=
        availableUnits;
    } else if (expiry <= soon) {
      expiringSoonUnits +=
        availableUnits;
    }
  }

  /*
   * Requested units by blood group.
   */
  const requestedByGroup =
    new Map<string, number>();

  for (const request of R) {
    const groupId = text(
      request.blood_group_id,
    );

    if (!groupId) {
      continue;
    }

    requestedByGroup.set(
      groupId,
      (requestedByGroup.get(groupId) ?? 0) +
        num(
          request.units_required,
        ),
    );
  }

  const bloodGroups =
    G.map((group) => {
      const groupId =
        text(group.id);

      const items = I.filter(
        (item) =>
          text(
            item.blood_group_id,
          ) === groupId,
      );

      const totalUnits =
        items.reduce(
          (sum, item) =>
            sum +
            num(
              item.total_units,
            ),
          0,
        );

      const availableUnits =
        items.reduce(
          (sum, item) =>
            sum +
            num(
              item.available_units,
            ),
          0,
        );

      const reservedUnits =
        items.reduce(
          (sum, item) =>
            sum +
            num(
              item.reserved_units,
            ),
          0,
        );

      const requestedUnits =
        requestedByGroup.get(
          groupId,
        ) ?? 0;

      return {
        id: groupId,

        code: text(
          group.code,
        ),

        name: text(
          group.name,
        ),

        totalUnits,

        availableUnits,

        reservedUnits,

        requestedUnits,

        shortageUnits:
          Math.max(
            0,
            requestedUnits -
              availableUnits,
          ),
      };
    });

  const bloodNetwork = {
    totalUnits:
      bloodGroups.reduce(
        (sum, group) =>
          sum +
          group.totalUnits,
        0,
      ),

    availableUnits:
      bloodGroups.reduce(
        (sum, group) =>
          sum +
          group.availableUnits,
        0,
      ),

    reservedUnits:
      bloodGroups.reduce(
        (sum, group) =>
          sum +
          group.reservedUnits,
        0,
      ),

    bloodGroups,

    risk: {
      lowStockGroups:
        bloodGroups.filter(
          (group) =>
            group.availableUnits <=
            5,
        ).length,

      expiredUnits,

      expiringSoonUnits,

      shortageGroups:
        bloodGroups.filter(
          (group) =>
            group.shortageUnits >
            0,
        ).length,
    },
  };

  /*
   * -------------------------------------------------------
   * GENERIC STATUS COUNTS
   * -------------------------------------------------------
   */

  const statusCounts = (
    values: Row[],
  ) => ({
    pending:
      values.filter(
        (row) =>
          low(row.status) ===
          "pending",
      ).length,

    active:
      values.filter((row) =>
        [
          "active",
          "approved",
          "processing",
          "in_progress",
          "open",
        ].includes(
          low(row.status),
        ),
      ).length,

    completed:
      values.filter((row) =>
        [
          "completed",
          "fulfilled",
          "resolved",
        ].includes(
          low(row.status),
        ),
      ).length,

    cancelled:
      values.filter((row) =>
        [
          "cancelled",
          "rejected",
          "closed",
        ].includes(
          low(row.status),
        ),
      ).length,
  });

  /*
   * -------------------------------------------------------
   * BLOOD REQUESTS
   * -------------------------------------------------------
   */

  const requestCounts =
    statusCounts(R);

  const bloodRequests = {
    total: R.length,

    ...requestCounts,

    requestedUnits:
      R.reduce(
        (sum, request) =>
          sum +
          num(
            request.units_required,
          ),
        0,
      ),

    byBloodGroup:
      G.map((group) => {
        const groupId =
          text(group.id);

        const items =
          R.filter(
            (request) =>
              text(
                request.blood_group_id,
              ) === groupId,
          );

        return {
          code: text(
            group.code,
          ),

          name: text(
            group.name,
          ),

          requests:
            items.length,

          unitsRequired:
            items.reduce(
              (sum, request) =>
                sum +
                num(
                  request.units_required,
                ),
              0,
            ),
        };
      }),
  };

  /*
   * -------------------------------------------------------
   * DONORS
   * -------------------------------------------------------
   */

  const donorAvailable = (
    donor: Row,
  ): boolean => {
    const donorId =
      text(donor.id);

    const availability =
      latestAvailabilityMap.get(
        donorId,
      );

    if (availability) {
      return bool(
        availability.is_available,
      );
    }

    return bool(
      donor.is_available,
    );
  };

  const donationByGroup =
    G.map((group) => {
      const groupId =
        text(group.id);

      const items =
        DH.filter(
          (donation) =>
            text(
              donation.blood_group_id,
            ) === groupId,
        );

      return {
        code: text(
          group.code,
        ),

        name: text(
          group.name,
        ),

        donations:
          items.length,

        units:
          items.reduce(
            (sum, donation) =>
              sum +
              num(
                donation.units_donated,
              ),
            0,
          ),
      };
    });

  const donationDates =
    DH.map((item) =>
      Date.parse(
        text(
          item.donation_date,
        ),
      ),
    ).filter(
      Number.isFinite,
    );

  const donors = {
    total: D.length,

    available:
      D.filter(
        donorAvailable,
      ).length,

    unavailable:
      D.filter(
        (donor) =>
          !donorAvailable(donor),
      ).length,

    byBloodGroup:
      G.map((group) => {
        const groupId =
          text(group.id);

        const items =
          D.filter(
            (donor) =>
              text(
                donor.blood_group_id,
              ) === groupId,
          );

        return {
          code: text(
            group.code,
          ),

          name: text(
            group.name,
          ),

          total:
            items.length,

          available:
            items.filter(
              donorAvailable,
            ).length,
        };
      }),

    activity: {
      totalDonations:
        DH.length,

      verifiedDonations:
        DH.filter(
          (donation) =>
            bool(
              donation.verified,
            ),
        ).length,

      totalUnits:
        DH.reduce(
          (sum, donation) =>
            sum +
            num(
              donation.units_donated,
            ),
          0,
        ),

      lastDonationAt:
        donationDates.length
          ? new Date(
              Math.max(
                ...donationDates,
              ),
            ).toISOString()
          : null,

      recent30Days:
        DH.filter((donation) => {
          const donationDate =
            Date.parse(
              text(
                donation.donation_date,
              ),
            );

          return (
            Number.isFinite(
              donationDate,
            ) &&
            donationDate >=
              now -
                30 *
                  86400000
          );
        }).length,

      recent90Days:
        DH.filter((donation) => {
          const donationDate =
            Date.parse(
              text(
                donation.donation_date,
              ),
            );

          return (
            Number.isFinite(
              donationDate,
            ) &&
            donationDate >=
              now -
                90 *
                  86400000
          );
        }).length,

      byBloodGroup:
        donationByGroup,
    },
  };

  /*
   * -------------------------------------------------------
   * EMERGENCY SOS
   * -------------------------------------------------------
   *
   * Source of truth:
   *
   * public.emergency_sos
   *
   * No emergency_requests table is used.
   * -------------------------------------------------------
   */

  const emergencyCounts =
    statusCounts(E);

  const emergencyRecords =
    E.map((item) => {
      const city = item.city_id
        ? cityMap.get(
            text(item.city_id),
          )
        : undefined;

      const province =
        city?.province_id
          ? provinceMap.get(
              text(
                city.province_id,
              ),
            )
          : undefined;

      const group =
        item.blood_group_id
          ? groupMap.get(
              text(
                item.blood_group_id,
              ),
            )
          : undefined;

      return {
        id: text(
          item.id,
        ),

        cityName:
          text(city?.name) ||
          "Unknown",

        provinceName:
          text(province?.name) ||
          "Unknown",

        bloodGroup:
          text(group?.code) ||
          "—",

        unitsRequired:
          num(
            item.units_required,
          ),

        urgency:
          text(
            item.urgency_level,
          ) || "unknown",

        status:
          text(item.status) ||
          "unknown",

        createdAt:
          text(
            item.created_at,
          ),
      };
    }).sort(
      (a, b) =>
        Date.parse(
          b.createdAt,
        ) -
        Date.parse(
          a.createdAt,
        ),
    );

  const emergency = {
    total: E.length,

    pending:
      E.filter(
        (item) =>
          low(item.status) ===
          "pending",
      ).length,

    active:
      E.filter(
        (item) =>
          low(item.status) ===
          "active",
      ).length,

    resolved:
      emergencyCounts.completed,

    cancelled:
      emergencyCounts.cancelled,

    requestedUnits:
      E.reduce(
        (sum, item) =>
          sum +
          num(
            item.units_required,
          ),
        0,
      ),

    byUrgency:
      [
        "critical",
        "high",
        "medium",
        "low",
      ].map((urgency) => ({
        urgency,

        count:
          E.filter(
            (item) =>
              low(
                item.urgency_level,
              ) === urgency,
          ).length,
      })),

    records:
      emergencyRecords,
  };

  /*
   * -------------------------------------------------------
   * FACILITY HEALTH
   * -------------------------------------------------------
   *
   * IMPORTANT:
   *
   * All facility capability metrics are calculated from
   * VERIFIED parent organizations and DISTINCT organization
   * IDs.
   *
   * This prevents results such as:
   *
   * 3 hospitals in Organizations
   * but
   * 6 hospitals with emergency service.
   *
   * -------------------------------------------------------
   */

  const verifiedHospitalIds =
    new Set(
      orgs
        .filter(
          (organization) =>
            organization.organizationType ===
              "HOSPITAL" &&
            organization.verificationStatus ===
              "VERIFIED",
        )
        .map(
          (organization) =>
            organization.id,
        ),
    );

  const verifiedBankIds =
    new Set(
      orgs
        .filter(
          (organization) =>
            organization.organizationType ===
              "BLOOD_BANK" &&
            organization.verificationStatus ===
              "VERIFIED",
        )
        .map(
          (organization) =>
            organization.id,
        ),
    );

  const hospitalsWithEmergency =
    [...hospitalMap.entries()].filter(
      ([organizationId, hospital]) =>
        verifiedHospitalIds.has(
          organizationId,
        ) &&
        bool(
          hospital.emergency_service,
        ),
    ).length;

  const hospitalsWithBloodStorage =
    [...hospitalMap.entries()].filter(
      ([organizationId, hospital]) =>
        verifiedHospitalIds.has(
          organizationId,
        ) &&
        bool(
          hospital.blood_storage_available,
        ),
    ).length;

  const hospitalsWithIcu =
    [...hospitalMap.entries()].filter(
      ([organizationId, hospital]) =>
        verifiedHospitalIds.has(
          organizationId,
        ) &&
        bool(
          hospital.icu_available,
        ),
    ).length;

  const bloodBanksWithColdStorage =
    [...bankMap.entries()].filter(
      ([organizationId, bank]) =>
        verifiedBankIds.has(
          organizationId,
        ) &&
        bool(
          bank.cold_storage_available,
        ),
    ).length;

  const bloodBanksWithProcessing =
    [...bankMap.entries()].filter(
      ([organizationId, bank]) =>
        verifiedBankIds.has(
          organizationId,
        ) &&
        bool(
          bank.blood_processing_available,
        ),
    ).length;

  const citiesCovered =
    new Set(
      orgs
        .map(
          (organization) =>
            organization.cityId,
        )
        .filter(Boolean),
    ).size;

  const provincesCovered =
    new Set(
      orgs
        .map((organization) => {
          if (!organization.cityId) {
            return "";
          }

          const city =
            cityMap.get(
              organization.cityId,
            );

          return text(
            city?.province_id,
          );
        })
        .filter(Boolean),
    ).size;

  const facilityHealth = {
    verified:
      summary.verifiedOrganizations,

    pending:
      summary.pendingOrganizations,

    rejected:
      summary.rejectedOrganizations,

    hospitalsWithEmergency,

    hospitalsWithBloodStorage,

    hospitalsWithIcu,

    bloodBanksWithColdStorage,

    bloodBanksWithProcessing,

    citiesCovered,

    provincesCovered,
  };

  /*
   * -------------------------------------------------------
   * REGIONAL MONITORING
   * -------------------------------------------------------
   */

  const regional = P.map(
    (province) => {
      const provinceId =
        text(province.id);

      const provinceCities =
        C.filter(
          (city) =>
            text(
              city.province_id,
            ) === provinceId,
        );

      const cityIds =
        new Set(
          provinceCities.map(
            (city) =>
              text(city.id),
          ),
        );

      const provinceOrgs =
        orgs.filter(
          (organization) =>
            organization.cityId &&
            cityIds.has(
              organization.cityId,
            ),
        );

      const organizationIds =
        new Set(
          provinceOrgs.map(
            (organization) =>
              organization.id,
          ),
        );

      const provinceDonors =
        D.filter(
          (donor) =>
            donor.city_id &&
            cityIds.has(
              text(donor.city_id),
            ),
        );

      const provinceInventory =
        I.filter(
          (item) =>
            organizationIds.has(
              text(
                item.organization_id,
              ),
            ),
        );

      const provinceRequests =
        R.filter(
          (item) =>
            item.organization_id &&
            organizationIds.has(
              text(
                item.organization_id,
              ),
            ),
        );

      const provinceSos =
        E.filter(
          (item) =>
            item.city_id &&
            cityIds.has(
              text(item.city_id),
            ),
        );

      const hospitalIds =
        new Set(
          provinceOrgs
            .filter(
              (organization) =>
                organization.organizationType ===
                "HOSPITAL",
            )
            .map(
              (organization) =>
                organization.id,
            ),
        );

      const bloodBankIds =
        new Set(
          provinceOrgs
            .filter(
              (organization) =>
                organization.organizationType ===
                "BLOOD_BANK",
            )
            .map(
              (organization) =>
                organization.id,
            ),
        );

      return {
        id: provinceId,

        name: text(
          province.name,
        ),

        code: text(
          province.code,
        ),

        organizations:
          organizationIds.size,

        hospitals:
          hospitalIds.size,

        bloodBanks:
          bloodBankIds.size,

        donors:
          provinceDonors.length,

        availableDonors:
          provinceDonors.filter(
            donorAvailable,
          ).length,

        bloodUnits:
          provinceInventory.reduce(
            (sum, item) =>
              sum +
              num(
                item.total_units,
              ),
            0,
          ),

        availableUnits:
          provinceInventory.reduce(
            (sum, item) =>
              sum +
              num(
                item.available_units,
              ),
            0,
          ),

        bloodRequests:
          provinceRequests.length,

        requestedUnits:
          provinceRequests.reduce(
            (sum, item) =>
              sum +
              num(
                item.units_required,
              ),
            0,
          ),

        sos:
          provinceSos.length,

        activeSos:
          provinceSos.filter(
            (item) =>
              low(item.status) ===
              "active",
          ).length,
      };
    },
  );

  /*
   * -------------------------------------------------------
   * CITY INTELLIGENCE
   * -------------------------------------------------------
   *
   * All seeded cities remain available here.
   *
   * The client controls:
   *
   * - Search
   * - Province
   * - Active / All
   * - Sort
   * - Page size
   * - Pagination
   *
   * This means the server keeps the source data complete
   * while the Government UI remains compact.
   */

  const cities = C.map(
    (city) => {
      const cityId =
        text(city.id);

      const cityOrgs =
        orgs.filter(
          (organization) =>
            organization.cityId ===
            cityId,
        );

      const cityOrganizationIds =
        new Set(
          cityOrgs.map(
            (organization) =>
              organization.id,
          ),
        );

      const cityDonors =
        D.filter(
          (donor) =>
            text(
              donor.city_id,
            ) === cityId,
        );

      const cityInventory =
        I.filter(
          (item) =>
            cityOrganizationIds.has(
              text(
                item.organization_id,
              ),
            ),
        );

      const cityRequests =
        R.filter(
          (item) =>
            item.organization_id &&
            cityOrganizationIds.has(
              text(
                item.organization_id,
              ),
            ),
        );

      const citySos =
        E.filter(
          (item) =>
            text(
              item.city_id,
            ) === cityId,
        );

      const province =
        city.province_id
          ? provinceMap.get(
              text(
                city.province_id,
              ),
            )
          : undefined;

      const hospitalIds =
        new Set(
          cityOrgs
            .filter(
              (organization) =>
                organization.organizationType ===
                "HOSPITAL",
            )
            .map(
              (organization) =>
                organization.id,
            ),
        );

      const bloodBankIds =
        new Set(
          cityOrgs
            .filter(
              (organization) =>
                organization.organizationType ===
                "BLOOD_BANK",
            )
            .map(
              (organization) =>
                organization.id,
            ),
        );

      return {
        id: cityId,

        name:
          text(city.name),

        provinceName:
          text(
            province?.name,
          ) || "Unknown",

        organizations:
          cityOrganizationIds.size,

        hospitals:
          hospitalIds.size,

        bloodBanks:
          bloodBankIds.size,

        donors:
          cityDonors.length,

        availableDonors:
          cityDonors.filter(
            donorAvailable,
          ).length,

        availableUnits:
          cityInventory.reduce(
            (sum, item) =>
              sum +
              num(
                item.available_units,
              ),
            0,
          ),

        requestedUnits:
          cityRequests.reduce(
            (sum, item) =>
              sum +
              num(
                item.units_required,
              ),
            0,
          ),

        activeSos:
          citySos.filter(
            (item) =>
              low(item.status) ===
              "active",
          ).length,
      };
    },
  ).sort(
    (a, b) => {
      const activityA =
        a.organizations +
        a.donors +
        a.availableUnits +
        a.requestedUnits +
        a.activeSos;

      const activityB =
        b.organizations +
        b.donors +
        b.availableUnits +
        b.requestedUnits +
        b.activeSos;

      return (
        activityB -
        activityA
      );
    },
  );

  /*
   * -------------------------------------------------------
   * HISTORICAL ANALYTICS
   * -------------------------------------------------------
   *
   * Strictly sourced from:
   *
   * public.government_analytics
   *
   * No fake historical records are created.
   */

  const historical =
    GA.map((item) => ({
      metricName:
        text(
          item.metric_name,
        ),

      value:
        num(
          item.metric_value,
        ),

      region:
        item.region
          ? text(item.region)
          : null,

      generatedAt:
        text(
          item.generated_at,
        ),
    })).sort(
      (a, b) =>
        Date.parse(
          b.generatedAt,
        ) -
        Date.parse(
          a.generatedAt,
        ),
    );

  /*
   * -------------------------------------------------------
   * LIVE GOVERNMENT ANALYTICS
   * -------------------------------------------------------
   *
   * These values always represent the current
   * Supabase operational state.
   *
   * Nothing is inserted into government_analytics.
   */

  const liveAnalytics: GovernmentLiveAnalytics[] =
    [
      {
        metricName:
          "Total Organizations",
        value:
          summary.totalOrganizations,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Verified Organizations",
        value:
          summary.verifiedOrganizations,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Pending Organizations",
        value:
          summary.pendingOrganizations,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Rejected Organizations",
        value:
          summary.rejectedOrganizations,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Hospitals",
        value:
          summary.hospitals,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Blood Banks",
        value:
          summary.bloodBanks,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Available Blood Units",
        value:
          bloodNetwork.availableUnits,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Total Blood Units",
        value:
          bloodNetwork.totalUnits,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Reserved Blood Units",
        value:
          bloodNetwork.reservedUnits,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Blood Requests",
        value:
          bloodRequests.total,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Requested Blood Units",
        value:
          bloodRequests.requestedUnits,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Pending Blood Requests",
        value:
          bloodRequests.pending,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Active Blood Requests",
        value:
          bloodRequests.active,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Completed Blood Requests",
        value:
          bloodRequests.completed,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Cancelled Blood Requests",
        value:
          bloodRequests.cancelled,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Active SOS",
        value:
          emergency.active,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Pending SOS",
        value:
          emergency.pending,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Total SOS",
        value:
          emergency.total,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Resolved SOS",
        value:
          emergency.resolved,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Cancelled SOS",
        value:
          emergency.cancelled,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Registered Donors",
        value:
          donors.total,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Available Donors",
        value:
          donors.available,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Unavailable Donors",
        value:
          donors.unavailable,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Total Donations",
        value:
          donors.activity
            .totalDonations,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Verified Donations",
        value:
          donors.activity
            .verifiedDonations,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Donated Blood Units",
        value:
          donors.activity
            .totalUnits,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Low Stock Blood Groups",
        value:
          bloodNetwork.risk
            .lowStockGroups,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Shortage Blood Groups",
        value:
          bloodNetwork.risk
            .shortageGroups,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Expired Blood Units",
        value:
          bloodNetwork.risk
            .expiredUnits,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Expiring Soon Blood Units",
        value:
          bloodNetwork.risk
            .expiringSoonUnits,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Covered Cities",
        value:
          facilityHealth
            .citiesCovered,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Covered Provinces",
        value:
          facilityHealth
            .provincesCovered,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Verified Facilities",
        value:
          facilityHealth.verified,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },

      {
        metricName:
          "Pending Facilities",
        value:
          facilityHealth.pending,
        region: null,
        generatedAt:
          lastUpdatedAt,
      },
    ];

  const analyticsSource: GovernmentAnalyticsSource =
    historical.length > 0
      ? "HISTORICAL"
      : "LIVE";

  /*
   * -------------------------------------------------------
   * GOVERNMENT ALERTS
   * -------------------------------------------------------
   */

  const alerts: GovernmentData["alerts"] =
    [];

  if (
    bloodNetwork.risk
      .lowStockGroups > 0
  ) {
    alerts.push({
      type:
        "LOW_INVENTORY",

      severity:
        "critical",

      title:
        "Critical blood inventory",

      message:
        `${bloodNetwork.risk.lowStockGroups} blood group(s) have 5 or fewer available units.`,
    });
  }

  if (
    bloodNetwork.risk
      .shortageGroups > 0
  ) {
    alerts.push({
      type:
        "SUPPLY_SHORTAGE",

      severity:
        "critical",

      title:
        "Supply-demand shortage",

      message:
        `${bloodNetwork.risk.shortageGroups} blood group(s) have more requested units than available inventory.`,
    });
  }

  if (
    bloodNetwork.risk
      .expiredUnits > 0
  ) {
    alerts.push({
      type:
        "EXPIRED_INVENTORY",

      severity:
        "critical",

      title:
        "Expired inventory detected",

      message:
        `${bloodNetwork.risk.expiredUnits} available unit(s) have passed their recorded expiry date.`,
    });
  }

  if (
    bloodNetwork.risk
      .expiringSoonUnits > 0
  ) {
    alerts.push({
      type:
        "EXPIRING_INVENTORY",

      severity:
        "warning",

      title:
        "Inventory expiring soon",

      message:
        `${bloodNetwork.risk.expiringSoonUnits} available unit(s) expire within the next 7 days.`,
    });
  }

  if (
    emergency.active > 0
  ) {
    alerts.push({
      type:
        "ACTIVE_SOS",

      severity:
        emergency.active >= 5
          ? "critical"
          : "warning",

      title:
        "Active emergency SOS",

      message:
        `${emergency.active} emergency SOS request(s) currently require attention.`,
    });
  }

  if (
    summary.pendingOrganizations >
    0
  ) {
    alerts.push({
      type:
        "PENDING_ORGANIZATION",

      severity:
        summary.pendingOrganizations >=
        10
          ? "warning"
          : "info",

      title:
        "Pending organization reviews",

      message:
        `${summary.pendingOrganizations} organization registration(s) are waiting for review.`,
    });
  }

  if (
    bloodRequests.byBloodGroup.some(
      (item) =>
        item.unitsRequired >=
        20,
    )
  ) {
    alerts.push({
      type:
        "HIGH_DEMAND",

      severity:
        "warning",

      title:
        "High blood demand detected",

      message:
        "One or more blood groups have 20 or more requested units.",
    });
  }

  /*
   * -------------------------------------------------------
   * FINAL GOVERNMENT DATA
   * -------------------------------------------------------
   */

  return {
    organizations: orgs,

    summary,

    bloodNetwork,

    bloodRequests,

    emergency,

    donors,

    facilityHealth,

    regional,

    cities,

    historical,

    liveAnalytics,

    analyticsSource,

    lastUpdatedAt,

    alerts,
  };
}