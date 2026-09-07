import { createClient } from "@/lib/supabase/server";

export interface Province {
  id: string;
  name: string;
  code: string;
}

export interface City {
  id: string;
  name: string;
  code: string;
  province_id: string;
  latitude: number | null;
  longitude: number | null;
}

export interface LocationOrganization {
  id: string;
  name: string;
  organization_type: string;
  phone: string;
  email: string | null;
  address: string;
  verification_status: string;
  city_id: string;
}

export interface LocationsData {
  provinces: Province[];
  cities: City[];
  organizations: LocationOrganization[];
  summary: {
    totalProvinces: number;
    totalCities: number;
    totalOrganizations: number;
    totalHospitals: number;
    totalBloodBanks: number;
  };
}

export async function getLocationsData(): Promise<LocationsData> {
  const supabase = await createClient();

  /*
   * --------------------------------------------------
   * PROVINCES
   * --------------------------------------------------
   */

  const {
    data: provinces,
    error: provincesError,
  } = await supabase
    .from("provinces")
    .select("id, name, code")
    .eq("is_active", true)
    .is("deleted_at", null)
    .order("name");

  if (provincesError) {
    console.error(
      "LOCATIONS - PROVINCES ERROR",
      provincesError,
    );
  }

  /*
   * --------------------------------------------------
   * CITIES
   * --------------------------------------------------
   */

  const {
    data: cities,
    error: citiesError,
  } = await supabase
    .from("cities")
    .select(
      "id, name, code, province_id, latitude, longitude",
    )
    .eq("is_active", true)
    .is("deleted_at", null)
    .order("name");

  if (citiesError) {
    console.error(
      "LOCATIONS - CITIES ERROR",
      citiesError,
    );
  }

  /*
   * --------------------------------------------------
   * ORGANIZATIONS
   * --------------------------------------------------
   *
   * Fetch VERIFIED organizations only.
   * RLS controls visibility: authenticated users see
   * VERIFIED orgs or their own via membership.
   */

  const {
    data: organizations,
    error: orgsError,
  } = await supabase
    .from("organizations")
    .select(
      `
        id,
        name,
        organization_type,
        phone,
        email,
        address,
        verification_status,
        city_id
      `,
    )
    .eq(
      "verification_status",
      "VERIFIED",
    )
    .is("deleted_at", null)
    .order("name");

  if (orgsError) {
    console.error(
      "LOCATIONS - ORGANIZATIONS ERROR",
      orgsError,
    );
  }

  /*
   * --------------------------------------------------
   * SUMMARY
   * --------------------------------------------------
   */

  const resolvedOrgs = organizations ?? [];
  const totalHospitals = resolvedOrgs.filter(
    (o) =>
      o.organization_type === "HOSPITAL",
  ).length;
  const totalBloodBanks = resolvedOrgs.filter(
    (o) =>
      o.organization_type === "BLOOD_BANK",
  ).length;

  return {
    provinces: provinces ?? [],
    cities: cities ?? [],
    organizations: resolvedOrgs.map((o) => ({
      id: o.id,
      name: o.name,
      organization_type: o.organization_type,
      phone: o.phone,
      email: o.email,
      address: o.address,
      verification_status: o.verification_status,
      city_id: o.city_id,
    })),
    summary: {
      totalProvinces:
        provinces?.length ?? 0,
      totalCities:
        cities?.length ?? 0,
      totalOrganizations:
        resolvedOrgs.length,
      totalHospitals,
      totalBloodBanks,
    },
  };
}
