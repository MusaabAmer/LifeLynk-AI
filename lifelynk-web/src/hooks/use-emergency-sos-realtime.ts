"use client";

import {
  useEffect,
} from "react";

import { createClient } from "@/lib/supabase/client";

export function useEmergencySosRealtime(
  onChange: () => void,
) {
  useEffect(() => {
    const supabase = createClient();

    const channel =
      supabase
        .channel(
          "emergency-sos-realtime",
        )
        .on(
          "postgres_changes",
          {
            event: "*",
            schema: "public",
            table: "emergency_sos",
          },
          () => {
            onChange();
          },
        )
        .subscribe();

    return () => {
      void supabase.removeChannel(
        channel,
      );
    };
  }, [onChange]);
}