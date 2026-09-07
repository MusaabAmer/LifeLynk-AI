"use client";

import {
  createContext,
  ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";

import { createClient } from "@/lib/supabase/client";

interface NotificationContextValue {
  unreadCount: number;
  refreshUnreadCount: () => Promise<void>;
}

const NotificationContext =
  createContext<NotificationContextValue | null>(
    null,
  );

interface NotificationProviderProps {
  children: ReactNode;
  userId: string;
}

export default function NotificationProvider({
  children,
  userId,
}: NotificationProviderProps) {
  const [unreadCount, setUnreadCount] =
    useState(0);

  const supabase = useMemo(
    () => createClient(),
    [],
  );

  /*
   * ------------------------------------------------------------
   * LOAD CURRENT UNREAD COUNT
   * ------------------------------------------------------------
   */

  const refreshUnreadCount =
    useCallback(async () => {
      const { count, error } =
        await supabase
          .from("notifications")
          .select("id", {
            count: "exact",
            head: true,
          })
          .eq("user_id", userId)
          .eq("is_read", false);

      if (error) {
        console.error(
          "NOTIFICATIONS - UNREAD COUNT ERROR",
          error,
        );

        return;
      }

      setUnreadCount(count ?? 0);
    }, [supabase, userId]);

  /*
   * ------------------------------------------------------------
   * REALTIME
   * ------------------------------------------------------------
   */

  useEffect(() => {
    let cancelled = false;

    const channelName =
      `notifications-${userId}`;

    async function setupRealtime() {
      /*
       * Remove an existing channel with the same name.
       */
      const existingChannel =
        supabase
          .getChannels()
          .find(
            (channel) =>
              channel.topic ===
              `realtime:${channelName}`,
          );

      if (existingChannel) {
        await supabase.removeChannel(
          existingChannel,
        );
      }

      if (cancelled) {
        return;
      }

      /*
       * Initial authoritative count.
       */
      await refreshUnreadCount();

      if (cancelled) {
        return;
      }

      /*
       * Register ALL listeners before subscribe().
       */
      const channel = supabase
        .channel(channelName)

        /*
         * ------------------------------------------------------
         * INSERT
         * ------------------------------------------------------
         */
        .on(
          "postgres_changes",
          {
            event: "INSERT",
            schema: "public",
            table: "notifications",
            filter: `user_id=eq.${userId}`,
          },
          () => {
            if (cancelled) {
              return;
            }

            /*
             * Supabase is the source of truth.
             */
            void refreshUnreadCount();
          },
        )

        /*
         * ------------------------------------------------------
         * UPDATE
         * ------------------------------------------------------
         *
         * Handles:
         *
         * false -> true
         * true  -> false
         */
        .on(
          "postgres_changes",
          {
            event: "UPDATE",
            schema: "public",
            table: "notifications",
            filter: `user_id=eq.${userId}`,
          },
          () => {
            if (cancelled) {
              return;
            }

            void refreshUnreadCount();
          },
        )

        /*
         * ------------------------------------------------------
         * DELETE
         * ------------------------------------------------------
         */
        .on(
          "postgres_changes",
          {
            event: "DELETE",
            schema: "public",
            table: "notifications",
            filter: `user_id=eq.${userId}`,
          },
          () => {
            if (cancelled) {
              return;
            }

            void refreshUnreadCount();
          },
        );

      /*
       * --------------------------------------------------------
       * SUBSCRIBE
       * --------------------------------------------------------
       */

      channel.subscribe((status) => {
        console.log(
          "NOTIFICATIONS - REALTIME STATUS:",
          status,
        );

        if (
          status === "SUBSCRIBED" &&
          !cancelled
        ) {
          void refreshUnreadCount();
        }
      });
    }

    void setupRealtime();

    /*
     * ----------------------------------------------------------
     * CLEANUP
     * ----------------------------------------------------------
     */

    return () => {
      cancelled = true;

      const channel =
        supabase
          .getChannels()
          .find(
            (item) =>
              item.topic ===
              `realtime:${channelName}`,
          );

      if (channel) {
        void supabase.removeChannel(
          channel,
        );
      }
    };
  }, [
    supabase,
    userId,
    refreshUnreadCount,
  ]);

  /*
   * ------------------------------------------------------------
   * CONTEXT VALUE
   * ------------------------------------------------------------
   */

  const value = useMemo(
    () => ({
      unreadCount,
      refreshUnreadCount,
    }),
    [
      unreadCount,
      refreshUnreadCount,
    ],
  );

  return (
    <NotificationContext.Provider
      value={value}
    >
      {children}
    </NotificationContext.Provider>
  );
}

export function useNotifications() {
  const context =
    useContext(NotificationContext);

  if (!context) {
    throw new Error(
      "useNotifications must be used inside NotificationProvider",
    );
  }

  return context;
}