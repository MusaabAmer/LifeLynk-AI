"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";

import {
  decideGovernmentOrganization,
  type GovernmentDecision,
} from "@/lib/dashboard/government-actions";

import type {
  GovernmentData,
  GovernmentOrganization,
} from "@/lib/dashboard/get-government-data";

import { createClient } from "@/lib/supabase/client";

import "./government.css";

interface Props {
  data: GovernmentData;
  currentUser: {
    id: string;
    email: string;
    fullName: string | null;
    role: string;
  };
}

type Status = "ALL" | "PENDING" | "VERIFIED" | "REJECTED";
type Type = "ALL" | "HOSPITAL" | "BLOOD_BANK";
type RegionSort = "availability" | "demand" | "sos";
type CitySort = "availability" | "demand" | "sos";
type CityActivity = "ACTIVE" | "ALL";

const REALTIME_TABLES = [
  "organizations",
  "hospitals",
  "blood_banks",
  "blood_inventory",
  "blood_requests",
  "donors",
  "donor_availability",
  "emergency_sos",
  "donation_history",
  "government_analytics",
] as const;

const fmt = (value: number) =>
  new Intl.NumberFormat().format(value);

const dt = (value: string | null) =>
  value
    ? new Intl.DateTimeFormat("en-PK", {
        dateStyle: "medium",
        timeStyle: "short",
      }).format(new Date(value))
    : "—";

const cap = (value: string) =>
  value
    .replaceAll("_", " ")
    .replace(/\b\w/g, (match) => match.toUpperCase());

function K({
  label,
  value,
  detail,
}: {
  label: string;
  value: number | string;
  detail?: string;
}) {
  return (
    <div className="gov-kpi">
      <small>{label}</small>
      <b>{value}</b>
      {detail && <em>{detail}</em>}
    </div>
  );
}

function Badge({ value }: { value: string }) {
  return (
    <span className={`gov-status ${value.toLowerCase()}`}>
      {value}
    </span>
  );
}

