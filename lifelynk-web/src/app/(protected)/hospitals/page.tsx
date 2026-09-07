import { getCurrentUser } from "@/lib/auth/get-current-user";
import { redirect } from "next/navigation";

import {
  getHospitalsData,
} from "@/lib/dashboard/get-hospitals-data";

import HospitalsClient from "./hospitals-client";

import "./hospitals.css";

/* =========================================================
   PAGE
   ========================================================= */

export default async function HospitalsPage() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect("/login");
  }

  const {
    hospitals,
    stats,
    error,
  } = await getHospitalsData(
    currentUser.role,
    currentUser.organizationId,
  );

  return (
    <HospitalsClient
      facilities={hospitals}
      stats={stats}
      error={error}
      role={currentUser.role}
    />
  );
}