import { getCurrentUser } from "@/lib/auth/get-current-user";
import { redirect } from "next/navigation";
import { getBloodRequestsData } from "@/lib/dashboard/get-blood-requests-data";
import type { BloodRequestsData } from "@/lib/dashboard/get-blood-requests-data";
import BloodRequestsClient from "./blood-requests-client";
import "./blood-requests.css";

/* =========================================================
   PAGE (server component)
   =========================================================
 *
 * Server component fetches the data (RLS scopes visibility),
 * then hands it to the client component which owns all the
 * interactivity: filtering, and CRUD for roles permitted by
 * the blood_requests RLS policies.
 */

export default async function BloodRequestsPage() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect("/login");
  }

  let requestsData: BloodRequestsData;

  try {
    requestsData = await getBloodRequestsData(
      currentUser.role,
      currentUser.organizationId,
      currentUser.id,
    );
  } catch (error) {
    console.error(
      "BLOOD REQUESTS PAGE - DATA FETCH ERROR",
      error,
    );

    requestsData = {
      records: [],
      bloodGroups: [],
      patients: [],
      summary: {
        totalRequests: 0,
        pendingCount: 0,
        urgentCount: 0,
        fulfilledCount: 0,
      },
      error: true,
    };
  }

  return (
    <BloodRequestsClient
      data={requestsData}
      currentUser={currentUser}
    />
  );
}