export default function GovernmentClient({
  data,
  currentUser,
}: Props) {
  const router = useRouter();

  /*
   * ---------------------------------------------------------
   * ORGANIZATION FILTERS
   * ---------------------------------------------------------
   *
   * Organizations intentionally remain derived directly from
   * the server-provided data.organizations array.
   *
   * There is no duplicate local organizations state.
   *
   * Therefore:
   *
   * Supabase
   *    ↓
   * getGovernmentData()
   *    ↓
   * GovernmentData
   *    ↓
   * data.organizations
   *    ↓
   * summary / filtered
   *    ↓
   * organization table
   */
  const [q, setQ] = useState("");
  const [status, setStatus] = useState<Status>("ALL");
  const [type, setType] = useState<Type>("ALL");

  /*
   * ---------------------------------------------------------
   * REGION / CITY FILTERS
   * ---------------------------------------------------------
   */
  const [regionSort, setRegionSort] =
    useState<RegionSort>("availability");

  const [citySort, setCitySort] =
    useState<CitySort>("availability");

  const [citySearch, setCitySearch] =
    useState("");

  const [cityProvince, setCityProvince] =
    useState("ALL");

  const [cityActivity, setCityActivity] =
    useState<CityActivity>("ACTIVE");

  const [cityPageSize, setCityPageSize] =
    useState(10);

  const [cityPage, setCityPage] =
    useState(1);

  /*
   * ---------------------------------------------------------
   * ORGANIZATION REVIEW
   * ---------------------------------------------------------
   */
  const [selected, setSelected] =
    useState<GovernmentOrganization | null>(null);

  const [decision, setDecision] =
    useState<GovernmentDecision | null>(null);

  const [notes, setNotes] = useState("");

  const [error, setError] = useState("");

  const [saving, setSaving] = useState(false);

  /*
   * ---------------------------------------------------------
   * REALTIME STATE
   * ---------------------------------------------------------
   */
  const [realtimeConnected, setRealtimeConnected] =
    useState(false);

  const refreshTimer = useRef<
    ReturnType<typeof setTimeout> | null
  >(null);

  /*
   * ---------------------------------------------------------
   * GOVERNMENT REALTIME
   * ---------------------------------------------------------
   *
   * One Supabase channel is used for all government tables.
   *
   * Database change
   *        ↓
   * Supabase Realtime
   *        ↓
   * scheduleRefresh()
   *        ↓
   * router.refresh()
   *        ↓
   * getGovernmentData()
   *        ↓
   * Fresh Government Dashboard
   *
   * A 15-second fallback refresh is also kept so the dashboard
   * remains current even if a realtime event is missed.
   */
  useEffect(() => {
    const supabase = createClient();

    let mounted = true;

    const scheduleRefresh = () => {
      if (refreshTimer.current) {
        clearTimeout(refreshTimer.current);
      }

      refreshTimer.current = setTimeout(() => {
        if (!mounted) {
          return;
        }

        router.refresh();
      }, 350);
    };

    let channel = supabase.channel(
      "government-dashboard-realtime",
    );

    channel = REALTIME_TABLES.reduce(
      (currentChannel, table) =>
        currentChannel.on(
          "postgres_changes",
          {
            event: "*",
            schema: "public",
            table,
          },
          () => {
            if (process.env.NODE_ENV === "development") {
              console.log(
                `GOVERNMENT REALTIME UPDATE: ${table}`,
              );
            }

            scheduleRefresh();
          },
        ),
      channel,
    );

    channel.subscribe((subscriptionStatus) => {
      if (!mounted) {
        return;
      }

      if (subscriptionStatus === "SUBSCRIBED") {
        setRealtimeConnected(true);

        if (process.env.NODE_ENV === "development") {
          console.log(
            "GOVERNMENT DASHBOARD REALTIME CONNECTED",
          );
        }

        return;
      }

      if (subscriptionStatus === "CHANNEL_ERROR") {
        setRealtimeConnected(false);

        console.error(
          "GOVERNMENT DASHBOARD REALTIME CHANNEL ERROR",
        );

        return;
      }

      if (subscriptionStatus === "TIMED_OUT") {
        setRealtimeConnected(false);

        console.error(
          "GOVERNMENT DASHBOARD REALTIME TIMED OUT",
        );

        return;
      }

      /*
       * CLOSED is not treated as an error.
       *
       * Supabase closes channels during cleanup, Fast Refresh,
       * route transitions, and component unmounting.
       */
      if (subscriptionStatus === "CLOSED") {
        setRealtimeConnected(false);

        if (process.env.NODE_ENV === "development") {
          console.log(
            "GOVERNMENT DASHBOARD REALTIME CHANNEL CLOSED",
          );
        }
      }
    });

    const fallbackRefresh = setInterval(() => {
      if (!mounted) {
        return;
      }

      router.refresh();
    }, 15000);

    return () => {
      mounted = false;

      if (refreshTimer.current) {
        clearTimeout(refreshTimer.current);
        refreshTimer.current = null;
      }

      clearInterval(fallbackRefresh);

      setRealtimeConnected(false);

      void supabase.removeChannel(channel);
    };
  }, [router]);

  /*
   * ---------------------------------------------------------
   * ORGANIZATION SUMMARY
   * ---------------------------------------------------------
   */
  const summary = useMemo(
    () => ({
      total: data.organizations.length,

      pending: data.organizations.filter(
        (item) =>
          item.verificationStatus === "PENDING",
      ).length,

      verified: data.organizations.filter(
        (item) =>
          item.verificationStatus === "VERIFIED",
      ).length,

      rejected: data.organizations.filter(
        (item) =>
          item.verificationStatus === "REJECTED",
      ).length,

      hospitals: data.organizations.filter(
        (item) =>
          item.organizationType === "HOSPITAL",
      ).length,

      banks: data.organizations.filter(
        (item) =>
          item.organizationType === "BLOOD_BANK",
      ).length,
    }),
    [data.organizations],
  );

  /*
   * ---------------------------------------------------------
   * ORGANIZATION SEARCH / FILTER
   * ---------------------------------------------------------
   */
  const filtered = useMemo(
    () =>
      data.organizations.filter((organization) => {
        const searchable = [
          organization.name,
          organization.cityName,
          organization.provinceName,
          organization.registrationNumber ?? "",
        ]
          .join(" ")
          .toLowerCase();

        const normalizedQuery =
          q.trim().toLowerCase();

        return (
          (!normalizedQuery ||
            searchable.includes(normalizedQuery)) &&
          (status === "ALL" ||
            organization.verificationStatus ===
              status) &&
          (type === "ALL" ||
            organization.organizationType === type)
        );
      }),
    [data.organizations, q, status, type],
  );

  /*
   * ---------------------------------------------------------
   * PROVINCE SORTING
   * ---------------------------------------------------------
   */
  const regions = useMemo(
    () =>
      [...data.regional].sort(
        (a, b) =>
          regionSort === "demand"
            ? b.requestedUnits -
              a.requestedUnits
            : regionSort === "sos"
              ? b.activeSos -
                a.activeSos
              : b.availableUnits -
                a.availableUnits,
      ),
    [data.regional, regionSort],
  );

  /*
   * ---------------------------------------------------------
   * CITY PROVINCE OPTIONS
   * ---------------------------------------------------------
   */
  const cityProvinces = useMemo(
    () =>
      Array.from(
        new Set(
          data.cities.map(
            (city) => city.provinceName,
          ),
        ),
      ).sort(),
    [data.cities],
  );

  /*
   * ---------------------------------------------------------
   * CITY FILTERING + SORTING
   * ---------------------------------------------------------
   *
   * ACTIVE means a city has at least one meaningful
   * live network signal.
   */
  const filteredCities = useMemo(() => {
    const search =
      citySearch.trim().toLowerCase();

    return data.cities
      .filter((city) => {
        const matchesSearch =
          !search ||
          `${city.name} ${city.provinceName}`
            .toLowerCase()
            .includes(search);

        const matchesProvince =
          cityProvince === "ALL" ||
          city.provinceName === cityProvince;

        const isActive =
          city.organizations > 0 ||
          city.donors > 0 ||
          city.availableUnits > 0 ||
          city.requestedUnits > 0 ||
          city.activeSos > 0;

        const matchesActivity =
          cityActivity === "ALL" ||
          isActive;

        return (
          matchesSearch &&
          matchesProvince &&
          matchesActivity
        );
      })
      .sort((a, b) => {
        if (citySort === "demand") {
          return (
            b.requestedUnits -
            a.requestedUnits
          );
        }

        if (citySort === "sos") {
          return (
            b.activeSos -
            a.activeSos
          );
        }

        return (
          b.availableUnits -
          a.availableUnits
        );
      });
  }, [
    data.cities,
    citySearch,
    cityProvince,
    cityActivity,
    citySort,
  ]);

  /*
 * ---------------------------------------------------------
 * CITY PAGINATION
 * ---------------------------------------------------------
 *
 * Keep the requested page in state, but derive the page
 * that can actually be displayed from the current filtered
 * result set.
 *
 * This avoids synchronously calling setState from effects
 * and keeps pagination compatible with React's current
 * hooks lint rules.
 */

const cityTotalPages = Math.max(
  1,
  Math.ceil(
    filteredCities.length /
      cityPageSize,
  ),
);

const effectiveCityPage = Math.min(
  cityPage,
  cityTotalPages,
);

const paginatedCities = useMemo(() => {
  const start =
    (effectiveCityPage - 1) *
    cityPageSize;

  return filteredCities.slice(
    start,
    start + cityPageSize,
  );
}, [
  filteredCities,
  effectiveCityPage,
  cityPageSize,
]);

  const historical =
    data.historical.slice(0, 12);

  /*
   * ---------------------------------------------------------
   * REVIEW ORGANIZATION
   * ---------------------------------------------------------
   */
  const review = (
    organization: GovernmentOrganization,
  ) => {
    setSelected(organization);
    setDecision(null);
    setNotes(
      organization.verificationNotes ?? "",
    );
    setError("");
  };

  /*
   * ---------------------------------------------------------
   * VERIFY / REJECT ORGANIZATION
   * ---------------------------------------------------------
   */
  const submit = async () => {
    if (!selected || !decision) {
      return;
    }

    const trimmed = notes.trim();

    if (
      decision === "REJECT" &&
      trimmed.length < 5
    ) {
      setError(
        "A rejection reason of at least 5 characters is required.",
      );
      return;
    }

    setSaving(true);
    setError("");

    const result =
      await decideGovernmentOrganization(
        selected.id,
        decision,
        trimmed,
      );

    if (!result.success) {
      setError(
        result.error ??
          "Unable to process decision.",
      );
      setSaving(false);
      return;
    }

    setSaving(false);
    setSelected(null);
    setDecision(null);

    router.refresh();
  };

  return (
    <main className="government-page">
      {/* =====================================================
          HEADER
      ===================================================== */}

      <header className="gov-header">
        <div>
          <small className="eyebrow">
            LIFELYNK AI · GOVERNMENT CONTROL CENTER
          </small>

          <h1>National Healthcare Network</h1>

          <p>
            Live oversight of blood supply,
            demand, donor activity, emergency
            response, regional capacity,
            facilities, and regulatory
            verification.
          </p>
        </div>

        <div className="gov-user">
          <b>
            {currentUser.fullName ||
              currentUser.email}
          </b>

          <small>
            {cap(currentUser.role)}
          </small>

          <small
            title={
              realtimeConnected
                ? "Government dashboard realtime is connected."
                : "Government dashboard realtime is connecting or unavailable."
            }
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: "6px",
              marginTop: "4px",
              opacity: 0.8,
            }}
          >
            <span
              aria-hidden="true"
              style={{
                width: "7px",
                height: "7px",
                borderRadius: "999px",
                display: "inline-block",
                background:
                  realtimeConnected
                    ? "currentColor"
                    : "transparent",
                border:
                  realtimeConnected
                    ? "none"
                    : "1px solid currentColor",
              }}
            />

            {realtimeConnected
              ? "Live"
              : "Connecting"}
          </small>
        </div>
      </header>

      {/* =====================================================
          NATIONAL KPIs
      ===================================================== */}

      <section className="gov-kpis">
        <K
          label="Organizations"
          value={fmt(summary.total)}
          detail={`${fmt(summary.verified)} verified`}
        />

        <K
          label="Hospitals"
          value={fmt(summary.hospitals)}
          detail={`${fmt(summary.banks)} blood banks`}
        />

        <K
          label="Available Blood"
          value={fmt(
            data.bloodNetwork.availableUnits,
          )}
          detail={`${fmt(
            data.bloodNetwork.totalUnits,
          )} total units`}
        />

        <K
          label="Active SOS"
          value={data.emergency.active}
          detail={`${data.emergency.pending} pending`}
        />

        <K
          label="Blood Requests"
          value={fmt(
            data.bloodRequests.total,
          )}
          detail={`${fmt(
            data.bloodRequests.requestedUnits,
          )} units`}
        />

        <K
          label="Available Donors"
          value={fmt(data.donors.available)}
          detail={`${fmt(
            data.donors.total,
          )} registered`}
        />
      </section>

      {/* =====================================================
          GOVERNMENT ALERTS
      ===================================================== */}

      {data.alerts.length > 0 && (
        <section className="gov-panel">
          <div className="section-head">
            <div>
              <small className="eyebrow">
                OPERATIONS
              </small>

              <h2>Government Alerts</h2>
            </div>
          </div>

          <div className="alerts">
            {data.alerts.map((alert) => (
              <div
                className={`alert ${alert.severity}`}
                key={alert.type}
              >
                <b>{alert.title}</b>

                <p>{alert.message}</p>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* =====================================================
          NATIONAL INVENTORY + SUPPLY RISK
      ===================================================== */}

      <section className="two">
        <section className="gov-panel">
          <div className="section-head">
            <div>
              <small className="eyebrow">
                BLOOD NETWORK
              </small>

              <h2>National Inventory</h2>
            </div>

            <span>
              {fmt(
                data.bloodNetwork
                  .reservedUnits,
              )}{" "}
              reserved
            </span>
          </div>

          <div className="blood-total">
            <div>
              Available{" "}
              <b>
                {fmt(
                  data.bloodNetwork
                    .availableUnits,
                )}
              </b>
            </div>

            <div>
              Total{" "}
              <b>
                {fmt(
                  data.bloodNetwork
                    .totalUnits,
                )}
              </b>
            </div>
          </div>

          {data.bloodNetwork.bloodGroups.map(
            (group) => {
              const percentage =
                group.totalUnits
                  ? Math.min(
                      100,
                      (group.availableUnits /
                        group.totalUnits) *
                        100,
                    )
                  : 0;

              return (
                <div
                  className="blood-row"
                  key={group.id}
                >
                  <b>{group.code}</b>

                  <div className="bar">
                    <i
                      style={{
                        width: `${percentage}%`,
                      }}
                    />
                  </div>

                  <span>
                    {fmt(
                      group.availableUnits,
                    )}{" "}
                    /{" "}
                    {fmt(
                      group.totalUnits,
                    )}
                  </span>
                </div>
              );
            },
          )}
        </section>

        <section className="gov-panel">
          <div className="section-head">
            <div>
              <small className="eyebrow">
                INVENTORY RISK
              </small>

              <h2>Supply Risk</h2>
            </div>
          </div>

          <div className="risk-grid">
            <K
              label="Low stock groups"
              value={
                data.bloodNetwork.risk
                  .lowStockGroups
              }
            />

            <K
              label="Shortage groups"
              value={
                data.bloodNetwork.risk
                  .shortageGroups
              }
            />

            <K
              label="Expired units"
              value={fmt(
                data.bloodNetwork.risk
                  .expiredUnits,
              )}
            />

            <K
              label="Expiring = 7d"
              value={fmt(
                data.bloodNetwork.risk
                  .expiringSoonUnits,
              )}
            />
          </div>

          {data.bloodNetwork.bloodGroups
            .filter(
              (group) =>
                group.shortageUnits > 0,
            )
            .map((group) => (
              <div
                className="line"
                key={group.code}
              >
                <span>
                  {group.code} shortage
                </span>

                <b className="danger">
                  {fmt(
                    group.shortageUnits,
                  )}{" "}
                  units
                </b>
              </div>
            ))}
        </section>
      </section>

      {/* =====================================================
          SOS + BLOOD REQUEST ANALYTICS
      ===================================================== */}

      <section className="two">
        <section className="gov-panel">
          <div className="section-head">
            <div>
              <small className="eyebrow">
                EMERGENCY RESPONSE
              </small>

              <h2>SOS Analytics</h2>
            </div>

            <span>
              {fmt(
                data.emergency
                  .requestedUnits,
              )}{" "}
              units requested
            </span>
          </div>

          <div className="mini">
            <K
              label="Pending"
              value={
                data.emergency.pending
              }
            />

            <K
              label="Active"
              value={
                data.emergency.active
              }
            />

            <K
              label="Resolved"
              value={
                data.emergency.resolved
              }
            />

            <K
              label="Cancelled"
              value={
                data.emergency.cancelled
              }
            />
          </div>

          {data.emergency.byUrgency.map(
            (item) => (
              <div
                className="line"
                key={item.urgency}
              >
                <span>
                  {cap(item.urgency)}
                </span>

                <b>{item.count}</b>
              </div>
            ),
          )}
        </section>

        <section className="gov-panel">
          <div className="section-head">
            <div>
              <small className="eyebrow">
                DEMAND
              </small>

              <h2>Blood Requests</h2>
            </div>
          </div>

          <div className="mini">
            <K
              label="Total"
              value={
                data.bloodRequests.total
              }
            />

            <K
              label="Pending"
              value={
                data.bloodRequests.pending
              }
            />

            <K
              label="Active"
              value={
                data.bloodRequests.active
              }
            />

            <K
              label="Completed"
              value={
                data.bloodRequests.completed
              }
            />
          </div>

          {data.bloodRequests.byBloodGroup
            .filter(
              (item) => item.requests,
            )
            .map((item) => (
              <div
                className="line"
                key={item.code}
              >
                <span>
                  {item.code} ·{" "}
                  {item.requests} requests
                </span>

                <b>
                  {fmt(
                    item.unitsRequired,
                  )}{" "}
                  units
                </b>
              </div>
            ))}
        </section>
      </section>

      {/* =====================================================
          DONOR ACTIVITY + FACILITY HEALTH
      ===================================================== */}

      <section className="two">
        <section className="gov-panel">
          <div className="section-head">
            <div>
              <small className="eyebrow">
                DONOR NETWORK
              </small>

              <h2>
                Availability & Activity
              </h2>
            </div>
          </div>

          <div className="donor">
            <div>
              Registered{" "}
              <b>
                {fmt(data.donors.total)}
              </b>
            </div>

            <div>
              Available{" "}
              <b>
                {fmt(
                  data.donors.available,
                )}
              </b>
            </div>

            <div>
              Donations{" "}
              <b>
                {fmt(
                  data.donors.activity
                    .totalDonations,
                )}
              </b>
            </div>

            <div>
              Donated units{" "}
              <b>
                {fmt(
                  data.donors.activity
                    .totalUnits,
                )}
              </b>
            </div>
          </div>

          <div className="mini">
            <K
              label="Verified donations"
              value={
                data.donors.activity
                  .verifiedDonations
              }
            />

            <K
              label="Last 30 days"
              value={
                data.donors.activity
                  .recent30Days
              }
            />

            <K
              label="Last 90 days"
              value={
                data.donors.activity
                  .recent90Days
              }
            />

            <K
              label="Unavailable"
              value={
                data.donors.unavailable
              }
            />
          </div>

          {data.donors.activity.byBloodGroup
            .filter(
              (item) => item.donations,
            )
            .map((item) => (
              <div
                className="line"
                key={item.code}
              >
                <span>
                  {item.code} ·{" "}
                  {item.donations} donations
                </span>

                <b>
                  {fmt(item.units)} units
                </b>
              </div>
            ))}
        </section>

        <section className="gov-panel">
          <div className="section-head">
            <div>
              <small className="eyebrow">
                FACILITY CAPACITY
              </small>

              <h2>Network Health</h2>
            </div>
          </div>

          <div className="mini">
            <K
              label="Verified"
              value={
                data.facilityHealth
                  .verified
              }
            />

            <K
              label="Pending"
              value={
                data.facilityHealth
                  .pending
              }
            />

            <K
              label="Cities"
              value={
                data.facilityHealth
                  .citiesCovered
              }
            />

            <K
              label="Provinces"
              value={
                data.facilityHealth
                  .provincesCovered
              }
            />
          </div>

          <div className="line">
            <span>
              Hospitals with emergency
              service
            </span>

            <b>
              {
                data.facilityHealth
                  .hospitalsWithEmergency
              }
            </b>
          </div>

          <div className="line">
            <span>
              Hospitals with blood storage
            </span>

            <b>
              {
                data.facilityHealth
                  .hospitalsWithBloodStorage
              }
            </b>
          </div>

          <div className="line">
            <span>
              Hospitals with ICU
            </span>

            <b>
              {
                data.facilityHealth
                  .hospitalsWithIcu
              }
            </b>
          </div>

          <div className="line">
            <span>
              Banks with cold storage
            </span>

            <b>
              {
                data.facilityHealth
                  .bloodBanksWithColdStorage
              }
            </b>
          </div>

          <div className="line">
            <span>
              Banks with processing
            </span>

            <b>
              {
                data.facilityHealth
                  .bloodBanksWithProcessing
              }
            </b>
          </div>
        </section>
      </section>

      {/* =====================================================
          PROVINCE NETWORK
      ===================================================== */}

      <section className="gov-panel">
        <div className="section-head">
          <div>
            <small className="eyebrow">
              REGIONAL MONITORING
            </small>

            <h2>Province Network</h2>
          </div>

          <select
            value={regionSort}
            onChange={(event) =>
              setRegionSort(
                event.target.value as RegionSort,
              )
            }
          >
            <option value="availability">
              Blood availability
            </option>

            <option value="demand">
              Blood demand
            </option>

            <option value="sos">
              Active SOS
            </option>
          </select>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Province</th>
                <th>Organizations</th>
                <th>Donors</th>
                <th>Available Blood</th>
                <th>Requests</th>
                <th>Active SOS</th>
              </tr>
            </thead>

            <tbody>
              {regions.map((region) => (
                <tr key={region.id}>
                  <td>
                    <b>{region.name}</b>

                    <small>
                      {region.code}
                    </small>
                  </td>

                  <td>
                    {region.organizations}

                    <small>
                      {region.hospitals} hospitals
                      {" · "}
                      {region.bloodBanks} banks
                    </small>
                  </td>

                  <td>
                    {region.availableDonors}

                    <small>
                      / {region.donors} available
                    </small>
                  </td>

                  <td>
                    <b>
                      {fmt(
                        region.availableUnits,
                      )}
                    </b>

                    <small>
                      /{" "}
                      {fmt(
                        region.bloodUnits,
                      )}{" "}
                      total
                    </small>
                  </td>

                  <td>
                    {region.bloodRequests}

                    <small>
                      {fmt(
                        region.requestedUnits,
                      )}{" "}
                      units
                    </small>
                  </td>

                  <td
                    className={
                      region.activeSos
                        ? "danger"
                        : ""
                    }
                  >
                    {region.activeSos}

                    <small>
                      {region.sos} total
                    </small>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {!regions.length && (
            <div className="empty">
              No province data is available.
            </div>
          )}
        </div>
      </section>

      {/* =====================================================
          CITY INTELLIGENCE
      ===================================================== */}

      <section className="gov-panel">
        <div className="section-head wrap">
          <div>
            <small className="eyebrow">
              CITY INTELLIGENCE
            </small>

            <h2>City-Level Breakdown</h2>
          </div>

          <div className="filters">
            <input
              value={citySearch}
              onChange={(event) =>
                setCitySearch(
                  event.target.value,
                )
              }
              placeholder="Search city..."
              aria-label="Search cities"
            />

            <select
              value={cityProvince}
              onChange={(event) =>
                setCityProvince(
                  event.target.value,
                )
              }
              aria-label="Filter cities by province"
            >
              <option value="ALL">
                All provinces
              </option>

              {cityProvinces.map(
                (province) => (
                  <option
                    key={province}
                    value={province}
                  >
                    {province}
                  </option>
                ),
              )}
            </select>

            <select
              value={cityActivity}
              onChange={(event) =>
                setCityActivity(
                  event.target.value as CityActivity,
                )
              }
              aria-label="Filter city activity"
            >
              <option value="ACTIVE">
                Active cities
              </option>

              <option value="ALL">
                All cities
              </option>
            </select>

            <select
              value={citySort}
              onChange={(event) =>
                setCitySort(
                  event.target.value as CitySort,
                )
              }
              aria-label="Sort cities"
            >
              <option value="availability">
                Blood availability
              </option>

              <option value="demand">
                Demand
              </option>

              <option value="sos">
                Active SOS
              </option>
            </select>

            <select
              value={cityPageSize}
              onChange={(event) =>
                setCityPageSize(
                  Number(event.target.value),
                )
              }
              aria-label="Cities per page"
            >
              <option value={10}>
                10 / page
              </option>

              <option value={20}>
                20 / page
              </option>

              <option value={50}>
                50 / page
              </option>
            </select>
          </div>
        </div>

        <div className="chips">
          <span>
            {fmt(filteredCities.length)} cities
          </span>

          <span>
            Page {cityPage} of{" "}
            {cityTotalPages}
          </span>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>City</th>
                <th>Province</th>
                <th>Facilities</th>
                <th>Donors</th>
                <th>Available Blood</th>
                <th>Requested</th>
                <th>Active SOS</th>
              </tr>
            </thead>

            <tbody>
              {paginatedCities.map((city) => (
                <tr key={city.id}>
                  <td>
                    <b>{city.name}</b>
                  </td>

                  <td>
                    {city.provinceName}
                  </td>

                  <td>
                    {city.organizations}

                    <small>
                      {city.hospitals} hospitals
                      {" · "}
                      {city.bloodBanks} banks
                    </small>
                  </td>

                  <td>
                    {city.availableDonors}

                    <small>
                      / {city.donors} available
                    </small>
                  </td>

                  <td>
                    <b>
                      {fmt(
                        city.availableUnits,
                      )}
                    </b>
                  </td>

                  <td>
                    {fmt(
                      city.requestedUnits,
                    )}
                  </td>

                  <td
                    className={
                      city.activeSos
                        ? "danger"
                        : ""
                    }
                  >
                    {city.activeSos}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {!paginatedCities.length && (
            <div className="empty">
              {cityActivity === "ACTIVE"
                ? "No active city data matches the current filters."
                : "No city data is available."}
            </div>
          )}
        </div>

        {filteredCities.length > 0 &&
          cityTotalPages > 1 && (
            <div
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                gap: "12px",
                marginTop: "16px",
                flexWrap: "wrap",
              }}
            >
              <small>
                Showing{" "}
                {Math.min(
                  (cityPage - 1) *
                    cityPageSize +
                    1,
                  filteredCities.length,
                )}
                {"–"}
                {Math.min(
                  cityPage * cityPageSize,
                  filteredCities.length,
                )}{" "}
                of{" "}
                {fmt(
                  filteredCities.length,
                )}
              </small>

              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: "8px",
                }}
              >
                <button
                  type="button"
                  onClick={() =>
                    setCityPage((page) =>
                      Math.max(1, page - 1),
                    )
                  }
                  disabled={cityPage <= 1}
                >
                  Previous
                </button>

                <span>
                  {cityPage} /{" "}
                  {cityTotalPages}
                </span>

                <button
                  type="button"
                  onClick={() =>
                    setCityPage((page) =>
                      Math.min(
                        cityTotalPages,
                        page + 1,
                      ),
                    )
                  }
                  disabled={
                    cityPage >=
                    cityTotalPages
                  }
                >
                  Next
                </button>
              </div>
            </div>
          )}
      </section>

      {/* =====================================================
          DETAILED SOS MONITORING
      ===================================================== */}

      <section className="gov-panel">
        <div className="section-head">
          <div>
            <small className="eyebrow">
              EMERGENCY OPERATIONS
            </small>

            <h2>Detailed SOS Monitoring</h2>
          </div>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Status</th>
                <th>Urgency</th>
                <th>Blood</th>
                <th>Units</th>
                <th>Location</th>
                <th>Created</th>
              </tr>
            </thead>

            <tbody>
              {data.emergency.records
                .slice(0, 50)
                .map((sos) => (
                  <tr key={sos.id}>
                    <td>
                      <Badge
                        value={sos.status.toUpperCase()}
                      />
                    </td>

                    <td
                      className={
                        sos.urgency.toLowerCase() ===
                        "critical"
                          ? "danger"
                          : ""
                      }
                    >
                      {cap(sos.urgency)}
                    </td>

                    <td>
                      <b>{sos.bloodGroup}</b>
                    </td>

                    <td>
                      {sos.unitsRequired}
                    </td>

                    <td>
                      {sos.cityName}

                      <small>
                        {sos.provinceName}
                      </small>
                    </td>

                    <td>
                      {dt(sos.createdAt)}
                    </td>
                  </tr>
                ))}
            </tbody>
          </table>

          {!data.emergency.records.length && (
            <div className="empty">
              No SOS records are available.
            </div>
          )}
        </div>
      </section>

      {/* =====================================================
          GOVERNMENT ANALYTICS
      ===================================================== */}

      <section className="gov-panel">
        <div className="section-head">
          <div>
            <small className="eyebrow">
              GOVERNMENT ANALYTICS
            </small>

            <h2>
              {historical.length
                ? "Historical Metrics"
                : "Live Government Metrics"}
            </h2>
          </div>

          <span>
            {historical.length
              ? "Latest stored records"
              : data.analyticsSource ===
                  "LIVE"
                ? `Live · ${dt(
                    data.lastUpdatedAt,
                  )}`
                : "Current network snapshot"}
          </span>
        </div>

        {historical.length ? (
          <div className="history-grid">
            {historical.map(
              (item, index) => (
                <div
                  className="history-card"
                  key={`${item.metricName}-${item.generatedAt}-${index}`}
                >
                  <small>
                    {cap(
                      item.metricName,
                    )}
                  </small>

                  <b>
                    {fmt(item.value)}
                  </b>

                  <span>
                    {item.region
                      ? `${item.region} · `
                      : ""}

                    {dt(
                      item.generatedAt,
                    )}
                  </span>
                </div>
              ),
            )}
          </div>
        ) : data.liveAnalytics &&
          data.liveAnalytics.length ? (
          <div className="history-grid">
            {data.liveAnalytics.map(
              (item, index) => (
                <div
                  className="history-card"
                  key={`${item.metricName}-${item.generatedAt}-${item.region ?? "national"}-${index}`}
                >
                  <small>
                    {cap(
                      item.metricName,
                    )}
                  </small>

                  <b>
                    {fmt(item.value)}
                  </b>

                  <span>
                    {item.region
                      ? `${item.region} · `
                      : "National · "}

                    {dt(
                      item.generatedAt,
                    )}
                  </span>
                </div>
              ),
            )}
          </div>
        ) : (
          <div className="empty">
            Live government analytics are
            currently unavailable.
          </div>
        )}
      </section>

      {/* =====================================================
          ORGANIZATION VERIFICATION
      ===================================================== */}

      <section className="gov-panel">
        <div className="section-head wrap">
          <div>
            <small className="eyebrow">
              REGULATORY CONTROL
            </small>

            <h2>
              Organization Verification
            </h2>
          </div>

          <div className="filters">
            <input
              value={q}
              onChange={(event) =>
                setQ(event.target.value)
              }
              placeholder="Search organization, city, province..."
              aria-label="Search organizations"
            />

            <select
              value={status}
              onChange={(event) =>
                setStatus(
                  event.target.value as Status,
                )
              }
              aria-label="Filter organizations by status"
            >
              <option value="ALL">
                All statuses
              </option>

              <option value="PENDING">
                Pending
              </option>

              <option value="VERIFIED">
                Verified
              </option>

              <option value="REJECTED">
                Rejected
              </option>
            </select>

            <select
              value={type}
              onChange={(event) =>
                setType(
                  event.target.value as Type,
                )
              }
              aria-label="Filter organizations by type"
            >
              <option value="ALL">
                All organizations
              </option>

              <option value="HOSPITAL">
                Hospitals
              </option>

              <option value="BLOOD_BANK">
                Blood banks
              </option>
            </select>
          </div>
        </div>

        <div className="chips">
          <span>
            {summary.pending} pending
          </span>

          <span>
            {summary.verified} verified
          </span>

          <span>
            {summary.rejected} rejected
          </span>

          <span>
            {filtered.length} shown
          </span>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Organization</th>
                <th>Type</th>
                <th>Location</th>
                <th>Registration</th>
                <th>Status</th>
                <th>Registered</th>
                <th />
              </tr>
            </thead>

            <tbody>
              {filtered.map(
                (organization) => (
                  <tr
                    key={
                      organization.id
                    }
                  >
                    <td>
                      <b>
                        {organization.name}
                      </b>

                      <small>
                        {organization.phone}
                      </small>
                    </td>

                    <td>
                      {organization.organizationType ===
                      "HOSPITAL"
                        ? "Hospital"
                        : "Blood Bank"}
                    </td>

                    <td>
                      {
                        organization.cityName
                      }

                      <small>
                        {
                          organization.provinceName
                        }
                      </small>
                    </td>

                    <td>
                      {
                        organization.registrationNumber ??
                        "—"
                      }
                    </td>

                    <td>
                      <Badge
                        value={
                          organization.verificationStatus
                        }
                      />
                    </td>

                    <td>
                      {dt(
                        organization.createdAt,
                      )}
                    </td>

                    <td>
                      <button
                        type="button"
                        onClick={() =>
                          review(
                            organization,
                          )
                        }
                      >
                        Review
                      </button>
                    </td>
                  </tr>
                ),
              )}
            </tbody>
          </table>

          {!filtered.length && (
            <div className="empty">
              No organizations match the
              current filters.
            </div>
          )}
        </div>
      </section>

      {/* =====================================================
          ORGANIZATION REVIEW MODAL
      ===================================================== */}

      {selected && (
        <div
          className="backdrop"
          onMouseDown={() =>
            !saving &&
            setSelected(null)
          }
        >
          <div
            className="modal"
            onMouseDown={(event) =>
              event.stopPropagation()
            }
          >
            <div className="modal-head">
              <div>
                <small className="eyebrow">
                  ORGANIZATION REVIEW
                </small>

                <h2>
                  {selected.name}
                </h2>
              </div>

              <button
                type="button"
                className="close"
                onClick={() =>
                  setSelected(null)
                }
                disabled={saving}
              >
                ×
              </button>
            </div>

            <div className="details">
              {[
                [
                  "Type",
                  selected.organizationType,
                ],
                [
                  "Status",
                  selected.verificationStatus,
                ],
                [
                  "Registration",
                  selected.registrationNumber ??
                    "—",
                ],
                [
                  "License",
                  selected.licenseNumber ??
                    "—",
                ],
                [
                  "City",
                  selected.cityName,
                ],
                [
                  "Province",
                  selected.provinceName,
                ],
                [
                  "Phone",
                  selected.phone,
                ],
                [
                  "Email",
                  selected.email ?? "—",
                ],
                [
                  "Address",
                  selected.address,
                ],
              ].map(
                ([label, value]) => (
                  <div key={label}>
                    <small>{label}</small>
                    <b>{value}</b>
                  </div>
                ),
              )}

              {selected.organizationType ===
                "HOSPITAL" && (
                <>
                  <div>
                    <small>
                      Hospital type
                    </small>

                    <b>
                      {
                        selected.hospitalType ??
                        "—"
                      }
                    </b>
                  </div>

                  <div>
                    <small>
                      Total beds
                    </small>

                    <b>
                      {
                        selected.totalBeds ??
                        "—"
                      }
                    </b>
                  </div>

                  <div>
                    <small>
                      Emergency
                    </small>

                    <b>
                      {selected.emergencyService
                        ? "Yes"
                        : "No"}
                    </b>
                  </div>

                  <div>
                    <small>ICU</small>

                    <b>
                      {selected.icuAvailable
                        ? "Yes"
                        : "No"}
                    </b>
                  </div>
                </>
              )}

              {selected.organizationType ===
                "BLOOD_BANK" && (
                <>
                  <div>
                    <small>
                      Storage capacity
                    </small>

                    <b>
                      {
                        selected.storageCapacity ??
                        "—"
                      }
                    </b>
                  </div>

                  <div>
                    <small>
                      Cold storage
                    </small>

                    <b>
                      {selected.coldStorageAvailable
                        ? "Yes"
                        : "No"}
                    </b>
                  </div>

                  <div>
                    <small>
                      Processing
                    </small>

                    <b>
                      {selected.bloodProcessingAvailable
                        ? "Yes"
                        : "No"}
                    </b>
                  </div>

                  <div>
                    <small>
                      Operating hours
                    </small>

                    <b>
                      {
                        selected.operatingHours ??
                        "—"
                      }
                    </b>
                  </div>
                </>
              )}
            </div>

            {selected.verificationStatus ===
            "PENDING" ? (
              <div className="decision">
                <label>
                  Decision
                </label>

                <div>
                  <button
                    type="button"
                    className={
                      decision === "VERIFY"
                        ? "chosen"
                        : ""
                    }
                    onClick={() =>
                      setDecision(
                        "VERIFY",
                      )
                    }
                    disabled={saving}
                  >
                    Verify
                  </button>

                  <button
                    type="button"
                    className={
                      decision ===
                      "REJECT"
                        ? "reject chosen"
                        : "reject"
                    }
                    onClick={() =>
                      setDecision(
                        "REJECT",
                      )
                    }
                    disabled={saving}
                  >
                    Reject
                  </button>
                </div>

                <label>
                  Notes{" "}
                  {decision ===
                    "REJECT" &&
                    "(required)"}
                </label>

                <textarea
                  rows={4}
                  value={notes}
                  onChange={(event) =>
                    setNotes(
                      event.target.value,
                    )
                  }
                  placeholder={
                    decision === "REJECT"
                      ? "Enter rejection reason..."
                      : "Optional review notes..."
                  }
                  disabled={saving}
                />

                {error && (
                  <p className="error">
                    {error}
                  </p>
                )}
              </div>
            ) : (
              <div className="existing">
                <small>
                  Verification notes
                </small>

                <p>
                  {selected.verificationNotes ??
                    "No notes recorded."}
                </p>
              </div>
            )}

            <div className="modal-actions">
              <button
                type="button"
                onClick={() =>
                  setSelected(null)
                }
                disabled={saving}
              >
                Close
              </button>

              {selected.verificationStatus ===
                "PENDING" &&
                decision && (
                  <button
                    type="button"
                    className="primary"
                    onClick={() =>
                      void submit()
                    }
                    disabled={saving}
                  >
                    {saving
                      ? "Processing..."
                      : decision ===
                          "VERIFY"
                        ? "Confirm verification"
                        : "Confirm rejection"}
                  </button>
                )}
            </div>
          </div>
        </div>
      )}
    </main>
  );
}