"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import { createClient } from "@/lib/supabase/client";

import "./notifications.css";

interface NotificationRecord {
  id: string;
  user_id: string;
  title: string;
  message: string;
  notification_type: string;
  is_read: boolean;
  created_at: string;
}

interface Props {
  userId: string;
}

type NotificationFilter = "ALL" | "UNREAD";

function formatDate(value: string) {
  try {
    return new Intl.DateTimeFormat("en-PK", {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(new Date(value));
  } catch {
    return value;
  }
}

function notificationTypeLabel(type: string) {
  return type
    .replace(/[_-]/g, " ")
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

function getNotificationTypeClass(type: string) {
  const value = type.toLowerCase();

  if (
    value.includes("emergency") ||
    value.includes("sos") ||
    value.includes("critical")
  ) {
    return "notification-type emergency";
  }

  if (value.includes("blood") || value.includes("request")) {
    return "notification-type blood";
  }

  if (
    value.includes("success") ||
    value.includes("approved") ||
    value.includes("resolved")
  ) {
    return "notification-type success";
  }

  if (value.includes("warning") || value.includes("alert")) {
    return "notification-type warning";
  }

  return "notification-type";
}

export default function NotificationsClient({
  userId,
}: Props) {
  const [notifications, setNotifications] = useState<
    NotificationRecord[]
  >([]);

  const [filter, setFilter] =
    useState<NotificationFilter>("ALL");

  const [search, setSearch] = useState("");

  const [loading, setLoading] = useState(true);

  const [actionLoading, setActionLoading] =
    useState<string | null>(null);

  const [markAllLoading, setMarkAllLoading] =
    useState(false);

  const [error, setError] =
    useState<string | null>(null);

  const [success, setSuccess] =
    useState<string | null>(null);

  const supabase = useMemo(
    () => createClient(),
    [],
  );

  const loadNotifications = useCallback(async () => {
    setLoading(true);
    setError(null);

    const { data, error: queryError } = await supabase
      .from("notifications")
      .select(
        "id,user_id,title,message,notification_type,is_read,created_at",
      )
      .eq("user_id", userId)
      .order("created_at", {
        ascending: false,
      });

    if (queryError) {
      console.error(
        "NOTIFICATIONS - QUERY ERROR",
        queryError,
      );

      setError(
        queryError.message ||
          "Unable to load notifications.",
      );

      setNotifications([]);
      setLoading(false);
      return;
    }

    setNotifications(
      (data ?? []) as NotificationRecord[],
    );

    setLoading(false);
  }, [supabase, userId]);

    /*
 * Initial notification load.
 *
 * Defer the request until after the effect has completed so
 * React does not treat the synchronous loading-state updates
 * inside loadNotifications() as state updates performed directly
 * by the effect.
 */
useEffect(() => {
  const timer = window.setTimeout(() => {
    void loadNotifications();
  }, 0);

  return () => {
    window.clearTimeout(timer);
  };
}, [loadNotifications]);

  /*
   * Supabase Realtime subscription.
   *
   * Keeps the notifications page synchronized immediately
   * when a notification is inserted, updated, or deleted.
   *
   * IMPORTANT:
   * postgres_changes callbacks MUST be registered before
   * subscribe() is called.
   */
  useEffect(() => {
    let cancelled = false;

    const channelName = `notifications-page-${userId}`;

    const setupRealtime = async () => {
      /*
       * Prevent duplicate channels during React/Next.js
       * development remounts.
       */
      const existingChannel =
        supabase.getChannels().find(
          (channel) =>
            channel.topic === `realtime:${channelName}`,
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
       * Create channel and register ALL callbacks
       * before subscribe().
       */
      const channel = supabase
        .channel(channelName)

        /*
         * NEW NOTIFICATION
         */
        .on(
          "postgres_changes",
          {
            event: "INSERT",
            schema: "public",
            table: "notifications",
            filter: `user_id=eq.${userId}`,
          },
          (payload) => {
            const notification =
              payload.new as NotificationRecord;

            setNotifications((current) => {
              /*
               * Prevent duplicates if the same event is
               * somehow received more than once.
               */
              const alreadyExists =
                current.some(
                  (item) =>
                    item.id === notification.id,
                );

              if (alreadyExists) {
                return current;
              }

              return [
                notification,
                ...current,
              ];
            });

            setSuccess(
              "New notification received.",
            );
          },
        )

        /*
         * NOTIFICATION UPDATED
         */
        .on(
          "postgres_changes",
          {
            event: "UPDATE",
            schema: "public",
            table: "notifications",
            filter: `user_id=eq.${userId}`,
          },
          (payload) => {
            const updated =
              payload.new as NotificationRecord;

            setNotifications((current) =>
              current.map((notification) =>
                notification.id === updated.id
                  ? updated
                  : notification,
              ),
            );
          },
        )

        /*
         * NOTIFICATION DELETED
         */
        .on(
          "postgres_changes",
          {
            event: "DELETE",
            schema: "public",
            table: "notifications",
            filter: `user_id=eq.${userId}`,
          },
          (payload) => {
            const deleted =
              payload.old as NotificationRecord;

            setNotifications((current) =>
              current.filter(
                (notification) =>
                  notification.id !== deleted.id,
              ),
            );
          },
        );

      /*
       * Subscribe ONLY after all postgres_changes
       * callbacks have been registered.
       */
      channel.subscribe((status) => {
        console.log(
          "NOTIFICATIONS PAGE - REALTIME STATUS:",
          status,
        );
      });
    };

    void setupRealtime();

    return () => {
      cancelled = true;

      const channel =
        supabase.getChannels().find(
          (item) =>
            item.topic ===
            `realtime:${channelName}`,
        );

      if (channel) {
        void supabase.removeChannel(channel);
      }
    };
  }, [supabase, userId]);

  const unreadCount = useMemo(
    () =>
      notifications.filter(
        (notification) => !notification.is_read,
      ).length,
    [notifications],
  );

  const filteredNotifications = useMemo(() => {
    const searchValue =
      search.trim().toLowerCase();

    return notifications.filter((notification) => {
      if (
        filter === "UNREAD" &&
        notification.is_read
      ) {
        return false;
      }

      if (!searchValue) {
        return true;
      }

      const searchable = [
        notification.title,
        notification.message,
        notification.notification_type,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();

      return searchable.includes(searchValue);
    });
  }, [notifications, filter, search]);

  async function markAsRead(
    notification: NotificationRecord,
  ) {
    if (
      actionLoading ||
      notification.is_read
    ) {
      return;
    }

    setActionLoading(notification.id);
    setError(null);
    setSuccess(null);

    const { error: updateError } =
      await supabase
        .from("notifications")
        .update({
          is_read: true,
        })
        .eq("id", notification.id)
        .eq("user_id", userId);

    if (updateError) {
      console.error(
        "NOTIFICATIONS - MARK READ ERROR",
        updateError,
      );

      setError(
        updateError.message ||
          "Unable to mark notification as read.",
      );

      setActionLoading(null);
      return;
    }

    /*
     * Optimistic/local update.
     *
     * The realtime UPDATE event may arrive as well,
     * but replacing the same record is harmless.
     */
    setNotifications((current) =>
      current.map((item) =>
        item.id === notification.id
          ? {
              ...item,
              is_read: true,
            }
          : item,
      ),
    );

    setSuccess("Notification marked as read.");
    setActionLoading(null);
  }

  async function markAllAsRead() {
    if (
      markAllLoading ||
      unreadCount === 0
    ) {
      return;
    }

    setMarkAllLoading(true);
    setError(null);
    setSuccess(null);

    const { error: updateError } =
      await supabase
        .from("notifications")
        .update({
          is_read: true,
        })
        .eq("user_id", userId)
        .eq("is_read", false);

    if (updateError) {
      console.error(
        "NOTIFICATIONS - MARK ALL READ ERROR",
        updateError,
      );

      setError(
        updateError.message ||
          "Unable to mark all notifications as read.",
      );

      setMarkAllLoading(false);
      return;
    }

    setNotifications((current) =>
      current.map((notification) => ({
        ...notification,
        is_read: true,
      })),
    );

    setSuccess(
      "All notifications marked as read.",
    );

    setMarkAllLoading(false);
  }

  async function deleteNotification(
    notification: NotificationRecord,
  ) {
    if (actionLoading) {
      return;
    }

    setActionLoading(notification.id);
    setError(null);
    setSuccess(null);

    const { error: deleteError } =
      await supabase
        .from("notifications")
        .delete()
        .eq("id", notification.id)
        .eq("user_id", userId);

    if (deleteError) {
      console.error(
        "NOTIFICATIONS - DELETE ERROR",
        deleteError,
      );

      setError(
        deleteError.message ||
          "Unable to delete notification.",
      );

      setActionLoading(null);
      return;
    }

    setNotifications((current) =>
      current.filter(
        (item) =>
          item.id !== notification.id,
      ),
    );

    setSuccess("Notification deleted.");
    setActionLoading(null);
  }

  return (
    <main className="notifications-page">
      <section className="notifications-header">
        <div>
          <div className="notifications-eyebrow">
            SYSTEM CENTER
          </div>

          <h1>Notifications</h1>

          <p>
            Stay up to date with emergency activity,
            blood requests, and important LifeLynk
            updates.
          </p>
        </div>

        <div className="notifications-header-count">
          <span>Unread</span>
          <strong>{unreadCount}</strong>
        </div>
      </section>

      {error && (
        <div className="notifications-error">
          <strong>
            Notification operation failed.
          </strong>

          <span>{error}</span>
        </div>
      )}

      {success && (
        <div className="notifications-success">
          <strong>{success}</strong>
        </div>
      )}

      <section className="notifications-toolbar">
        <div className="notifications-search">
          <span>⌕</span>

          <input
            type="search"
            placeholder="Search notifications..."
            value={search}
            onChange={(event) =>
              setSearch(event.target.value)
            }
          />
        </div>

        <div className="notifications-filters">
          <button
            type="button"
            className={
              filter === "ALL"
                ? "notification-filter active"
                : "notification-filter"
            }
            onClick={() => setFilter("ALL")}
          >
            All
          </button>

          <button
            type="button"
            className={
              filter === "UNREAD"
                ? "notification-filter active"
                : "notification-filter"
            }
            onClick={() => setFilter("UNREAD")}
          >
            Unread
            {unreadCount > 0 && (
              <span className="notification-filter-count">
                {unreadCount}
              </span>
            )}
          </button>
        </div>

        <button
          type="button"
          className="notifications-mark-all"
          disabled={
            markAllLoading ||
            unreadCount === 0
          }
          onClick={() =>
            void markAllAsRead()
          }
        >
          {markAllLoading
            ? "Marking..."
            : "Mark all as read"}
        </button>
      </section>

      <section className="notifications-card">
        <div className="notifications-card-header">
          <div>
            <h2>Recent notifications</h2>

            <p>
              {filteredNotifications.length}{" "}
              notification
              {filteredNotifications.length === 1
                ? ""
                : "s"}{" "}
              shown
            </p>
          </div>

          <button
            type="button"
            className="notifications-refresh"
            disabled={loading}
            onClick={() =>
              void loadNotifications()
            }
          >
            {loading ? "Loading..." : "Refresh"}
          </button>
        </div>

        {loading ? (
          <div className="notifications-state">
            <div className="notifications-spinner" />

            <h3>Loading notifications</h3>

            <p>
              Fetching your latest LifeLynk
              notifications...
            </p>
          </div>
        ) : filteredNotifications.length === 0 ? (
          <div className="notifications-state">
            <div className="notifications-empty-icon">
              ✓
            </div>

            <h3>
              {notifications.length === 0
                ? "No notifications yet"
                : "No matching notifications"}
            </h3>

            <p>
              {notifications.length === 0
                ? "You are all caught up. New notifications will appear here."
                : "Try changing the filter or search term."}
            </p>
          </div>
        ) : (
          <div className="notifications-list">
            {filteredNotifications.map(
              (notification) => (
                <article
                  key={notification.id}
                  className={
                    notification.is_read
                      ? "notification-item"
                      : "notification-item unread"
                  }
                >
                  <div
                    className={getNotificationTypeClass(
                      notification.notification_type,
                    )}
                  >
                    !
                  </div>

                  <div className="notification-content">
                    <div className="notification-top">
                      <div>
                        <h3>
                          {notification.title}
                        </h3>

                        <span
                          className={getNotificationTypeClass(
                            notification.notification_type,
                          )}
                        >
                          {notificationTypeLabel(
                            notification.notification_type,
                          )}
                        </span>
                      </div>

                      {!notification.is_read && (
                        <span className="notification-unread-dot" />
                      )}
                    </div>

                    <p>
                      {notification.message}
                    </p>

                    <div className="notification-bottom">
                      <time>
                        {formatDate(
                          notification.created_at,
                        )}
                      </time>

                      <div className="notification-actions">
                        {!notification.is_read && (
                          <button
                            type="button"
                            disabled={
                              actionLoading !== null
                            }
                            onClick={() =>
                              void markAsRead(
                                notification,
                              )
                            }
                          >
                            {actionLoading ===
                            notification.id
                              ? "Updating..."
                              : "Mark read"}
                          </button>
                        )}

                        <button
                          type="button"
                          className="notification-delete"
                          disabled={
                            actionLoading !== null
                          }
                          onClick={() =>
                            void deleteNotification(
                              notification,
                            )
                          }
                        >
                          {actionLoading ===
                          notification.id
                            ? "Working..."
                            : "Delete"}
                        </button>
                      </div>
                    </div>
                  </div>
                </article>
              ),
            )}
          </div>
        )}
      </section>
    </main>
  );
}

