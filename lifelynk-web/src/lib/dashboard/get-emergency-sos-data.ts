import { createClient } from "@/lib/supabase/server";
import type { WebRole } from "@/lib/auth/get-current-user";

export interface EmergencySosRecord {
  id: string;
  user_id: string;
  blood_group_id: string;
  city_id: string | null;
  units_required: number;
  urgency_level: string;
  description: string | null;
  status: string;
  created_at: string;
  latitude: number | null;
  longitude: number | null;
  gps_accuracy: number | null;
  location_timestamp: string | null;

  blood_groups:
    | {
        id: string;
        code: string;
        name: string;
      }[]
    | null;

  cities:
    | {
        id: string;
        name: string;
        provinces:
          | {
              id: string;
              name: string;
            }[]
          | null;
      }[]
    | null;

  users:
    | {
        id: string;
        email: string;
        full_name: string | null;
      }[]
    | null;
}

export interface EmergencySosSummary {
  total: number;
  active: number;
  pending: number;
  critical: number;
  resolved: number;
}

export interface EmergencySosData {
  records: EmergencySosRecord[];
  summary: EmergencySosSummary;
  error: string | null;
}

interface UserRow {
  id: string;
  email: string | null;
  full_name: string | null;
}

interface BloodGroupRow {
  id: string;
  code: string;
  name: string;
}

interface ProvinceRow {
  id: string;
  name: string;
}

interface CityRow {
  id: string;
  name: string;
  province_id: string | null;
}

interface SosBaseRow {
  id: string;
  user_id: string;
  blood_group_id: string;
  city_id: string | null;
  units_required: number;
  urgency_level: string;
  description: string | null;
  status: string;
  created_at: string;
  latitude: number | null;
  longitude: number | null;
  gps_accuracy: number | null;
  location_timestamp: string | null;
}

function normalizeString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeNullableString(
  value: unknown,
): string | null {
  const normalized = normalizeString(value);

  return normalized.length > 0 ? normalized : null;
}

function normalizeNumber(
  value: unknown,
): number | null {
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }

  if (
    typeof value === "string" &&
    value.trim().length > 0
  ) {
    const parsed = Number(value);

    return Number.isFinite(parsed) ? parsed : null;
  }

  return null;
}

function normalizeUser(
  row: Record<string, unknown>,
): UserRow | null {
  const id = normalizeString(row.id);

  if (!id) {
    return null;
  }

  return {
    id,
    email: normalizeNullableString(row.email),
    full_name: normalizeNullableString(row.full_name),
  };
}

function normalizeBloodGroup(
  row: Record<string, unknown>,
): BloodGroupRow | null {
  const id = normalizeString(row.id);

  if (!id) {
    return null;
  }

  return {
    id,
    code: normalizeString(row.code),
    name: normalizeString(row.name),
  };
}

function normalizeProvince(
  row: Record<string, unknown>,
): ProvinceRow | null {
  const id = normalizeString(row.id);

  if (!id) {
    return null;
  }

  return {
    id,
    name: normalizeString(row.name),
  };
}

function normalizeCity(
  row: Record<string, unknown>,
): CityRow | null {
  const id = normalizeString(row.id);

  if (!id) {
    return null;
  }

  return {
    id,
    name: normalizeString(row.name),
    province_id: normalizeNullableString(
      row.province_id,
    ),
  };
}

