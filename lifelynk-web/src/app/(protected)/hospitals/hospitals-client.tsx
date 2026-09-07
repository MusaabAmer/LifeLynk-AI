"use client";

import { useMemo, useState } from "react";
import {
  AlertTriangle,
  Building2,
  Droplets,
  HeartPulse,
  Landmark,
  MapPin,
  Search,
  Siren,
  X,
} from "lucide-react";

import type {
  HealthcareFacility,
  HospitalStats,
} from "@/lib/dashboard/get-hospitals-data";

/* =========================================================
   TYPES
   ========================================================= */

type FacilityFilter =
  | "ALL"
  | "HOSPITAL"
  | "BLOOD_BANK";

type VerificationFilter =
  | "ALL"
  | "VERIFIED"
  | "PENDING"
  | "REJECTED";

/* =========================================================
   HELPERS
   ========================================================= */

function BooleanBadge({
  value,
}: {
  value: boolean | null;
}) {
  if (value === null) {
    return (
      <span className="hospitals-badge hospitals-badge--na">
        —
      </span>
    );
  }

  return (
    <span
      className={`hospitals-badge ${
        value
          ? "hospitals-badge--yes"
          : "hospitals-badge--no"
      }`}
    >
      <span className="hospitals-badge__dot" />
      {value ? "Yes" : "No"}
    </span>
  );
}

function formatType(raw: string): string {
  if (!raw) {
    return "Hospital";
  }

  return raw
    .split("_")
    .map(
      (word) =>
        word.charAt(0).toUpperCase() +
        word.slice(1).toLowerCase(),
    )
    .join(" ");
}

function facilityTypeLabel(
  facility: HealthcareFacility,
): string {
  return facility.facility_type === "BLOOD_BANK"
    ? "Blood Bank"
    : "Hospital";
}

function verificationLabel(
  status: string | null | undefined,
): string {
  switch (status) {
    case "VERIFIED":
      return "Verified";
    case "PENDING":
      return "Pending";
    case "REJECTED":
      return "Rejected";
    default:
      return "Unknown";
  }
}

function verificationClass(
  status: string | null | undefined,
): string {
  switch (status) {
    case "VERIFIED":
      return "hospitals-status--verified";
    case "REJECTED":
      return "hospitals-status--rejected";
    case "PENDING":
    default:
      return "hospitals-status--pending";
  }
}

/* =========================================================
   VERIFICATION BADGE
   ========================================================= */

function VerificationBadge({
  status,
}: {
  status: string | null | undefined;
}) {
  return (
    <span
      className={`hospitals-status ${verificationClass(
        status,
      )}`}
    >
      <span className="hospitals-status__dot" />
      {verificationLabel(status)}
    </span>
  );
}

/* =========================================================
   FACILITY ROW — DESKTOP
   ========================================================= */

function HospitalRow({
  facility,
}: {
  facility: HealthcareFacility;
}) {
  const org = facility.organizations;
  const city = org?.cities;
  const province = city?.provinces;

  const isHospital =
    facility.facility_type === "HOSPITAL";

  return (
    <tr>
      {/* Facility */}
      <td>
        <div className="hospitals-table__name">
          <strong>
            {org?.name ?? "Unknown"}
          </strong>

          <span>
            License:{" "}
            {facility.license_number || "N/A"}
          </span>
        </div>
      </td>

      {/* Type */}
      <td>
        <span
          className={`hospitals-table__type ${
            isHospital
              ? "hospitals-table__type--hospital"
              : "hospitals-table__type--blood-bank"
          }`}
        >
          {isHospital
            ? formatType(facility.hospital_type)
            : "Blood Bank"}
        </span>
      </td>

      {/* Location */}
      <td>
        <div className="hospitals-table__location">
          <span>
            {city?.name ?? "—"}
          </span>

          <span>
            {province?.name ?? "—"}
          </span>
        </div>
      </td>

      {/* Verification */}
      <td>
        <VerificationBadge
          status={org?.verification_status}
        />
      </td>

      {/* Emergency */}
      <td>
        <BooleanBadge
          value={facility.emergency_service}
        />
      </td>

      {/* ICU */}
      <td>
        <BooleanBadge
          value={facility.icu_available}
        />
      </td>

      {/* Blood Storage */}
      <td>
        <BooleanBadge
          value={
            facility.blood_storage_available
          }
        />
      </td>

      {/* Beds */}
      <td>
        {facility.total_beds ?? "N/A"}
      </td>

      {/* Contact */}
      <td>
        {org?.phone ?? "—"}
      </td>
    </tr>
  );
}

