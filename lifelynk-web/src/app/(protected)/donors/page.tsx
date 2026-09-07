import { getCurrentUser } from "@/lib/auth/get-current-user";
import { redirect } from "next/navigation";
import { getDonorsData } from "@/lib/dashboard/get-donors-data";
import type { DonorsData } from "@/lib/dashboard/get-donors-data";
import DonorsClient from "./donors-client";
import "./donors.css";

/* =========================================================
   PAGE (server component)
   =========================================================
 *
 * Server component fetches the data — the donors RLS
 * policies scope visibility per role (SUPER_ADMIN and
 * GOVERNMENT_ADMIN see all donors; organization roles see
 * available donors only) — then hands it to the client
 * component which owns all interactivity: filtering plus
 * the limited SUPER_ADMIN edit.
 *
 * The DONOR role never reaches this page: WebRole excludes
 * it, and the (protected) layout redirects any non-web
 * role before this component renders.
 */

export default async function DonorsPage() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect("/login");
  }

  let donorsData: DonorsData;

  try {
    donorsData = await getDonorsData()
  } catch (error) {
    console.error(
      "DONORS PAGE - DATA FETCH ERROR",
      error,
    );

    donorsData = {
      records: [],
      bloodGroups: [],
      summary: {
        totalDonors: 0,
        availableDonors: 0,
        unavailableDonors: 0,
        bloodGroupCount: 0,
        cityCount: 0,
      },
      error: true,
    };
  }

  return (
    <DonorsClient
      data={donorsData}
      currentUser={currentUser}
    />
  );
}
