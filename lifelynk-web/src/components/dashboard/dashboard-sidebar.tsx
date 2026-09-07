"use client";

import Link from "next/link";
import {
  usePathname,
  useRouter,
} from "next/navigation";

import { createClient } from "@/lib/supabase/client";

import type {
  CurrentUser,
} from "@/lib/auth/get-current-user";

import { useNotifications } from "./notification-provider";

const navigation = [
  {
    label: "Dashboard",
    href: "/dashboard",
    icon: "⌂",
  },
  {
    label: "Government",
    href: "/government",
    icon: "▤",
    governmentOnly: true,
  },
  {
    label: "Blood Inventory",
    href: "/blood-inventory",
    icon: "🩸",
  },
  {
    label: "Blood Requests",
    href: "/blood-requests",
    icon: "▣",
  },
  {
    label: "Emergency SOS",
    href: "/emergency-sos",
    icon: "🚨",
  },
  {
    label: "Donors",
    href: "/donors",
    icon: "♙",
  },
  {
    label: "Hospitals",
    href: "/hospitals",
    icon: "✚",
  },
  {
    label: "Locations",
    href: "/locations",
    icon: "⌖",
  },
  {
    label: "Organization Members",
    href: "/organization-members",
    icon: "♙",
    organizationAdminOnly: true,
  },
  {
    label: "Notifications",
    href: "/notifications",
    icon: "♢",
  },
  {
    label: "Profile",
    href: "/profile",
    icon: "◉",
  },
  {
    label: "Settings",
    href: "/settings",
    icon: "⚙",
  },
];

interface DashboardSidebarProps {
  currentUser: CurrentUser;
}

function formatRole(role: string) {
  return role
    .replaceAll("_", " ")
    .toLowerCase()
    .replace(
      /\b\w/g,
      (letter) => letter.toUpperCase(),
    );
}

function getInitials(name: string) {
  const parts = name
    .trim()
    .split(/\s+/)
    .filter(Boolean);

  if (parts.length === 0) {
    return "U";
  }

  if (parts.length === 1) {
    return parts[0]
      .slice(0, 2)
      .toUpperCase();
  }

  return `${parts[0].charAt(0)}${
    parts[parts.length - 1].charAt(0)
  }`.toUpperCase();
}

export default function DashboardSidebar({
  currentUser,
}: DashboardSidebarProps) {
  const pathname = usePathname();
  const router = useRouter();

  /*
   * IMPORTANT:
   * Use the SAME notification provider as the
   * dashboard header and notifications page.
   *
   * This keeps the sidebar dot synchronized
   * with the real unread notification state.
   */
  const { unreadCount } = useNotifications();

  async function handleLogout() {
    const supabase = createClient();

    await supabase.auth.signOut();

    router.replace("/login");
  }

  const displayName =
    currentUser.fullName?.trim() ||
    currentUser.email;

  const initials = getInitials(displayName);

  const roleLabel = formatRole(
    currentUser.role,
  );

  const isGovernmentUser =
    currentUser.role ===
      "GOVERNMENT_ADMIN" ||
    currentUser.role ===
      "SUPER_ADMIN";

  /*
   * Organization Members is specifically for the
   * primary organization administrators.
   *
   * STAFF members must NOT receive access to the
   * approval interface.
   */
  const isOrganizationAdmin =
    currentUser.role ===
      "HOSPITAL_ADMIN" ||
    currentUser.role ===
      "BLOOD_BANK_ADMIN";

  const isProfileActive =
    pathname === "/profile" ||
    pathname.startsWith("/profile/");

  return (
    <aside className="lifelynk-sidebar">
      {/* =====================================================
          BRAND
          ===================================================== */}

      <div className="lifelynk-sidebar__brand">
        <img
          src="/images/app_icon.png"
          alt="LifeLynk AI"
        />

        <div>
          <strong>
            LifeLynk AI
          </strong>

          <span>
            Healthcare Network
          </span>
        </div>
      </div>

      {/* =====================================================
          NAVIGATION
          ===================================================== */}

      <nav className="lifelynk-sidebar__nav">
        <p className="lifelynk-sidebar__section">
          PLATFORM
        </p>

        {navigation
          .filter((item) => {
            /*
             * Government navigation
             */
            if (
              item.governmentOnly &&
              !isGovernmentUser
            ) {
              return false;
            }

            /*
             * Organization Members navigation
             *
             * Only HOSPITAL_ADMIN and BLOOD_BANK_ADMIN
             * can access organization member approvals.
             */
            if (
              item.organizationAdminOnly &&
              !isOrganizationAdmin
            ) {
              return false;
            }

            return true;
          })
          .map((item) => {
            const active =
              pathname === item.href ||
              pathname.startsWith(
                `${item.href}/`,
              );

            const isNotifications =
              item.href ===
              "/notifications";

            return (
              <Link
                key={item.href}
                href={item.href}
                className={`lifelynk-sidebar__item ${
                  active
                    ? "lifelynk-sidebar__item--active"
                    : ""
                }`}
                aria-label={
                  isNotifications &&
                  unreadCount > 0
                    ? `Notifications, ${unreadCount} unread`
                    : item.label
                }
              >
                <span className="lifelynk-sidebar__icon">
                  {item.icon}
                </span>

                <span>
                  {item.label}
                </span>

                {/* ==========================================
                    UNREAD NOTIFICATION DOT
                    ========================================== */}

                {isNotifications &&
                  unreadCount > 0 && (
                    <span
                      className="lifelynk-sidebar__notification-dot"
                      aria-label={`${unreadCount} unread notifications`}
                    />
                  )}
              </Link>
            );
          })}
      </nav>

      {/* =====================================================
          SIDEBAR BOTTOM
          ===================================================== */}

      <div className="lifelynk-sidebar__bottom">
        {/* ===================================================
            ACCOUNT / PROFILE CARD
            =================================================== */}

        <Link
          href="/profile"
          aria-label="Open profile"
          className={`lifelynk-sidebar__account ${
            isProfileActive
              ? "lifelynk-sidebar__account--active"
              : ""
          }`}
        >
          <span className="lifelynk-sidebar__account-avatar">
            {initials}
          </span>

          <span className="lifelynk-sidebar__account-info">
            <strong title={displayName}>
              {displayName}
            </strong>

            <small>
              {roleLabel}
            </small>
          </span>

          <span
            className="lifelynk-sidebar__account-arrow"
            aria-hidden="true"
          >
            →
          </span>
        </Link>

        {/* ===================================================
            SYSTEM STATUS
            =================================================== */}

        <div className="lifelynk-sidebar__status">
          <span className="lifelynk-sidebar__status-dot" />

          <div>
            <strong>
              System online
            </strong>

            <span>
              Supabase connected
            </span>
          </div>
        </div>

        {/* ===================================================
            SIGN OUT
            =================================================== */}

        <button
          type="button"
          className="lifelynk-sidebar__logout"
          onClick={handleLogout}
        >
          <span>
            ↪
          </span>

          Sign out
        </button>
      </div>
    </aside>
  );
}