/* =========================================================
   FACILITY CARD — MOBILE
   ========================================================= */

function HospitalCard({
  facility,
}: {
  facility: HealthcareFacility;
}) {
  const org = facility.organizations;
  const city = org?.cities;
  const province = city?.provinces;

  const isHospital =
    facility.facility_type === "HOSPITAL";

  return (
    <div className="hospitals-card">
      <div className="hospitals-card__top">
        <div>
          <div className="hospitals-card__name">
            {org?.name ?? "Unknown"}
          </div>

          <div className="hospitals-card__license">
            License:{" "}
            {facility.license_number || "N/A"}
          </div>
        </div>

        <span
          className={`hospitals-card__type ${
            isHospital
              ? "hospitals-card__type--hospital"
              : "hospitals-card__type--blood-bank"
          }`}
        >
          {facilityTypeLabel(facility)}
        </span>
      </div>

      <div className="hospitals-card__location">
        <MapPin />

        {city?.name ?? "—"},{" "}
        {province?.name ?? "—"}
      </div>

      <div className="hospitals-card__verification">
        <VerificationBadge
          status={org?.verification_status}
        />
      </div>

      <div className="hospitals-card__grid">
        {/* Facility Type */}
        <div className="hospitals-card__field">
          <span className="hospitals-card__field-label">
            Facility Type
          </span>

          <span className="hospitals-card__field-value">
            {isHospital
              ? formatType(
                  facility.hospital_type,
                )
              : "Blood Bank"}
          </span>
        </div>

        {/* Emergency */}
        <div className="hospitals-card__field">
          <span className="hospitals-card__field-label">
            Emergency
          </span>

          <span className="hospitals-card__field-value">
            <BooleanBadge
              value={
                facility.emergency_service
              }
            />
          </span>
        </div>

        {/* ICU */}
        <div className="hospitals-card__field">
          <span className="hospitals-card__field-label">
            ICU
          </span>

          <span className="hospitals-card__field-value">
            <BooleanBadge
              value={facility.icu_available}
            />
          </span>
        </div>

        {/* Blood Storage */}
        <div className="hospitals-card__field">
          <span className="hospitals-card__field-label">
            Blood Storage
          </span>

          <span className="hospitals-card__field-value">
            <BooleanBadge
              value={
                facility.blood_storage_available
              }
            />
          </span>
        </div>

        {/* Beds */}
        <div className="hospitals-card__field">
          <span className="hospitals-card__field-label">
            Beds
          </span>

          <span className="hospitals-card__field-value">
            {facility.total_beds ?? "N/A"}
          </span>
        </div>

        {/* Contact */}
        <div className="hospitals-card__field">
          <span className="hospitals-card__field-label">
            Contact
          </span>

          <span className="hospitals-card__field-value">
            {org?.phone ?? "—"}
          </span>
        </div>

        {/* Email */}
        <div className="hospitals-card__field">
          <span className="hospitals-card__field-label">
            Email
          </span>

          <span className="hospitals-card__field-value">
            {org?.email ?? "—"}
          </span>
        </div>

        {/* License */}
        <div className="hospitals-card__field">
          <span className="hospitals-card__field-label">
            License
          </span>

          <span className="hospitals-card__field-value">
            {facility.license_number ||
              "N/A"}
          </span>
        </div>

        {/* Blood-bank specific information */}
        {!isHospital && (
          <>
            <div className="hospitals-card__field">
              <span className="hospitals-card__field-label">
                Cold Storage
              </span>

              <span className="hospitals-card__field-value">
                <BooleanBadge
                  value={
                    facility.cold_storage_available
                  }
                />
              </span>
            </div>

            <div className="hospitals-card__field">
              <span className="hospitals-card__field-label">
                Processing
              </span>

              <span className="hospitals-card__field-value">
                <BooleanBadge
                  value={
                    facility.blood_processing_available
                  }
                />
              </span>
            </div>

            <div className="hospitals-card__field">
              <span className="hospitals-card__field-label">
                Capacity
              </span>

              <span className="hospitals-card__field-value">
                {facility.storage_capacity ??
                  "N/A"}
              </span>
            </div>

            <div className="hospitals-card__field">
              <span className="hospitals-card__field-label">
                Operating Hours
              </span>

              <span className="hospitals-card__field-value">
                {facility.operating_hours ??
                  "N/A"}
              </span>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

/* =========================================================
   FILTERS
   ========================================================= */

function FilterBar({
  search,
  setSearch,
  facilityType,
  setFacilityType,
  verification,
  setVerification,
  province,
  setProvince,
  city,
  setCity,
  provinces,
  cities,
  resultCount,
  totalCount,
  onClear,
}: {
  search: string;
  setSearch: (value: string) => void;
  facilityType: FacilityFilter;
  setFacilityType: (
    value: FacilityFilter,
  ) => void;
  verification: VerificationFilter;
  setVerification: (
    value: VerificationFilter,
  ) => void;
  province: string;
  setProvince: (value: string) => void;
  city: string;
  setCity: (value: string) => void;
  provinces: string[];
  cities: string[];
  resultCount: number;
  totalCount: number;
  onClear: () => void;
}) {
  const hasFilters =
    search.trim() !== "" ||
    facilityType !== "ALL" ||
    verification !== "ALL" ||
    province !== "ALL" ||
    city !== "ALL";

  return (
    <div className="hospitals-filters">
      <div className="hospitals-filters__top">
        <div className="hospitals-filters__title">
          <span className="hospitals-filters__title-icon">
            <Search />
          </span>

          <div>
            <strong>Filter Directory</strong>

            <span>
              Showing {resultCount} of{" "}
              {totalCount} facilities
            </span>
          </div>
        </div>

        {hasFilters && (
          <button
            type="button"
            className="hospitals-filters__clear"
            onClick={onClear}
          >
            <X />
            Clear Filters
          </button>
        )}
      </div>

      <div className="hospitals-filters__grid">
        {/* Search */}
        <label className="hospitals-filter">
          <span>Search</span>

          <div className="hospitals-filter__input">
            <Search />

            <input
              type="search"
              value={search}
              onChange={(event) =>
                setSearch(event.target.value)
              }
              placeholder="Name, phone, email, license..."
              aria-label="Search healthcare facilities"
            />

            {search && (
              <button
                type="button"
                onClick={() => setSearch("")}
                aria-label="Clear search"
              >
                <X />
              </button>
            )}
          </div>
        </label>

        {/* Facility Type */}
        <label className="hospitals-filter">
          <span>Facility Type</span>

          <select
            value={facilityType}
            onChange={(event) =>
              setFacilityType(
                event.target
                  .value as FacilityFilter,
              )
            }
          >
            <option value="ALL">
              All Facilities
            </option>

            <option value="HOSPITAL">
              Hospitals
            </option>

            <option value="BLOOD_BANK">
              Blood Banks
            </option>
          </select>
        </label>

        {/* Verification */}
        <label className="hospitals-filter">
          <span>Verification</span>

          <select
            value={verification}
            onChange={(event) =>
              setVerification(
                event.target
                  .value as VerificationFilter,
              )
            }
          >
            <option value="ALL">
              All Statuses
            </option>

            <option value="VERIFIED">
              Verified
            </option>

            <option value="PENDING">
              Pending
            </option>

            <option value="REJECTED">
              Rejected
            </option>
          </select>
        </label>

        {/* Province */}
        <label className="hospitals-filter">
          <span>Province</span>

          <select
            value={province}
            onChange={(event) => {
              setProvince(event.target.value);
              setCity("ALL");
            }}
          >
            <option value="ALL">
              All Provinces
            </option>

            {provinces.map(
              (provinceName) => (
                <option
                  key={provinceName}
                  value={provinceName}
                >
                  {provinceName}
                </option>
              ),
            )}
          </select>
        </label>

        {/* City */}
        <label className="hospitals-filter">
          <span>City</span>

          <select
            value={city}
            onChange={(event) =>
              setCity(event.target.value)
            }
            disabled={cities.length === 0}
          >
            <option value="ALL">
              All Cities
            </option>

            {cities.map((cityName) => (
              <option
                key={cityName}
                value={cityName}
              >
                {cityName}
              </option>
            ))}
          </select>
        </label>
      </div>
    </div>
  );
}

/* =========================================================
   CLIENT PAGE
   ========================================================= */

export default function HospitalsClient({
  facilities,
  stats,
  error,
  role,
}: {
  facilities: HealthcareFacility[];
  stats: HospitalStats;
  error: boolean;
  role: string;
}) {
  const [search, setSearch] =
    useState("");

  const [facilityType, setFacilityType] =
    useState<FacilityFilter>("ALL");

  const [verification, setVerification] =
    useState<VerificationFilter>("ALL");

  const [province, setProvince] =
    useState("ALL");

  const [city, setCity] =
    useState("ALL");

  /* =======================================================
     PROVINCES
     ======================================================= */

  const provinces = useMemo(() => {
    const values = facilities
      .map(
        (facility) =>
          facility.organizations?.cities
            ?.provinces?.name,
      )
      .filter(
        (value): value is string =>
          Boolean(value),
      );

    return Array.from(new Set(values)).sort(
      (a, b) => a.localeCompare(b),
    );
  }, [facilities]);

  /* =======================================================
     CITIES
     ======================================================= */

  const cities = useMemo(() => {
    const values = facilities
      .filter((facility) => {
        if (province === "ALL") {
          return true;
        }

        return (
          facility.organizations?.cities
            ?.provinces?.name === province
        );
      })
      .map(
        (facility) =>
          facility.organizations?.cities
            ?.name,
      )
      .filter(
        (value): value is string =>
          Boolean(value),
      );

    return Array.from(new Set(values)).sort(
      (a, b) => a.localeCompare(b),
    );
  }, [facilities, province]);

  /* =======================================================
     FILTERED FACILITIES
     ======================================================= */

  const filteredFacilities = useMemo(() => {
    const normalizedSearch =
      search.trim().toLowerCase();

    return facilities.filter((facility) => {
      const org = facility.organizations;
      const facilityCity =
        org?.cities?.name ?? "";
      const facilityProvince =
        org?.cities?.provinces?.name ?? "";

      /* -----------------------------------------------
         Search
         ----------------------------------------------- */

      if (normalizedSearch) {
        const searchableText = [
          org?.name,
          org?.phone,
          org?.email,
          org?.address,
          facility.license_number,
          facility.hospital_type,
          facilityTypeLabel(facility),
          facilityCity,
          facilityProvince,
          org?.verification_status,
        ]
          .filter(Boolean)
          .join(" ")
          .toLowerCase();

        if (
          !searchableText.includes(
            normalizedSearch,
          )
        ) {
          return false;
        }
      }

      /* -----------------------------------------------
         Facility Type
         ----------------------------------------------- */

      if (
        facilityType !== "ALL" &&
        facility.facility_type !==
          facilityType
      ) {
        return false;
      }

      /* -----------------------------------------------
         Verification
         ----------------------------------------------- */

      if (
        verification !== "ALL" &&
        org?.verification_status !==
          verification
      ) {
        return false;
      }

      /* -----------------------------------------------
         Province
         ----------------------------------------------- */

      if (
        province !== "ALL" &&
        facilityProvince !== province
      ) {
        return false;
      }

      /* -----------------------------------------------
         City
         ----------------------------------------------- */

      if (
        city !== "ALL" &&
        facilityCity !== city
      ) {
        return false;
      }

      return true;
    });
  }, [
    facilities,
    search,
    facilityType,
    verification,
    province,
    city,
  ]);

  /* =======================================================
     CLEAR FILTERS
     ======================================================= */

  function clearFilters() {
    setSearch("");
    setFacilityType("ALL");
    setVerification("ALL");
    setProvince("ALL");
    setCity("ALL");
  }

  const roleLabel = role.replaceAll(
    "_",
    " ",
  );

  return (
    <div className="hospitals-page">
      {/* ------------------------------------------ */}
      {/* Header                                     */}
      {/* ------------------------------------------ */}

      <header className="hospitals-page__header">
        <div className="hospitals-page__header-content">
          <div className="hospitals-page__icon">
            <Building2 />
          </div>

          <div className="hospitals-page__title-group">
            <p className="hospitals-page__eyebrow">
              HEALTHCARE DIRECTORY
            </p>

            <h1 className="hospitals-page__title">
              Healthcare Facilities
            </h1>

            <p className="hospitals-page__description">
              Manage and monitor hospitals
              and blood banks connected to
              the LifeLynk healthcare network.
            </p>
          </div>
        </div>
      </header>

      {/* ------------------------------------------ */}
      {/* Summary stats                              */}
      {/* ------------------------------------------ */}

      <section className="hospitals-stats">
        <article className="hospitals-stat">
          <span className="hospitals-stat__icon">
            <Building2 />
          </span>

          <div>
            <p>Total Facilities</p>

            <strong>
              {stats.totalFacilities}
            </strong>
          </div>

          <span className="hospitals-stat__label">
            Network
          </span>
        </article>

        <article className="hospitals-stat">
          <span className="hospitals-stat__icon">
            <Landmark />
          </span>

          <div>
            <p>Hospitals</p>

            <strong>
              {stats.totalHospitals}
            </strong>
          </div>

          <span className="hospitals-stat__label">
            Registered
          </span>
        </article>

        <article className="hospitals-stat">
          <span className="hospitals-stat__icon">
            <Droplets />
          </span>

          <div>
            <p>Blood Banks</p>

            <strong>
              {stats.totalBloodBanks}
            </strong>
          </div>

          <span className="hospitals-stat__label">
            Connected
          </span>
        </article>

        <article className="hospitals-stat">
          <span className="hospitals-stat__icon">
            <Siren />
          </span>

          <div>
            <p>Emergency Services</p>

            <strong>
              {stats.emergencyService}
            </strong>
          </div>

          <span className="hospitals-stat__label">
            Active
          </span>
        </article>

        <article className="hospitals-stat">
          <span className="hospitals-stat__icon">
            <HeartPulse />
          </span>

          <div>
            <p>ICU Available</p>

            <strong>
              {stats.icuAvailable}
            </strong>
          </div>

          <span className="hospitals-stat__label">
            Equipped
          </span>
        </article>

        <article className="hospitals-stat">
          <span className="hospitals-stat__icon">
            <Droplets />
          </span>

          <div>
            <p>Blood Storage</p>

            <strong>
              {stats.bloodStorageAvailable}
            </strong>
          </div>

          <span className="hospitals-stat__label">
            Available
          </span>
        </article>
      </section>

      {/* ------------------------------------------ */}
      {/* Error state                                */}
      {/* ------------------------------------------ */}

      {error && (
        <div className="hospitals-error">
          <div className="hospitals-error__icon">
            <AlertTriangle />
          </div>

          <strong>
            Unable to load healthcare facilities
          </strong>

          <p>
            Something went wrong while
            fetching hospital and blood-bank
            data. Please try refreshing the
            page.
          </p>
        </div>
      )}

      {/* ------------------------------------------ */}
      {/* Directory                                  */}
      {/* ------------------------------------------ */}

      {!error && (
        <section className="hospitals-table-section">
          <div className="hospitals-table-section__header">
            <div>
              <p>
                HEALTHCARE DIRECTORY
              </p>

              <h3>
                All healthcare facilities
              </h3>
            </div>

            <span className="hospitals-table-section__count">
              {filteredFacilities.length}{" "}
              {filteredFacilities.length === 1
                ? "facility"
                : "facilities"}
            </span>
          </div>

          {/* -------------------------------------- */}
          {/* Filters                                */}
          {/* -------------------------------------- */}

          <FilterBar
            search={search}
            setSearch={setSearch}
            facilityType={facilityType}
            setFacilityType={setFacilityType}
            verification={verification}
            setVerification={
              setVerification
            }
            province={province}
            setProvince={setProvince}
            city={city}
            setCity={setCity}
            provinces={provinces}
            cities={cities}
            resultCount={
              filteredFacilities.length
            }
            totalCount={facilities.length}
            onClear={clearFilters}
          />

          {/* -------------------------------------- */}
          {/* Filtered desktop table                */}
          {/* -------------------------------------- */}

          {filteredFacilities.length > 0 && (
            <>
              <div className="hospitals-table-wrap">
                <table className="hospitals-table">
                  <thead>
                    <tr>
                      <th>Facility</th>
                      <th>Type</th>
                      <th>
                        City / Province
                      </th>
                      <th>
                        Verification
                      </th>
                      <th>Emergency</th>
                      <th>ICU</th>
                      <th>
                        Blood Storage
                      </th>
                      <th>Beds</th>
                      <th>Contact</th>
                    </tr>
                  </thead>

                  <tbody>
                    {filteredFacilities.map(
                      (facility) => (
                        <HospitalRow
                          key={`${facility.facility_type}-${facility.id}`}
                          facility={facility}
                        />
                      ),
                    )}
                  </tbody>
                </table>
              </div>

              {/* ---------------------------------- */}
              {/* Mobile cards                       */}
              {/* ---------------------------------- */}

              <div className="hospitals-cards">
                {filteredFacilities.map(
                  (facility) => (
                    <HospitalCard
                      key={`${facility.facility_type}-${facility.id}`}
                      facility={facility}
                    />
                  ),
                )}
              </div>
            </>
          )}

          {/* -------------------------------------- */}
          {/* Filter empty state                    */}
          {/* -------------------------------------- */}

          {filteredFacilities.length === 0 && (
            <div className="hospitals-empty">
              <div className="hospitals-empty__icon">
                <Search />
              </div>

              <strong>
                No matching facilities
              </strong>

              <p>
                No healthcare facilities match
                the current search and filter
                criteria.
              </p>

              <button
                type="button"
                className="hospitals-empty__button"
                onClick={clearFilters}
              >
                Clear Filters
              </button>
            </div>
          )}
        </section>
      )}

      {/* ------------------------------------------ */}
      {/* Original empty state                       */}
      {/* ------------------------------------------ */}

      {!error &&
        facilities.length === 0 && (
          <section className="hospitals-table-section">
            <div className="hospitals-empty">
              <div className="hospitals-empty__icon">
                <Building2 />
              </div>

              <strong>
                No healthcare facilities found
              </strong>

              <p>
                {role ===
                  "GOVERNMENT_ADMIN" ||
                role === "SUPER_ADMIN"
                  ? "No hospitals or blood banks have been registered in the network yet."
                  : `No healthcare facilities are currently visible for your ${roleLabel.toLowerCase()} role.`}
              </p>
            </div>
          </section>
        )}
    </div>
  );
}