"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

import { createClient } from "@/lib/supabase/client";

interface VerificationPendingRealtimeProps {
  organizationId: string;
}

export default function VerificationPendingRealtime({
  organizationId,
}: VerificationPendingRealtimeProps) {
  const router = useRouter();

  useEffect(() => {
    const supabase = createClient();

    let mounted = true;

    /*
     * ---------------------------------------------------------
     * Initial status check
     * ---------------------------------------------------------
     *
     * This handles the case where the organization was
     * verified immediately before the realtime subscription
     * became active.
     */
    async function checkVerificationStatus() {
      const { data, error } = await supabase
        .from("organizations")
        .select("verification_status")
        .eq("id", organizationId)
        .maybeSingle();

      if (!mounted || error || !data) {
        return;
      }

      if (data.verification_status === "VERIFIED") {
        router.replace("/dashboard");
        router.refresh();
        return;
      }

      if (data.verification_status === "REJECTED") {
        router.replace(
          "/organization-verification/rejected",
        );
        router.refresh();
      }
    }

    checkVerificationStatus();

    /*
     * ---------------------------------------------------------
     * Supabase Realtime
     * ---------------------------------------------------------
     *
     * Listen specifically to this organization's row.
     */
    const channel = supabase
      .channel(
        `organization-verification-${organizationId}`,
      )
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "organizations",
          filter: `id=eq.${organizationId}`,
        },
        (payload) => {
          if (!mounted) {
            return;
          }

          const newStatus =
            payload.new?.verification_status;

          if (newStatus === "VERIFIED") {
            router.replace("/dashboard");
            router.refresh();
            return;
          }

          if (newStatus === "REJECTED") {
            router.replace(
              "/organization-verification/rejected",
            );
            router.refresh();
          }
        },
      )
      .subscribe();

    /*
     * ---------------------------------------------------------
     * Cleanup
     * ---------------------------------------------------------
     */
    return () => {
      mounted = false;
      supabase.removeChannel(channel);
    };
  }, [organizationId, router]);

  return null;
}