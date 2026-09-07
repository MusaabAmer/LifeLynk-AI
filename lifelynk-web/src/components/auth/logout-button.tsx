"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function LogoutButton() {
  const router = useRouter();

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleLogout() {
    if (loading) return;

    setLoading(true);
    setError("");

    try {
      const supabase = createClient();

      const { error: signOutError } =
        await supabase.auth.signOut();

      if (signOutError) {
        console.error(
          "Logout failed:",
          signOutError,
        );

        setError(
          "Unable to sign out. Please try again.",
        );

        return;
      }

      router.replace("/login");
      router.refresh();
    } catch (error) {
      console.error(
        "Unexpected logout error:",
        error,
      );

      setError(
        "Something went wrong while signing out.",
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <button
        type="button"
        onClick={handleLogout}
        disabled={loading}
        className="lifelynk-button lifelynk-button--primary"
        aria-label="Sign out"
      >
        {loading
          ? "Signing out..."
          : "Sign out"}
      </button>

      {error && (
        <p
          role="alert"
          style={{
            marginTop: "8px",
            color: "var(--lifelynk-red)",
            fontSize: "13px",
          }}
        >
          {error}
        </p>
      )}
    </div>
  );
}