import { redirect } from "next/navigation";

import { getCurrentUser } from "@/lib/auth/get-current-user";
import { getEmergencySosData } from "@/lib/dashboard/get-emergency-sos-data";

import EmergencySosClient from "./emergency-sos-client";
import "./emergency-sos.css";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export default async function EmergencySosPage() {
  const user = await getCurrentUser();

  if (!user) {
    redirect("/login");
  }

  const data = await getEmergencySosData(
    user.role,
    user.organizationId,
    user.id,
  );

  return (
    <EmergencySosClient
      data={data}
      userRole={user.role}
    />
  );
}

