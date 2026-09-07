import { createClient } from "@/lib/supabase/server";

/* =========================================================
   TYPES
   ========================================================= */

export interface DonorRecord {
  id: string;
  user_id: string;
  blood_group_id: string;
  city_id: string;
  /*
   * PII — fetched because availability workflows depend on it,
   * but the UI only ever renders a masked form (last 4 digits).
   */
  phone_number: string;
  /*
   * PII — never rendered directly. The UI computes and shows
   * the donor's age instead of the raw date of birth.
   */
  date_of_birth: string;
  gender: string;
  is_available: boolean;
  total_donations: number;
  last_donation_date: string | null;
  created_at: string;
  updated_at: string;
  blood_groups: {
    id: string;
    code: string;
    name: string;
  };
  cities: {
    id: string;
    name: string;
    provinces: {
      id: string;
      name: string;
    };
  };
  users: {
    id: string;
    full_name: string;
  };
}

export interface DonorsSummary {
  totalDonors: number;
  availableDonors: number;
  unavailableDonors: number;
  bloodGroupCount: number;
  cityCount: number;
}

export interface DonorsData {
  records: DonorRecord[];
  bloodGroups: Array<{ id: string; code: string; name: string }>;
  summary: DonorsSummary;
  /*
   * Follows the get-blood-inventory-data.ts pattern: the flag
   * lets the page distinguish a failed fetch (error state)
   * from a legitimately empty donor registry (empty state).
   */
  error: boolean;
}

/* =========================================================
   EMPTY PAYLOAD
   ========================================================= */

const EMPTY_SUMMARY: DonorsSummary = {
  totalDonors: 0,
  availableDonors: 0,
  unavailableDonors: 0,
  bloodGroupCount: 0,
  cityCount: 0,
};

/* =========================================================
   DATA FETCHER
   ========================================================= */

export async function getDonorsData(): Promise<DonorsData> {
  const supabase = await createClient();

  /*
   * --------------------------------------------------
   * 1. Blood group reference data
   * --------------------------------------------------
   *
   * blood_groups supports soft delete (deleted_at), so
   * soft-deleted groups are excluded from the reference list
   * used by the blood group filter.
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
      "DONORS - BLOOD GROUPS QUERY ERROR",
      bloodGroupsError,
    );
  }

  /*
   * --------------------------------------------------
   * 2. Donor records
   * --------------------------------------------------
   *
   * donors has NO deleted_at column (no soft delete), so no
   * soft-delete filter is applied.
   *
   * Only the donors table (with joins) is queried:
   *   - donor_profiles is NOT queried — its RLS policies
   *     block dashboard access entirely.
   *   - donation_history is NOT queried — that table has no
   *     RLS, so reading it from the web client would be a
   *     security concern.
   *
   * Ordering: available donors first (operational priority
   * for matching), then newest registrations first.
   *
   * Visibility is controlled entirely by Supabase RLS.
   */

  const { data, error } = await supabase
    .from("donors")
    .select(`
      *,
      blood_groups(id, code, name),
      cities(id, name, provinces(id, name)),
      users(id, full_name)
    `)
    .order("is_available", { ascending: false })
    .order("created_at", { ascending: false });

  if (error) {
    console.error(
      "DONORS - QUERY ERROR",
      error,
    );

    return {
      records: [],
      bloodGroups: [],
      summary: EMPTY_SUMMARY,
      error: true,
    };
  }

  /*
   * --------------------------------------------------
   * 3. Cast rows
   * --------------------------------------------------
   */

  const records = (data ?? []) as unknown as DonorRecord[];

  /*
   * --------------------------------------------------
   * 4. Summary stats
   * --------------------------------------------------
   */

  const availableDonors = records.filter(
    (record) => record.is_available,
  ).length;

  const summary: DonorsSummary = {
    totalDonors: records.length,

    availableDonors,

    unavailableDonors:
      records.length - availableDonors,

    bloodGroupCount: new Set(
      records.map((record) => record.blood_group_id),
    ).size,

    cityCount: new Set(
      records.map((record) => record.city_id),
    ).size,
  };

  return {
    records,

    bloodGroups:
      (bloodGroupsData ?? []) as unknown as Array<{
        id: string;
        code: string;
        name: string;
      }>,

    summary,

    /*
     * A failed blood_groups lookup only degrades the filter
     * reference list — the donor records can still render —
     * so only a donors query failure is treated as a hard
     * error above.
     */
    error: bloodGroupsError ? true : false,
  };
}