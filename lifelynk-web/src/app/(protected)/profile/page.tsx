import { redirect } from "next/navigation";

import { getCurrentUser } from "@/lib/auth/get-current-user";
import { getProfileData } from "@/lib/dashboard/get-profile-data";

import ProfileClient from "./profile-client";

export default async function ProfilePage() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect("/login");
  }

  const profile = await getProfileData(
    currentUser.id,
  );

  if (!profile) {
    return (
      <div className="profile-page">
        <div className="profile-state profile-state--error">
          <h1>Unable to load profile</h1>
          <p>
            We could not load your LifeLynk
            account information.
          </p>
        </div>
      </div>
    );
  }

  return (
    <ProfileClient
      profile={profile}
    />
  );
}