export async function getEmergencySosData(
  role: WebRole,
  organizationId: string | null,
  userId: string,
): Promise<EmergencySosData> {
  const supabase = await createClient();

  const emptySummary: EmergencySosSummary = {
    total: 0,
    active: 0,
    pending: 0,
    critical: 0,
    resolved: 0,
  };

  /*
   * ---------------------------------------------------------
   * AUTHORIZATION
   * ---------------------------------------------------------
   *
   * The database/RLS remains the authorization source.
   *
   * emergency_sos currently does not contain an
   * organization_id, so this function intentionally does
   * not invent organization-level ownership or assignment.
   *
   * role, organizationId, and userId are retained in the
   * function signature because the dashboard authorization
   * layer already provides them.
   */
  void role;
  void organizationId;
  void userId;

  /*
   * ---------------------------------------------------------
   * EMERGENCY SOS
   * ---------------------------------------------------------
   *
   * emergency_sos is the single source of truth.
   *
   * Do not replace this with another table such as
   * emergency_requests.
   */
  const {
    data: sosData,
    error: sosError,
  } = await supabase
    .from("emergency_sos")
    .select(`
      id,
      user_id,
      blood_group_id,
      city_id,
      units_required,
      urgency_level,
      description,
      status,
      created_at,
      latitude,
      longitude,
      gps_accuracy,
      location_timestamp
    `)
    .order("created_at", {
      ascending: false,
    });

  if (sosError) {
    console.error(
      "GET EMERGENCY SOS DATA ERROR:",
      sosError,
    );

    return {
      records: [],
      summary: emptySummary,
      error:
        sosError.message ||
        "Unable to load emergency SOS data.",
    };
  }

  const baseRecords =
    (sosData ?? []) as SosBaseRow[];

  if (baseRecords.length === 0) {
    return {
      records: [],
      summary: emptySummary,
      error: null,
    };
  }

  /*
   * ---------------------------------------------------------
   * COLLECT RELATED IDS
   * ---------------------------------------------------------
   */

  const userIds = Array.from(
    new Set(
      baseRecords
        .map((record) =>
          normalizeString(record.user_id),
        )
        .filter(Boolean),
    ),
  );

  const bloodGroupIds = Array.from(
    new Set(
      baseRecords
        .map((record) =>
          normalizeString(
            record.blood_group_id,
          ),
        )
        .filter(Boolean),
    ),
  );

  const cityIds = Array.from(
    new Set(
      baseRecords
        .map((record) =>
          normalizeString(record.city_id),
        )
        .filter(Boolean),
    ),
  );

  /*
   * ---------------------------------------------------------
   * USERS
   * ---------------------------------------------------------
   *
   * This query depends on the public.users SELECT RLS
   * policy allowing authorized healthcare users to view
   * SOS participants.
   *
   * If RLS blocks these rows, the SOS record itself remains
   * valid but the users relation will be null.
   */

  const usersById =
    new Map<string, UserRow>();

  if (userIds.length > 0) {
    const {
      data: userData,
      error: userError,
    } = await supabase
      .from("users")
      .select(
        "id, email, full_name",
      )
      .in("id", userIds);

    if (userError) {
      console.error(
        "GET EMERGENCY SOS USERS ERROR:",
        userError,
      );
    } else {
      for (const raw of userData ?? []) {
        const normalized =
          normalizeUser(
            raw as Record<string, unknown>,
          );

        if (normalized) {
          usersById.set(
            normalized.id,
            normalized,
          );
        }
      }
    }
  }

  /*
   * ---------------------------------------------------------
   * BLOOD GROUPS
   * ---------------------------------------------------------
   */

  const bloodGroupsById =
    new Map<string, BloodGroupRow>();

  if (bloodGroupIds.length > 0) {
    const {
      data: bloodGroupData,
      error: bloodGroupError,
    } = await supabase
      .from("blood_groups")
      .select(
        "id, code, name",
      )
      .in(
        "id",
        bloodGroupIds,
      );

    if (bloodGroupError) {
      console.error(
        "GET EMERGENCY SOS BLOOD GROUPS ERROR:",
        bloodGroupError,
      );
    } else {
      for (const raw of bloodGroupData ?? []) {
        const normalized =
          normalizeBloodGroup(
            raw as Record<string, unknown>,
          );

        if (normalized) {
          bloodGroupsById.set(
            normalized.id,
            normalized,
          );
        }
      }
    }
  }

  /*
   * ---------------------------------------------------------
   * CITIES
   * ---------------------------------------------------------
   */

  const citiesById =
    new Map<string, CityRow>();

  const provinceIds =
    new Set<string>();

  if (cityIds.length > 0) {
    const {
      data: cityData,
      error: cityError,
    } = await supabase
      .from("cities")
      .select(
        "id, name, province_id",
      )
      .in("id", cityIds);

    if (cityError) {
      console.error(
        "GET EMERGENCY SOS CITIES ERROR:",
        cityError,
      );
    } else {
      for (const raw of cityData ?? []) {
        const normalized =
          normalizeCity(
            raw as Record<string, unknown>,
          );

        if (!normalized) {
          continue;
        }

        citiesById.set(
          normalized.id,
          normalized,
        );

        if (normalized.province_id) {
          provinceIds.add(
            normalized.province_id,
          );
        }
      }
    }
  }

  /*
   * ---------------------------------------------------------
   * PROVINCES
   * ---------------------------------------------------------
   */

  const provincesById =
    new Map<string, ProvinceRow>();

  if (provinceIds.size > 0) {
    const {
      data: provinceData,
      error: provinceError,
    } = await supabase
      .from("provinces")
      .select(
        "id, name",
      )
      .in(
        "id",
        Array.from(provinceIds),
      );

    if (provinceError) {
      console.error(
        "GET EMERGENCY SOS PROVINCES ERROR:",
        provinceError,
      );
    } else {
      for (const raw of provinceData ?? []) {
        const normalized =
          normalizeProvince(
            raw as Record<string, unknown>,
          );

        if (normalized) {
          provincesById.set(
            normalized.id,
            normalized,
          );
        }
      }
    }
  }

  /*
   * ---------------------------------------------------------
   * NORMALIZED CLIENT CONTRACT
   * ---------------------------------------------------------
   */

  const records: EmergencySosRecord[] =
    baseRecords.map((record) => {
      const user =
        usersById.get(
          normalizeString(
            record.user_id,
          ),
        );

      const bloodGroup =
        bloodGroupsById.get(
          normalizeString(
            record.blood_group_id,
          ),
        );

      const city =
        record.city_id
          ? citiesById.get(
              normalizeString(
                record.city_id,
              ),
            )
          : undefined;

      const province =
        city?.province_id
          ? provincesById.get(
              city.province_id,
            )
          : undefined;

      return {
        id: record.id,

        user_id:
          record.user_id,

        blood_group_id:
          record.blood_group_id,

        city_id:
          record.city_id,

        units_required:
          record.units_required,

        urgency_level:
          record.urgency_level,

        description:
          record.description,

        status:
          record.status,

        created_at:
          record.created_at,

        latitude:
          normalizeNumber(
            record.latitude,
          ),

        longitude:
          normalizeNumber(
            record.longitude,
          ),

        gps_accuracy:
          normalizeNumber(
            record.gps_accuracy,
          ),

        location_timestamp:
          record.location_timestamp,

        users: user
          ? [
              {
                id: user.id,
                email:
                  user.email ?? "",
                full_name:
                  user.full_name,
              },
            ]
          : null,

        blood_groups:
          bloodGroup
            ? [
                {
                  id:
                    bloodGroup.id,
                  code:
                    bloodGroup.code,
                  name:
                    bloodGroup.name,
                },
              ]
            : null,

        cities: city
          ? [
              {
                id: city.id,
                name: city.name,
                provinces:
                  province
                    ? [
                        {
                          id:
                            province.id,
                          name:
                            province.name,
                        },
                      ]
                    : null,
              },
            ]
          : null,
      };
    });

  /*
   * ---------------------------------------------------------
   * SUMMARY
   * ---------------------------------------------------------
   */

  const summary: EmergencySosSummary = {
    total:
      records.length,

    active:
      records.filter((record) => {
        const status =
          normalizeString(
            record.status,
          ).toLowerCase();

        return (
          status === "pending" ||
          status === "matched" ||
          status === "in_progress"
        );
      }).length,

    pending:
      records.filter(
        (record) =>
          normalizeString(
            record.status,
          ).toLowerCase() ===
          "pending",
      ).length,

    critical:
      records.filter((record) => {
        const urgency =
          normalizeString(
            record.urgency_level,
          ).toLowerCase();

        return (
          urgency === "critical" ||
          urgency === "emergency"
        );
      }).length,

    resolved:
      records.filter(
        (record) =>
          normalizeString(
            record.status,
          ).toLowerCase() ===
          "completed",
      ).length,
  };

  return {
    records,
    summary,
    error: null,
  };
}

