import { redirect } from "next/navigation";

import { getCurrentUser } from "@/lib/auth/get-current-user";
import { getGovernmentData } from "@/lib/dashboard/get-government-data";

import GovernmentClient from "./government-client";
import "./government.css";

export default async function GovernmentPage() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect("/login");
  }

  if (
    currentUser.role !== "GOVERNMENT_ADMIN" &&
    currentUser.role !== "SUPER_ADMIN"
  ) {
    redirect("/dashboard");
  }

  const data = await getGovernmentData();

  return (
    <GovernmentClient
      data={data}
      currentUser={currentUser}
    />
  );
}