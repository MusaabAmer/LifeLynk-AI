import { getCurrentUser } from "@/lib/auth/get-current-user";
import { redirect } from "next/navigation";
import { getBloodInventoryData } from "@/lib/dashboard/get-blood-inventory-data";
import type { BloodInventoryData } from "@/lib/dashboard/get-blood-inventory-data";
import BloodInventoryClient from "./blood-inventory-client";
import "./blood-inventory.css";

/* =========================================================
   PAGE (server component)
   =========================================================
 *
 * Server component fetches the data (RLS scopes visibility),
 * then hands it to the client component which owns all the
 * interactivity: filtering, and CRUD for roles permitted by
 * the blood_inventory RLS policies.
 */

export default async function BloodInventoryPage() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect("/login");
  }

  let inventoryData: BloodInventoryData;

  try {
    inventoryData = await getBloodInventoryData(
      currentUser.role,
      currentUser.organizationId,
    );
  } catch (error) {
    console.error(
      "BLOOD INVENTORY PAGE - DATA FETCH ERROR",
      error,
    );

    inventoryData = {
      records: [],
      bloodGroups: [],
      groupSummaries: [],
      summary: {
        totalRecords: 0,
        totalAvailableUnits: 0,
        totalReservedUnits: 0,
        totalUnits: 0,
        bloodGroupCount: 0,
        organizationCount: 0,
      },
      error: true,
    };
  }

  return (
    <BloodInventoryClient
      data={inventoryData}
      currentUser={currentUser}
    />
  );
}
