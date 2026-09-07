"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

import { createClient } from "@/lib/supabase/client";

interface JoinRequestRow {
  id: string;
  organization_id: string;
  user_id: string;
  status:
    | "PENDING"
    | "APPROVED"
    | "REJECTED";
  requested_at: string;
  reviewed_at: string | null;
  rejection_reason: string | null;
}

interface JoinRequestPendingClientProps {
  organizationName: string;
}

export default function JoinRequestPendingClient({
  organizationName,
}: JoinRequestPendingClientProps) {
  const router = useRouter();
  const supabase = createClient();

  const [status, setStatus] =
    useState<
      "LOADING" |
      "PENDING" |
      "APPROVED" |
      "REJECTED"
    >("LOADING");

  const [rejectionReason, setRejectionReason] =
    useState("");

  const [error, setError] =
    useState("");

  useEffect(() => {
    let mounted = true;

    async function checkCurrentRequest() {
      try {
        /*
         * Supabase Auth tells us who the current
         * member is.
         */
        const {
          data: {
            user,
          },
          error: userError,
        } = await supabase.auth.getUser();

        if (userError || !user) {
          if (mounted) {
            setError(
              "Your session could not be verified.",
            );
          }

          return;
        }

        /*
         * RLS allows a user to view their own
         * organization join requests.
         */
        const {
          data,
          error: requestError,
        } = await supabase
          .from(
            "organization_join_requests",
          )
          .select(`
            id,
            organization_id,
            user_id,
            status,
            requested_at,
            reviewed_at,
            rejection_reason
          `)
          .eq("user_id", user.id)
          .order(
            "requested_at",
            {
              ascending: false,
            },
          )
          .limit(1)
          .maybeSingle();

        if (requestError) {
          throw requestError;
        }

        if (!mounted) {
          return;
        }

        /*
         * No request means the user should return
         * to onboarding.
         */
        if (!data) {
          setStatus("REJECTED");
          setRejectionReason(
            "No active organization access request was found.",
          );
          return;
        }

        const request =
          data as JoinRequestRow;

        if (
          request.status ===
          "APPROVED"
        ) {
          /*
           * Membership has already been created by
           * the approval API.
           */
          setStatus("APPROVED");

          router.replace("/dashboard");
          router.refresh();

          return;
        }

        if (
          request.status ===
          "REJECTED"
        ) {
          setStatus("REJECTED");

          setRejectionReason(
            request.rejection_reason ||
              "Your organization access request was rejected.",
          );

          return;
        }

        setStatus("PENDING");
      } catch (requestError) {
        if (!mounted) {
          return;
        }

        setError(
          requestError instanceof Error
            ? requestError.message
            : "Unable to check your access request.",
        );

        setStatus("PENDING");
      }
    }

    /*
     * Check immediately when the page opens.
     */
    void checkCurrentRequest();

    /*
     * ------------------------------------------------
     * REALTIME
     * ------------------------------------------------
     *
     * Listen specifically for changes to this
     * user's organization join requests.
     *
     * The INSERT is also handled because another
     * browser/session could create a request while
     * this page is open.
     */
    const channel = supabase
      .channel(
        "member-join-request-status",
      )
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "organization_join_requests",
        },
        (payload) => {
          if (!mounted) {
            return;
          }

          const row =
            payload.new as Partial<JoinRequestRow>;

          /*
           * Only react to this authenticated user's
           * request.
           *
           * RLS is still the database security layer.
           */
          void supabase.auth
            .getUser()
            .then(
              ({
                data: {
                  user,
                },
              }) => {
                if (
                  !mounted ||
                  !user ||
                  row.user_id !==
                    user.id
                ) {
                  return;
                }

                if (
                  row.status ===
                  "APPROVED"
                ) {
                  router.replace(
                    "/dashboard",
                  );

                  router.refresh();

                  return;
                }

                if (
                  row.status ===
                  "REJECTED"
                ) {
                  setStatus(
                    "REJECTED",
                  );

                  setRejectionReason(
                    row.rejection_reason ||
                      "Your organization access request was rejected.",
                  );

                  return;
                }

                setStatus("PENDING");
              },
            );
        },
      )
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "organization_join_requests",
        },
        (payload) => {
          if (!mounted) {
            return;
          }

          const row =
            payload.new as Partial<JoinRequestRow>;

          void supabase.auth
            .getUser()
            .then(
              ({
                data: {
                  user,
                },
              }) => {
                if (
                  !mounted ||
                  !user ||
                  row.user_id !==
                    user.id
                ) {
                  return;
                }

                if (
                  row.status ===
                  "APPROVED"
                ) {
                  /*
                   * Member 1 approved the request.
                   *
                   * The approval API creates
                   * organization_staff first and then
                   * changes the request to APPROVED.
                   *
                   * Therefore dashboard access is
                   * ready when we redirect.
                   */
                  setStatus(
                    "APPROVED",
                  );

                  router.replace(
                    "/dashboard",
                  );

                  router.refresh();

                  return;
                }

                if (
                  row.status ===
                  "REJECTED"
                ) {
                  setStatus(
                    "REJECTED",
                  );

                  setRejectionReason(
                    row.rejection_reason ||
                      "Your organization access request was rejected.",
                  );

                  return;
                }

                setStatus("PENDING");
              },
            );
        },
      )
      .subscribe();

    return () => {
      mounted = false;

      void supabase.removeChannel(
        channel,
      );
    };
  }, [router, supabase]);

  /*
   * ------------------------------------------------
   * ERROR
   * ------------------------------------------------
   */
  if (error) {
    return (
      <div className="dashboard-page onboarding-page">
        <section className="onboarding-welcome">
          <div className="onboarding-welcome__content">
            <div className="onboarding-welcome__icon">
              !
            </div>

            <div>
              <p className="dashboard-page__eyebrow">
                ORGANIZATION ACCESS
              </p>

              <h2>
                Unable to check request
              </h2>

              <p>{error}</p>
            </div>
          </div>

          <div className="onboarding-welcome__status">
            <span />
            Connection issue
          </div>
        </section>
      </div>
    );
  }

  /*
   * ------------------------------------------------
   * REJECTED
   * ------------------------------------------------
   */
  if (status === "REJECTED") {
    return (
      <div className="dashboard-page onboarding-page">
        <section className="onboarding-welcome">
          <div className="onboarding-welcome__content">
            <div className="onboarding-welcome__icon">
              !
            </div>

            <div>
              <p className="dashboard-page__eyebrow">
                ORGANIZATION ACCESS
              </p>

              <h2>
                Request not approved
              </h2>

              <p>
                Your request to join{" "}
                {organizationName} was not
                approved.
              </p>
            </div>
          </div>

          <div className="onboarding-welcome__status">
            <span />
            Request rejected
          </div>
        </section>

        <section className="onboarding-selection">
          <div className="onboarding-selection__header">
            <div>
              <p className="onboarding-selection__eyebrow">
                ORGANIZATION
              </p>

              <h3>
                {organizationName}
              </h3>

              <p>
                You can return to onboarding
                and request access to another
                organization.
              </p>
            </div>
          </div>

          <div className="onboarding-form__error">
            <span>!</span>

            <p>
              {rejectionReason}
            </p>
          </div>

          <div className="onboarding-form__footer">
            <div>
              <strong>
                Choose another organization
              </strong>

              <span>
                Return to onboarding to select
                another verified organization.
              </span>
            </div>

            <button
              type="button"
              className="onboarding-submit"
              onClick={() =>
                router.replace(
                  "/onboarding",
                )
              }
            >
              Back to onboarding
              <span>→</span>
            </button>
          </div>
        </section>
      </div>
    );
  }

  /*
   * ------------------------------------------------
   * APPROVED
   * ------------------------------------------------
   *
   * Normally this state is only visible for an
   * instant because the code immediately redirects.
   */
  if (status === "APPROVED") {
    return (
      <div className="dashboard-page onboarding-page">
        <section className="onboarding-welcome">
          <div className="onboarding-welcome__content">
            <div className="onboarding-welcome__icon">
              ✓
            </div>

            <div>
              <p className="dashboard-page__eyebrow">
                ORGANIZATION ACCESS
              </p>

              <h2>
                Access approved
              </h2>

              <p>
                Your organization access has
                been approved. Opening your
                dashboard...
              </p>
            </div>
          </div>

          <div className="onboarding-welcome__status">
            <span />
            Approved
          </div>
        </section>
      </div>
    );
  }

  /*
   * ------------------------------------------------
   * PENDING / LOADING
   * ------------------------------------------------
   */
  return (
    <div className="dashboard-page onboarding-page">
      <section className="onboarding-welcome">
        <div className="onboarding-welcome__content">
          <div className="onboarding-welcome__icon">
            !
          </div>

          <div>
            <p className="dashboard-page__eyebrow">
              ORGANIZATION ACCESS
            </p>

            <h2>
              Waiting for approval
            </h2>

            <p>
              Your request to join{" "}
              <strong>
                {organizationName}
              </strong>{" "}
              has been submitted successfully.
              The organization administrator must
              approve your request.
            </p>
          </div>
        </div>

        <div className="onboarding-welcome__status">
          <span />
          Awaiting approval
        </div>
      </section>

      <section className="onboarding-info-grid">
        <div className="onboarding-info-card">
          <div className="onboarding-info-card__icon">
            ✓
          </div>

          <div>
            <strong>
              Request submitted
            </strong>

            <span>
              Your request has been sent to the
              organization administrator.
            </span>
          </div>
        </div>

        <div className="onboarding-info-card">
          <div className="onboarding-info-card__icon">
            !
          </div>

          <div>
            <strong>
              Waiting for administrator
            </strong>

            <span>
              The organization administrator
              will review your request.
            </span>
          </div>
        </div>

        <div className="onboarding-info-card">
          <div className="onboarding-info-card__icon">
            →
          </div>

          <div>
            <strong>
              Automatic dashboard access
            </strong>

            <span>
              Once approved, you will be
              automatically taken to the
              organization dashboard.
            </span>
          </div>
        </div>
      </section>

      <section className="onboarding-selection">
        <div className="onboarding-selection__header">
          <div>
            <p className="onboarding-selection__eyebrow">
              ORGANIZATION
            </p>

            <h3>
              {organizationName}
            </h3>

            <p>
              Keep this page open. You do not
              need to refresh it.
            </p>
          </div>

          <div className="onboarding-selection__count">
            <strong>
              PENDING
            </strong>

            <span>
              Access request
            </span>
          </div>
        </div>
      </section>
    </div>
  );
}

