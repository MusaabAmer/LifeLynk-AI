import { redirect } from "next/navigation";
import "./dashboard.css";

import { getCurrentUser } from "@/lib/auth/get-current-user";
import { getDashboardData } from "@/lib/dashboard/get-dashboard-data";
import PakistanBloodMap from "@/components/dashboard/pakistan-blood-map";
import OrganizationJoinRequestsCard from "./organization-join-requests-card";

export default async function DashboardPage() {
  const currentUser = await getCurrentUser();

  if (!currentUser) {
    redirect("/login");
  }

  const dashboardData = await getDashboardData(
    currentUser.id,
    currentUser.role,
    currentUser.organizationId,
  );

  const {
    role,
    fullName,
    organizationName,
    organizationType,
  } = currentUser;

  const isGovernment =
    role === "GOVERNMENT_ADMIN";

  const isSuperAdmin =
    role === "SUPER_ADMIN";

  const isHospital =
    role === "HOSPITAL_ADMIN" ||
    (role === "STAFF" &&
      organizationType === "HOSPITAL");

  const isBloodBank =
    role === "BLOOD_BANK_ADMIN" ||
    (role === "STAFF" &&
      organizationType === "BLOOD_BANK");

  const displayName =
    fullName?.trim() || "Administrator";

  const bloodInventory =
    dashboardData.bloodInventory;

  const maxAvailableUnits = Math.max(
    ...bloodInventory.groupSummaries.map(
      (group) => group.availableUnits,
    ),
    1,
  );

  const canViewBloodNetwork =
    isBloodBank ||
    isHospital ||
    isGovernment ||
    isSuperAdmin;

  return (
    <div className="dashboard-page">
      {/* ==================================================
          WELCOME
          ================================================== */}

      <section className="dashboard-page__welcome">
        <div>
          <p className="dashboard-page__eyebrow">
            OVERVIEW
          </p>

          <h2>
            Welcome, {displayName}
          </h2>

          <p>
            {organizationName
              ? `${organizationName} — LifeLynk AI healthcare network.`
              : isGovernment
                ? "Monitor the connected healthcare and blood availability network."
                : isSuperAdmin
                  ? "Manage and monitor the complete LifeLynk AI platform."
                  : "Welcome to the LifeLynk AI healthcare network."}
          </p>
        </div>

        <div className="dashboard-page__live">
          <span />
          Live system
        </div>
      </section>

            {/* ==================================================
          ROLE
          ================================================== */}

      <section className="dashboard-role">
        <div>
          <p className="dashboard-role__label">
            ACCESS ROLE
          </p>

          <strong>
            {role.replaceAll("_", " ")}
          </strong>
        </div>

        {organizationName && (
          <div>
            <p className="dashboard-role__label">
              ORGANIZATION
            </p>

            <strong>
              {organizationName}
            </strong>
          </div>
        )}
      </section>

      {/* ==================================================
          ORGANIZATION MEMBER REQUESTS
          ================================================== */}

      {(role === "HOSPITAL_ADMIN" ||
        role === "BLOOD_BANK_ADMIN") && (
        <OrganizationJoinRequestsCard />
      )}

      {/* ==================================================
          STATISTICS
          ================================================== */}

      <section className="dashboard-stats">
        {canViewBloodNetwork && (
          <article className="dashboard-stat">
            <span className="dashboard-stat__icon">
              🩸
            </span>

            <div>
              <p>Blood Inventory</p>

              <strong>
                {bloodInventory.availableUnits}
              </strong>
            </div>

            <span className="dashboard-stat__label">
              Available
            </span>
          </article>
        )}

        {(isHospital ||
          isGovernment ||
          isSuperAdmin) && (
          <article className="dashboard-stat">
            <span className="dashboard-stat__icon">
              🚨
            </span>

            <div>
              <p>Emergency SOS</p>

              <strong>
                {dashboardData.emergencySos.active}
              </strong>
            </div>

            <span className="dashboard-stat__label">
              Active
            </span>
          </article>
        )}

        {(isHospital ||
          isBloodBank ||
          isGovernment ||
          isSuperAdmin) && (
          <article className="dashboard-stat">
            <span className="dashboard-stat__icon">
              👥
            </span>

            <div>
              <p>Registered Donors</p>

              <strong>
                {dashboardData.donors.total}
              </strong>
            </div>

            <span className="dashboard-stat__label">
              Network
            </span>
          </article>
        )}

        {(isGovernment ||
          isSuperAdmin) && (
          <article className="dashboard-stat">
            <span className="dashboard-stat__icon">
              🏥
            </span>

            <div>
              <p>Healthcare Facilities</p>

              <strong>
                {dashboardData.healthcareFacilities.total}
              </strong>
            </div>

            <span className="dashboard-stat__label">
              Connected
            </span>
          </article>
        )}
      </section>

      {/* ==================================================
          PAKISTAN BLOOD NETWORK MAP
          ================================================== */}

      {canViewBloodNetwork && (
        <section className="dashboard-map-panel">
          <div className="dashboard-map-panel__header">
            <div>
              <p>
                NATIONAL BLOOD NETWORK
              </p>

              <h3>
                Pakistan blood availability
              </h3>

              <span>
                Live inventory distribution
                across the connected network
              </span>
            </div>

            <div className="dashboard-map-panel__status">
              <span />
              Live data
            </div>
          </div>

          <div className="dashboard-map-panel__body">
            <PakistanBloodMap
              provinceInventory={
                dashboardData.provinceInventory
              }
            />
          </div>
        </section>
      )}

      {/* ==================================================
          PANELS
          ================================================== */}

      <section className="dashboard-panels">
        {/* Emergency */}

        {(isHospital ||
          isGovernment ||
          isSuperAdmin) && (
          <article className="dashboard-panel">
            <div className="dashboard-panel__header">
              <div>
                <p>
                  EMERGENCY RESPONSE
                </p>

                <h3>
                  Recent SOS activity
                </h3>
              </div>

              <span>
                Live
              </span>
            </div>

            <div className="dashboard-panel__empty">
              <div>
                🚨
              </div>

              <strong>
                No emergency activity loaded
              </strong>

              <p>
                Real-time SOS activity will
                appear here.
              </p>
            </div>
          </article>
        )}

        {/* Blood inventory */}

        {canViewBloodNetwork && (
          <article className="dashboard-panel dashboard-panel--inventory">
            <div className="dashboard-panel__header">
              <div>
                <p>
                  BLOOD NETWORK
                </p>

                <h3>
                  Inventory overview
                </h3>
              </div>

              <span>
                {bloodInventory.availableUnits > 0
                  ? "Available"
                  : "Empty"}
              </span>
            </div>

            {/* Inventory metrics */}

            <div className="dashboard-inventory__metrics">
              <div>
                <span>
                  Available
                </span>

                <strong>
                  {bloodInventory.availableUnits}
                </strong>

                <small>
                  units
                </small>
              </div>

              <div>
                <span>
                  Reserved
                </span>

                <strong>
                  {bloodInventory.reservedUnits}
                </strong>

                <small>
                  units
                </small>
              </div>

              <div>
                <span>
                  Total
                </span>

                <strong>
                  {bloodInventory.totalUnits}
                </strong>

                <small>
                  units
                </small>
              </div>

              <div>
                <span>
                  Records
                </span>

                <strong>
                  {bloodInventory.totalRecords}
                </strong>

                <small>
                  {bloodInventory.totalRecords === 1
                    ? "record"
                    : "records"}
                </small>
              </div>
            </div>

            {/* Blood group breakdown */}

            <div className="dashboard-inventory__groups">
              <div className="dashboard-inventory__groups-header">
                <div>
                  <strong>
                    Blood group availability
                  </strong>

                  <span>
                    {bloodInventory.bloodGroupCount}{" "}
                    {bloodInventory.bloodGroupCount === 1
                      ? "group"
                      : "groups"}{" "}
                    tracked
                  </span>
                </div>
              </div>

              {bloodInventory.groupSummaries.length > 0 ? (
                <div className="dashboard-inventory__group-list">
                  {bloodInventory.groupSummaries.map(
                    (group) => {
                      const width =
                        group.availableUnits === 0
                          ? 0
                          : Math.max(
                              (group.availableUnits /
                                maxAvailableUnits) *
                                100,
                              5,
                            );

                      return (
                        <div
                          className="dashboard-inventory__group"
                          key={group.code}
                        >
                          <div className="dashboard-inventory__group-top">
                            <div>
                              <strong>
                                {group.code}
                              </strong>

                              <span>
                                {group.name}
                              </span>
                            </div>

                            <b>
                              {group.availableUnits}
                            </b>
                          </div>

                          <div className="dashboard-inventory__bar">
                            <span
                              style={{
                                width: `${width}%`,
                              }}
                            />
                          </div>
                        </div>
                      );
                    },
                  )}
                </div>
              ) : (
                <div className="dashboard-inventory__empty">
                  <div>
                    🩸
                  </div>

                  <strong>
                    No blood inventory yet
                  </strong>

                  <p>
                    Inventory records will appear
                    here when blood stock is added
                    to the network.
                  </p>
                </div>
              )}
            </div>
          </article>
        )}
      </section>
    </div>
  );
}