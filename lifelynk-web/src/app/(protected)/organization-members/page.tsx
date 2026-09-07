"use client";

import {
  useEffect,
  useMemo,
  useState,
} from "react";

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
  status: string;
  requested_at: string;
  users:
    | JoinRequestUser
    | JoinRequestUser[]
    | null;
}

interface OrganizationResponse {
  id: string;
  name: string;
  type: string;
}

interface OrganizationMember {
  id: string;
  user_id: string;
  organization_id: string;
  is_primary: boolean;
  created_at: string;
  user: JoinRequestUser | null;
}

interface JoinRequestsApiResponse {
  success?: boolean;
  error?: string;
  organization?: OrganizationResponse;
  requests?: JoinRequest[];
}

interface MembersApiResponse {
  success?: boolean;
  error?: string;
  organization?: OrganizationResponse;
  is_primary?: boolean;
  can_manage?: boolean;
  members?: OrganizationMember[];
}

export default function OrganizationMembersPage() {
  const supabase = useMemo(
    () => createClient(),
    [],
  );

  const [organization, setOrganization] =
    useState<OrganizationResponse | null>(
      null,
    );

  const [requests, setRequests] =
    useState<JoinRequest[]>([]);

  const [members, setMembers] =
    useState<OrganizationMember[]>([]);

  const [canManage, setCanManage] =
    useState(false);

  const [loading, setLoading] =
    useState(true);

  const [membersLoading, setMembersLoading] =
    useState(true);

  const [processingId, setProcessingId] =
    useState<string | null>(null);

  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  /*
   * ------------------------------------------------------------
   * LOAD PENDING JOIN REQUESTS
   * ------------------------------------------------------------
   *
   * Only the primary administrator should call this API.
   *
   * Normal members can still see the Current Members list,
   * but they do not need the admin-only pending request API.
   * ------------------------------------------------------------
   */
  async function loadRequests(
    showLoading = true,
  ) {
    /*
     * Normal members should not call the admin-only
     * join-request endpoint.
     */
    if (!canManage) {
      setRequests([]);
      setLoading(false);
      return;
    }

    if (showLoading) {
      setLoading(true);
    }

    try {
      const response = await fetch(
        "/api/organization/join-requests",
        {
          method: "GET",
          cache: "no-store",
        },
      );

      const result =
        (await response.json()) as JoinRequestsApiResponse;

      if (!response.ok) {
        setError(
          result.error ||
            "Unable to load join requests.",
        );

        return;
      }

      if (result.organization) {
        setOrganization(
          result.organization,
        );
      }

      setRequests(
        result.requests ?? [],
      );
    } catch {
      setError(
        "Something went wrong while loading join requests.",
      );
    } finally {
      if (showLoading) {
        setLoading(false);
      }
    }
  }

  /*
   * ------------------------------------------------------------
   * LOAD CURRENT MEMBERS
   * ------------------------------------------------------------
   */
  async function loadMembers(
    showLoading = true,
  ) {
    if (showLoading) {
      setMembersLoading(true);
    }

    try {
      const response = await fetch(
        "/api/organization/members",
        {
          method: "GET",
          cache: "no-store",
        },
      );

      const result =
        (await response.json()) as MembersApiResponse;

      if (!response.ok) {
        setError(
          result.error ||
            "Unable to load organization members.",
        );

        return;
      }

      /*
       * Organization information comes from the
       * members API and works for both primary
       * administrator and normal members.
       */
      if (result.organization) {
        setOrganization(
          result.organization,
        );
      }

      /*
       * Primary administrator:
       *   can_manage = true
       *
       * Normal member:
       *   can_manage = false
       */
      setCanManage(
        result.can_manage === true,
      );

      setMembers(
        result.members ?? [],
      );
    } catch {
      setError(
        "Something went wrong while loading organization members.",
      );
    } finally {
      if (showLoading) {
        setMembersLoading(false);
      }
    }
  }

  /*
   * ------------------------------------------------------------
   * INITIAL LOAD
   * ------------------------------------------------------------
   */
  useEffect(() => {
    let cancelled = false;

    async function initialize() {
      /*
       * First load membership information.
       *
       * This tells us whether the current user is
       * the primary administrator.
       */
      try {
        const response = await fetch(
          "/api/organization/members",
          {
            method: "GET",
            cache: "no-store",
          },
        );

        const result =
          (await response.json()) as MembersApiResponse;

        if (cancelled) {
          return;
        }

        if (!response.ok) {
          setError(
            result.error ||
              "Unable to load organization members.",
          );

          setMembersLoading(false);
          setLoading(false);

          return;
        }

        if (result.organization) {
          setOrganization(
            result.organization,
          );
        }

        const primary =
          result.can_manage === true;

        setCanManage(primary);

        setMembers(
          result.members ?? [],
        );

        setMembersLoading(false);

        /*
         * Only primary administrator loads
         * pending requests.
         */
        if (primary) {
          const requestsResponse =
            await fetch(
              "/api/organization/join-requests",
              {
                method: "GET",
                cache: "no-store",
              },
            );

          const requestsResult =
            (await requestsResponse.json()) as JoinRequestsApiResponse;

          if (cancelled) {
            return;
          }

          if (!requestsResponse.ok) {
            setError(
              requestsResult.error ||
                "Unable to load join requests.",
            );
          } else {
            setRequests(
              requestsResult.requests ?? [],
            );
          }
        }

        setLoading(false);
      } catch {
        if (cancelled) {
          return;
        }

        setError(
          "Something went wrong while loading organization members.",
        );

        setMembersLoading(false);
        setLoading(false);
      }
    }

    void initialize();

    /*
     * ----------------------------------------------------------
     * JOIN REQUEST REALTIME
     * ----------------------------------------------------------
     */
    const requestsChannel = supabase
      .channel(
        "organization-members-join-requests",
      )
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "organization_join_requests",
        },
        () => {
          if (
            cancelled ||
            !canManage
          ) {
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
          if (
            cancelled ||
            !canManage
          ) {
            return;
          }

          void loadRequests(false);
        },
      )
      .subscribe((status) => {
        console.log(
          "ORGANIZATION MEMBERS - JOIN REQUEST REALTIME:",
          status,
        );
      });

    /*
     * ----------------------------------------------------------
     * ORGANIZATION STAFF REALTIME
     * ----------------------------------------------------------
     */
    const membersChannel = supabase
      .channel(
        "organization-members-staff",
      )
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "organization_staff",
        },
        () => {
          if (cancelled) {
            return;
          }

          void loadMembers(false);
        },
      )
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "organization_staff",
        },
        () => {
          if (cancelled) {
            return;
          }

          void loadMembers(false);
        },
      )
      .on(
        "postgres_changes",
        {
          event: "DELETE",
          schema: "public",
          table: "organization_staff",
        },
        () => {
          if (cancelled) {
            return;
          }

          void loadMembers(false);
        },
      )
      .subscribe((status) => {
        console.log(
          "ORGANIZATION MEMBERS - STAFF REALTIME:",
          status,
        );
      });

    return () => {
      cancelled = true;

      void supabase.removeChannel(
        requestsChannel,
      );

      void supabase.removeChannel(
        membersChannel,
      );
    };

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [supabase]);

  /*
   * ------------------------------------------------------------
   * APPROVE / REJECT REQUEST
   * ------------------------------------------------------------
   */
  async function handleRequest(
    requestId: string,
    action: "APPROVE" | "REJECT",
  ) {
    /*
     * Frontend guard.
     *
     * The API also enforces this server-side.
     */
    if (!canManage) {
      setError(
        "Only the Primary Administrator can manage join requests.",
      );

      return;
    }

    setProcessingId(requestId);
    setError("");
    setMessage("");

    try {
      const response = await fetch(
        `/api/organization/join-requests/${requestId}`,
        {
          method: "PATCH",
          headers: {
            "Content-Type":
              "application/json",
          },
          body: JSON.stringify({
            action,
          }),
        },
      );

      const result =
        (await response.json()) as JoinRequestsApiResponse;

      if (!response.ok) {
        setError(
          result.error ||
            "Unable to process this request.",
        );

        return;
      }

      setMessage(
        action === "APPROVE"
          ? "Member approved successfully."
          : "Join request rejected.",
      );

      /*
       * Immediately synchronize both sections.
       */
      await Promise.all([
        loadRequests(false),
        loadMembers(false),
      ]);
    } catch {
      setError(
        "Something went wrong. Please try again.",
      );
    } finally {
      setProcessingId(null);
    }
  }

  /*
   * ------------------------------------------------------------
   * JOIN REQUEST USER
   * ------------------------------------------------------------
   */
  function getUser(
    request: JoinRequest,
  ): JoinRequestUser | null {
    if (Array.isArray(request.users)) {
      return request.users[0] ?? null;
    }

    return request.users;
  }

  /*
   * ------------------------------------------------------------
   * MEMBER USER
   * ------------------------------------------------------------
   */
  function getMemberName(
    member: OrganizationMember,
  ) {
    return (
      member.user?.full_name ||
      member.user?.email ||
      "LifeLynk user"
    );
  }

  /*
   * ------------------------------------------------------------
   * RENDER
   * ------------------------------------------------------------
   */
  return (
    <section
      style={{
        width: "100%",
        maxWidth: "1100px",
        margin: "0 auto",
        padding: "32px 36px 48px",
      }}
    >
      {/* ======================================================
          HEADER
          ====================================================== */}

      <div
        style={{
          marginBottom: "28px",
        }}
      >
        <p
          style={{
            margin: 0,
            fontSize: "12px",
            fontWeight: 700,
            letterSpacing: "0.12em",
          }}
        >
          ORGANIZATION
        </p>

        <h2
          style={{
            margin: "8px 0 8px",
          }}
        >
          Members
        </h2>

        <p
          style={{
            margin: 0,
            opacity: 0.7,
          }}
        >
          View organization members and manage
          requests to join.
        </p>
      </div>

      {/* ======================================================
          ORGANIZATION
          ====================================================== */}

      {organization && (
        <div
          style={{
            padding: "18px 20px",
            marginBottom: "24px",
            border:
              "1px solid rgba(0,0,0,0.08)",
            borderRadius: "14px",
          }}
        >
          <strong>
            {organization.name}
          </strong>

          <div
            style={{
              marginTop: "5px",
              opacity: 0.65,
              fontSize: "14px",
            }}
          >
            {organization.type.replaceAll(
              "_",
              " ",
            )}
          </div>

          {!canManage && (
            <div
              style={{
                marginTop: "10px",
                fontSize: "13px",
                opacity: 0.65,
              }}
            >
              You are a member of this
              organization. Only the Primary
              Administrator can approve or reject
              join requests.
            </div>
          )}
        </div>
      )}

      {/* ======================================================
          ERROR
          ====================================================== */}

      {error && (
        <div
          role="alert"
          style={{
            padding: "14px 16px",
            marginBottom: "20px",
            borderRadius: "12px",
            background:
              "rgba(198,40,40,0.08)",
            color: "#C62828",
          }}
        >
          {error}
        </div>
      )}

      {/* ======================================================
          SUCCESS MESSAGE
          ====================================================== */}

      {message && (
        <div
          role="status"
          style={{
            padding: "14px 16px",
            marginBottom: "20px",
            borderRadius: "12px",
            background:
              "rgba(34,197,94,0.08)",
          }}
        >
          {message}
        </div>
      )}

      {/* ======================================================
          CURRENT MEMBERS
          ====================================================== */}

      <div
        style={{
          padding: "24px",
          marginBottom: "24px",
          border:
            "1px solid rgba(0,0,0,0.08)",
          borderRadius: "16px",
        }}
      >
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            marginBottom: "20px",
          }}
        >
          <div>
            <h3
              style={{
                margin: 0,
              }}
            >
              Current Members
            </h3>

            <p
              style={{
                margin: "6px 0 0",
                opacity: 0.65,
                fontSize: "14px",
              }}
            >
              Members who currently have access
              to this organization.
            </p>
          </div>

          <strong>
            {members.length}
          </strong>
        </div>

        {membersLoading ? (
          <div
            style={{
              padding: "32px 0",
              textAlign: "center",
              opacity: 0.65,
            }}
          >
            Loading members...
          </div>
        ) : members.length === 0 ? (
          <div
            style={{
              padding: "36px 0",
              textAlign: "center",
              opacity: 0.65,
            }}
          >
            No organization members found.
          </div>
        ) : (
          <div
            style={{
              display: "grid",
              gap: "12px",
            }}
          >
            {members.map((member) => (
              <div
                key={member.id}
                style={{
                  display: "flex",
                  justifyContent:
                    "space-between",
                  alignItems: "center",
                  gap: "20px",
                  padding: "18px",
                  border:
                    "1px solid rgba(0,0,0,0.07)",
                  borderRadius: "12px",
                }}
              >
                <div>
                  <strong>
                    {getMemberName(member)}
                  </strong>

                  <div
                    style={{
                      marginTop: "4px",
                      fontSize: "14px",
                      opacity: 0.65,
                    }}
                  >
                    {member.user?.email ||
                      "No email available"}
                  </div>

                  <div
                    style={{
                      marginTop: "6px",
                      fontSize: "12px",
                      opacity: 0.5,
                    }}
                  >
                    Joined{" "}
                    {new Date(
                      member.created_at,
                    ).toLocaleString()}
                  </div>
                </div>

                <div
                  style={{
                    padding:
                      "6px 10px",
                    borderRadius: "999px",
                    fontSize: "12px",
                    fontWeight: 700,
                    background:
                      member.is_primary
                        ? "rgba(30,136,229,0.10)"
                        : "rgba(0,0,0,0.06)",
                  }}
                >
                  {member.is_primary
                    ? "Primary Administrator"
                    : "Member"}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* ======================================================
          PENDING JOIN REQUESTS
          ====================================================== */}

      {canManage && (
        <div
          style={{
            padding: "24px",
            border:
              "1px solid rgba(0,0,0,0.08)",
            borderRadius: "16px",
          }}
        >
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              marginBottom: "20px",
            }}
          >
            <div>
              <h3
                style={{
                  margin: 0,
                }}
              >
                Pending Join Requests
              </h3>

              <p
                style={{
                  margin: "6px 0 0",
                  opacity: 0.65,
                  fontSize: "14px",
                }}
              >
                Approve a member to give them
                access to this organization's
                dashboard.
              </p>
            </div>

            <strong>
              {requests.length}
            </strong>
          </div>

          {loading ? (
            <div
              style={{
                padding: "32px 0",
                textAlign: "center",
                opacity: 0.65,
              }}
            >
              Loading requests...
            </div>
          ) : requests.length === 0 ? (
            <div
              style={{
                padding: "36px 0",
                textAlign: "center",
                opacity: 0.65,
              }}
            >
              No pending join requests.
            </div>
          ) : (
            <div
              style={{
                display: "grid",
                gap: "12px",
              }}
            >
              {requests.map((request) => {
                const applicant =
                  getUser(request);

                const processing =
                  processingId ===
                  request.id;

                return (
                  <div
                    key={request.id}
                    style={{
                      display: "flex",
                      justifyContent:
                        "space-between",
                      alignItems: "center",
                      gap: "20px",
                      padding: "18px",
                      border:
                        "1px solid rgba(0,0,0,0.07)",
                      borderRadius: "12px",
                    }}
                  >
                    <div>
                      <strong>
                        {applicant?.full_name ||
                          "LifeLynk user"}
                      </strong>

                      <div
                        style={{
                          marginTop: "4px",
                          fontSize: "14px",
                          opacity: 0.65,
                        }}
                      >
                        {applicant?.email ||
                          "No email available"}
                      </div>

                      <div
                        style={{
                          marginTop: "6px",
                          fontSize: "12px",
                          opacity: 0.5,
                        }}
                      >
                        Requested{" "}
                        {new Date(
                          request.requested_at,
                        ).toLocaleString()}
                      </div>
                    </div>

                    <div
                      style={{
                        display: "flex",
                        gap: "8px",
                      }}
                    >
                      <button
                        type="button"
                        onClick={() =>
                          void handleRequest(
                            request.id,
                            "REJECT",
                          )
                        }
                        disabled={processing}
                      >
                        {processing
                          ? "..."
                          : "Reject"}
                      </button>

                      <button
                        type="button"
                        onClick={() =>
                          void handleRequest(
                            request.id,
                            "APPROVE",
                          )
                        }
                        disabled={processing}
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
          )}
        </div>
      )}
    </section>
  );
}