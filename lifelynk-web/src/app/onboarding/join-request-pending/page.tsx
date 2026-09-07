
import { redirect } from "next/navigation";

import "../onboarding.css";

import { getCurrentUser } from "@/lib/auth/get-current-user";

import JoinRequestPendingClient from "./join-request-pending-client";

interface JoinRequestPendingPageProps {
  searchParams: Promise<{
    organization?: string;
  }>;
}

export default async function JoinRequestPendingPage({
  searchParams,
}: JoinRequestPendingPageProps) {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect("/login");
  }

  if (
    currentUser.role === "SUPER_ADMIN" ||
    currentUser.role === "GOVERNMENT_ADMIN"
  ) {
    redirect("/dashboard");
  }

  const params = await searchParams;

  return (
    <JoinRequestPendingClient
      organizationName={
        params.organization ||
        "your organization"
      }
    />
  );
}

