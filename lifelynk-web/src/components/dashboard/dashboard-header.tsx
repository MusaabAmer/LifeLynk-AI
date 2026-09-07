"use client";

import Link from "next/link";

import type { CurrentUser } from "@/lib/auth/get-current-user";
import { useNotifications } from "./notification-provider";

interface DashboardHeaderProps {
  currentUser: CurrentUser;
}

function formatRole(
  role: CurrentUser["role"],
) {
  return role
    .replaceAll("_", " ")
    .toLowerCase()
    .replace(/\b\w/g, (letter) =>
      letter.toUpperCase(),
    );
}

export default function DashboardHeader({
  currentUser,
}: DashboardHeaderProps) {
  const { unreadCount } =
    useNotifications();

  const displayName =
    currentUser.fullName?.trim() ||
    currentUser.email;

  const initials = displayName
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) =>
      part.charAt(0).toUpperCase(),
    )
    .join("");

  /*
   * Keep the badge compact when there are many
   * unread notifications.
   *
   * Example:
   * 1 → 1
   * 9 → 9
   * 12 → 12
   * 100 → 99+
   */
  const unreadBadge =
    unreadCount > 99
      ? "99+"
      : String(unreadCount);

  return (
    <header className="lifelynk-header">
      <div>
        <p className="lifelynk-header__eyebrow">
          LIFELYNK AI
        </p>

        <h1>
          {currentUser.organizationName ??
            "Healthcare Network"}
        </h1>
      </div>

      <div className="lifelynk-header__actions">
        <Link
          href="/notifications"
          className="lifelynk-header__notification"
          aria-label={
            unreadCount > 0
              ? `Notifications, ${unreadCount} unread`
              : "Notifications"
          }
        >
          <span
            className="lifelynk-header__notification-icon"
            aria-hidden="true"
          >
            🔔
          </span>

          {unreadCount > 0 && (
            <span
              className="lifelynk-header__notification-badge"
              aria-hidden="true"
            >
              {unreadBadge}
            </span>
          )}
        </Link>

        <div className="lifelynk-header__user">
          <div className="lifelynk-header__avatar">
            {initials || "U"}
          </div>

          <div>
            <strong>
              {currentUser.fullName ||
                "User"}
            </strong>

            <span>
              {formatRole(
                currentUser.role,
              )}
            </span>
          </div>
        </div>
      </div>
    </header>
  );
}