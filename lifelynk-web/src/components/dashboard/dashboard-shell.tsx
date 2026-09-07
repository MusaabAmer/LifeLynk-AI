"use client";

import { ReactNode } from "react";

import DashboardSidebar from "./dashboard-sidebar";
import DashboardHeader from "./dashboard-header";
import NotificationProvider from "./notification-provider";

import type { CurrentUser } from "@/lib/auth/get-current-user";

interface DashboardShellProps {
  children: ReactNode;
  currentUser: CurrentUser;
}

export default function DashboardShell({
  children,
  currentUser,
}: DashboardShellProps) {
  return (
    <NotificationProvider
      userId={currentUser.id}
    >
      <div className="lifelynk-app">
        <DashboardSidebar
          currentUser={currentUser}
        />

        <div className="lifelynk-main">
          <DashboardHeader
            currentUser={currentUser}
          />

          <main className="lifelynk-main__content">
            {children}
          </main>
        </div>
      </div>
    </NotificationProvider>
  );
}