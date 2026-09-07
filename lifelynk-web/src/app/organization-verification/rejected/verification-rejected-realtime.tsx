"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

import { createClient } from "@/lib/supabase/client";

interface VerificationRejectedRealtimeProps {
  organizationId: string;
}

export default function VerificationRejectedRealtime({
  organizationId,
}: VerificationRejectedRealtimeProps) {
  const router = useRouter();

  useEffect(() => {
    const supabase = createClient();

    let mounted = true;

    /*
     * ---------------------------------------------------------
     * INITIAL STATUS CHECK
     * ---------------------------------------------------------
     *
     * Handles the case where the organization status changed
     * immediately before the realtime subscription started.
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

      if (
        data.verification_status ===
        "VERIFIED"
      ) {
        router.replace("/dashboard");
        router.refresh();
        return;
      }

      if (
        data.verification_status ===
        "PENDING"
      ) {
        router.replace(
          "/organization-verification/pending",
        );
        router.refresh();
      }
    }

    checkVerificationStatus();

    /*
     * ---------------------------------------------------------
     * SUPABASE REALTIME
     * ---------------------------------------------------------
     *
     * Listen only to this organization's row.
     */
    const channel = supabase
      .channel(
        `organization-rejected-${organizationId}`,
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

          if (
            newStatus === "VERIFIED"
          ) {
            router.replace("/dashboard");
            router.refresh();
            return;
          }

          if (
            newStatus === "PENDING"
          ) {
            router.replace(
              "/organization-verification/pending",
            );
            router.refresh();
          }
        },
      )
      .subscribe();

    /*
     * ---------------------------------------------------------
     * CLEANUP
     * ---------------------------------------------------------
     */
    return () => {
      mounted = false;
      supabase.removeChannel(channel);
    };
  }, [organizationId, router]);

  return null;
}