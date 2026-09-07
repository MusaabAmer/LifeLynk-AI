import { redirect } from "next/navigation";

import { getCurrentUser } from "@/lib/auth/get-current-user";

import NotificationsClient from "./notifications-client";

export default async function NotificationsPage() {
  const user = await getCurrentUser();

  if (!user) {
    redirect("/login");
  }

  return <NotificationsClient userId={user.id} />;
}
