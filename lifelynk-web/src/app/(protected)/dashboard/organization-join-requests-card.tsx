"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

import { createClient } from "@/lib/supabase/client";

interface JoinRequestUser {
  id: string;
  email: string | null;
  full_name: string | null;
}

interface JoinRequest {
  id: string;
  organization_id: string;
  user_id: string;
  status: "PENDING" | "APPROVED" | "REJECTED";
  requested_at: string;
  users: JoinRequestUser | JoinRequestUser[] | null;
}

interface JoinRequestsResponse {
  organization: {
    id: string;
    name: string;
    type: string;
  };
  requests: JoinRequest[];
}

function getUser(
  request: JoinRequest,
): JoinRequestUser | null {
  if (!request.users) {
    return null;
  }

  if (Array.isArray(request.users)) {
    return request.users[0] ?? null;
  }

  return request.users;
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

  return `${parts[0].charAt(0)}${parts[
    parts.length - 1
  ].charAt(0)}`.toUpperCase();
}

function formatRequestedDate(value: string) {
  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return "Recently";
  }

  return new Intl.DateTimeFormat("en-PK", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(date);
}

const supabase = createClient();

export default function OrganizationJoinRequestsCard() {
  const [requests, setRequests] =
    useState<JoinRequest[]>([]);

  const [organizationName, setOrganizationName] =
    useState("");

  const [loading, setLoading] =
    useState(true);

  const [processingId, setProcessingId] =
    useState<string | null>(null);

  const [error, setError] =
    useState("");

  const [message, setMessage] =
    useState("");

  /*
   * ------------------------------------------------
   * LOAD REQUESTS
   * ------------------------------------------------
   *
   * The API remains responsible for returning the
   * complete request objects, including the joined
   * users relation.
   *
   * Realtime is only used to tell us WHEN to reload.
   */
  async function loadRequests(
    showLoading = false,
  ) {
    try {
      if (showLoading) {
        setLoading(true);
      }

      setError("");

      const response = await fetch(
        "/api/organization/join-requests",
        {
          method: "GET",
          cache: "no-store",
        },
      );

      const data =
        (await response.json()) as
          | JoinRequestsResponse
          | { error?: string };

      if (!response.ok) {
        /*
         * A non-admin should not normally render this
         * component, but keep it fail-safe.
         */
        if (
          response.status === 403 ||
          response.status === 404
        ) {
          setRequests([]);
          setOrganizationName("");
          return;
        }

        throw new Error(
          "error" in data && data.error
            ? data.error
            : "Unable to load join requests.",
        );
      }

      const result =
        data as JoinRequestsResponse;

      setOrganizationName(
        result.organization?.name ?? "",
      );

      setRequests(
        Array.isArray(result.requests)
          ? result.requests
          : [],
      );
    } catch (requestError) {
      setError(
        requestError instanceof Error
          ? requestError.message
          : "Unable to load join requests.",
      );
    } finally {
      if (showLoading) {
        setLoading(false);
      }
    }
  }

  /*
   * ------------------------------------------------
   * INITIAL LOAD + SUPABASE REALTIME
   * ------------------------------------------------
   *
   * Initial page load gets the current requests.
   *
   * After that, Supabase Realtime listens for changes
   * to organization_join_requests.
   *
   * IMPORTANT:
   * We reload through our existing secure API
   * instead of trusting the raw Realtime payload.
   *
   * This gives us the complete joined user data and
   * keeps the existing authorization logic in place.
   */
   useEffect(() => {
    let mounted = true;

    void loadRequests(true);

    const channel = supabase
      .channel(
        "organization-join-requests-dashboard",
      )
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "organization_join_requests",
        },
        () => {
          if (!mounted) {
            return;
          }

          void loadRequests(false);
        },
      )
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "organization_join_requests",
        },
        () => {
          if (!mounted) {
            return;
          }

          void loadRequests(false);
        },
      )
      .subscribe();

    return () => {
      mounted = false;
      void supabase.removeChannel(channel);
    };
  }, []);

  /*
   * ------------------------------------------------
   * APPROVE / REJECT
   * ------------------------------------------------
   */
  async function handleDecision(
    requestId: string,
    action: "APPROVE" | "REJECT",
  ) {
    setProcessingId(requestId);
    setError("");
    setMessage("");

    try {
      const response = await fetch(
        `/api/organization/join-requests/${requestId}`,
        {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            action,
          }),
        },
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(
          data?.error ||
            `Unable to ${action.toLowerCase()} request.`,
        );
      }

      /*
       * Optimistic local update.
       *
       * The Realtime UPDATE event will also fire and
       * synchronize the card with the database.
       */
      setRequests((current) =>
        current.filter(
          (request) =>
            request.id !== requestId,
        ),
      );

      setMessage(
        action === "APPROVE"
          ? "Member approved successfully."
          : "Join request rejected.",
      );
    } catch (requestError) {
      setError(
        requestError instanceof Error
          ? requestError.message
          : "Unable to process the request.",
      );
    } finally {
      setProcessingId(null);
    }
  }

  /*
   * ------------------------------------------------
   * LOADING
   * ------------------------------------------------
   */
  if (loading) {
    return (
      <section className="dashboard-members-panel">
        <div className="dashboard-members-panel__header">
          <div>
            <p className="dashboard-members-panel__eyebrow">
              ORGANIZATION MEMBERS
            </p>

            <h3>
              Member access requests
            </h3>

            <p>
              Checking for pending requests...
            </p>
          </div>

          <span className="dashboard-members-panel__count">
            …
          </span>
        </div>

        <div className="dashboard-members-panel__body">
          <div className="dashboard-members-panel__empty">
            <div className="dashboard-members-panel__empty-icon">
              👥
            </div>

            <div>
              <strong>
                Loading member requests
              </strong>

              <span>
                Please wait while we check your
                organization.
              </span>
            </div>
          </div>
        </div>
      </section>
    );
  }

  /*
   * ------------------------------------------------
   * FAIL-SAFE NON-ADMIN CHECK
   * ------------------------------------------------
   */
  if (
    !organizationName &&
    requests.length === 0 &&
    !error
  ) {
    return null;
  }

  return (
    <section className="dashboard-members-panel">
      <div className="dashboard-members-panel__header">
        <div>
          <p className="dashboard-members-panel__eyebrow">
            ORGANIZATION MEMBERS
          </p>

          <h3>
            Member access requests
          </h3>

          <p>
            Review people requesting access to{" "}
            {organizationName ||
              "your organization"}.
          </p>
        </div>

        <span className="dashboard-members-panel__count">
          {requests.length}
        </span>
      </div>

      <div className="dashboard-members-panel__body">
        {error && (
          <div
            className="dashboard-members-panel__message dashboard-members-panel__message--error"
            role="alert"
          >
            {error}
          </div>
        )}

        {message && (
          <div
            className="dashboard-members-panel__message dashboard-members-panel__message--success"
            role="status"
          >
            {message}
          </div>
        )}

        {requests.length > 0 ? (
          <>
            <div className="dashboard-members-panel__list">
              {requests.map((request) => {
                const user = getUser(request);

                const displayName =
                  user?.full_name?.trim() ||
                  user?.email ||
                  "LifeLynk user";

                const email =
                  user?.email ||
                  "Email unavailable";

                const initials =
                  getInitials(displayName);

                const processing =
                  processingId === request.id;

                return (
                  <div
                    className="dashboard-member-request"
                    key={request.id}
                  >
                    <div className="dashboard-member-request__identity">
                      <span className="dashboard-member-request__avatar">
                        {initials}
                      </span>

                      <div className="dashboard-member-request__info">
                        <strong
                          title={displayName}
                        >
                          {displayName}
                        </strong>

                        <span title={email}>
                          {email}
                        </span>

                        <small>
                          Requested{" "}
                          {formatRequestedDate(
                            request.requested_at,
                          )}
                        </small>
                      </div>
                    </div>

                    <div className="dashboard-member-request__actions">
                      <button
                        type="button"
                        className="dashboard-member-request__button dashboard-member-request__button--reject"
                        disabled={processing}
                        onClick={() =>
                          void handleDecision(
                            request.id,
                            "REJECT",
                          )
                        }
                      >
                        {processing
                          ? "..."
                          : "Reject"}
                      </button>

                      <button
                        type="button"
                        className="dashboard-member-request__button dashboard-member-request__button--approve"
                        disabled={processing}
                        onClick={() =>
                          void handleDecision(
                            request.id,
                            "APPROVE",
                          )
                        }
                      >
                        {processing
                          ? "..."
                          : "Approve"}
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>

            <div className="dashboard-members-panel__footer">
              <Link
                href="/organization-members"
                className="dashboard-members-panel__view-all"
              >
                Manage all member requests →
              </Link>
            </div>
          </>
        ) : (
          <div className="dashboard-members-panel__empty">
            <div className="dashboard-members-panel__empty-icon">
              ✓
            </div>

            <div>
              <strong>
                No pending member requests
              </strong>

              <span>
                New access requests will appear
                here when someone wants to join
                your organization.
              </span>
            </div>
          </div>
        )}
      </div>
    </section>
  );
}