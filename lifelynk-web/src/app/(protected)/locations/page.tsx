import { redirect } from "next/navigation";

import { getCurrentUser } from "@/lib/auth/get-current-user";
import { getLocationsData } from "@/lib/dashboard/get-locations-data";
import LocationsClient from "./locations-client";
import "./locations.css";

export default async function LocationsPage() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect("/login");
  }

  let locationsData;

  try {
    locationsData = await getLocationsData();
  } catch (error) {
    console.error(
      "LOCATIONS PAGE - DATA FETCH ERROR",
      error,
    );

    locationsData = {
      provinces: [],
      cities: [],
      organizations: [],
      summary: {
        totalProvinces: 0,
        totalCities: 0,
        totalOrganizations: 0,
        totalHospitals: 0,
        totalBloodBanks: 0,
      },
    };
  }

  return (
    <LocationsClient
      data={locationsData}
      currentUser={currentUser}
    />
  );
}
