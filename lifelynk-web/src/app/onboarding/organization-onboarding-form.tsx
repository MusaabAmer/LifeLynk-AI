"use client";

import "./onboarding.css";

import {
  FormEvent,
  useMemo,
  useState,
} from "react";
import { useRouter } from "next/navigation";

interface OrganizationCity {
  id: string;
  name: string;
}

interface Organization {
  id: string;
  name: string;
  organization_type:
    | "HOSPITAL"
    | "BLOOD_BANK";
  registration_number: string | null;
  phone: string;
  email: string | null;
  address: string;
  city_id: string;
  verification_status: string;
  cities:
    | OrganizationCity
    | OrganizationCity[]
    | null;
}

interface OrganizationOnboardingFormProps {
  organizations: Organization[];
  organizationType:
    | "HOSPITAL"
    | "BLOOD_BANK";
}

export default function OrganizationOnboardingForm({
  organizations,
  organizationType,
}: OrganizationOnboardingFormProps) {
  const router = useRouter();

  const [
    organizationId,
    setOrganizationId,
  ] = useState("");

  const [loading, setLoading] =
    useState(false);

  const [error, setError] =
    useState("");

  const [
    successMessage,
    setSuccessMessage,
  ] = useState("");

  const [searchQuery, setSearchQuery] =
    useState("");

  const [cityFilter, setCityFilter] =
    useState("ALL");

  const isHospital =
    organizationType === "HOSPITAL";

  const organizationLabel = isHospital
    ? "hospital"
    : "blood bank";

  const title = isHospital
    ? "Select your hospital"
    : "Select your blood bank";

  const description = isHospital
    ? "Request access to a verified hospital. Access will be granted only after the organization's administrator approves your request."
    : "Request access to a verified blood bank. Access will be granted only after the organization's administrator approves your request.";

  /*
   * ------------------------------------------------
   * CITY OPTIONS
   * ------------------------------------------------
   *
   * Build a unique city list from the organizations
   * already loaded by the onboarding page.
   */
  const cities = useMemo(() => {
    const cityMap = new Map<
      string,
      string
    >();

    organizations.forEach(
      (organization) => {
        const city = Array.isArray(
          organization.cities,
        )
          ? organization.cities[0]
          : organization.cities;

        if (city?.id && city.name) {
          cityMap.set(
            city.id,
            city.name,
          );
        }
      },
    );

    return Array.from(
      cityMap.entries(),
    )
      .map(([id, name]) => ({
        id,
        name,
      }))
      .sort((a, b) =>
        a.name.localeCompare(b.name),
      );
  }, [organizations]);

  /*
   * ------------------------------------------------
   * FILTERED ORGANIZATIONS
   * ------------------------------------------------
   */
  const filteredOrganizations =
    useMemo(() => {
      const normalizedSearch =
        searchQuery
          .trim()
          .toLowerCase();

      return organizations.filter(
        (organization) => {
          const city = Array.isArray(
            organization.cities,
          )
            ? organization.cities[0]
            : organization.cities;

          /*
           * Search across the useful organization
           * information.
           */
          const searchableText = [
            organization.name,
            organization.address,
            organization.registration_number ||
              "",
            organization.phone,
            city?.name || "",
          ]
            .join(" ")
            .toLowerCase();

          const matchesSearch =
            !normalizedSearch ||
            searchableText.includes(
              normalizedSearch,
            );

          const matchesCity =
            cityFilter === "ALL" ||
            organization.city_id ===
              cityFilter ||
            city?.id === cityFilter;

          return (
            matchesSearch &&
            matchesCity
          );
        },
      );
    }, [
      organizations,
      searchQuery,
      cityFilter,
    ]);

  const hasActiveFilters =
    searchQuery.trim() !== "" ||
    cityFilter !== "ALL";

  function clearFilters() {
    setSearchQuery("");
    setCityFilter("ALL");
  }

  async function handleSubmit(
    event: FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault();

    setError("");
    setSuccessMessage("");

    if (!organizationId) {
      setError(
        "Please select your organization.",
      );
      return;
    }

    setLoading(true);

    try {
      const response = await fetch(
        "/api/onboarding/organization",
        {
          method: "POST",
          headers: {
            "Content-Type":
              "application/json",
          },
          body: JSON.stringify({
            organizationId,
          }),
        },
      );

      const result =
        await response.json();

      if (!response.ok) {
        setError(
          result.error ||
            "Unable to submit your organization access request.",
        );
        return;
      }

      /*
       * The request has now been created as
       * PENDING.
       *
       * Member 2 does NOT have organization_staff
       * membership yet, so do not send them to
       * the dashboard.
       *
       * The waiting page listens for the request
       * changing to APPROVED through Supabase
       * Realtime.
       */
      const selectedOrganizationName =
        result.organization?.name ||
        organizations.find(
          (organization) =>
            organization.id ===
            organizationId,
        )?.name ||
        "your organization";

      router.replace(
        `/onboarding/join-request-pending?organization=${encodeURIComponent(
          selectedOrganizationName,
        )}`,
      );
    } catch {
      setError(
        "Something went wrong. Please try again.",
      );
    } finally {
      setLoading(false);
    }
  }

  function handleRegisterNewOrganization() {
    router.push(
      `/organization-register?type=${organizationType}`,
    );
  }

  return (
    <section className="onboarding-selection">
      <div className="onboarding-selection__header">
        <div>
          <p className="onboarding-selection__eyebrow">
            {isHospital
              ? "HOSPITALS"
              : "BLOOD BANKS"}
          </p>

          <h3>{title}</h3>

          <p>{description}</p>
        </div>

        <div className="onboarding-selection__count">
          <strong>
            {organizations.length}
          </strong>

          <span>
            {organizations.length === 1
              ? "organization"
              : "organizations"}
          </span>
        </div>
      </div>

      {successMessage && (
        <div
          className="onboarding-form__success"
          role="status"
        >
          <span>✓</span>
          <p>{successMessage}</p>
        </div>
      )}

      {organizations.length > 0 ? (
        <form
          onSubmit={handleSubmit}
          className="onboarding-form"
        >
          {/* -----------------------------------------
              ORGANIZATION FILTERS
              ----------------------------------------- */}
          <div className="organization-filters">
            <div className="organization-filter__search">
              <span
                className="organization-filter__search-icon"
                aria-hidden="true"
              >
                🔍
              </span>

              <input
                type="search"
                value={searchQuery}
                onChange={(event) => {
                  setSearchQuery(
                    event.target.value,
                  );
                }}
                placeholder={`Search ${organizationLabel}s...`}
                aria-label={`Search ${organizationLabel}s`}
                disabled={loading}
              />

              {searchQuery && (
                <button
                  type="button"
                  className="organization-filter__clear-search"
                  onClick={() =>
                    setSearchQuery("")
                  }
                  aria-label="Clear search"
                  disabled={loading}
                >
                  ×
                </button>
              )}
            </div>

            <div className="organization-filter__city">
              <label htmlFor="organization-city-filter">
                City
              </label>

              <select
                id="organization-city-filter"
                value={cityFilter}
                onChange={(event) =>
                  setCityFilter(
                    event.target.value,
                  )
                }
                disabled={loading}
              >
                <option value="ALL">
                  All cities
                </option>

                {cities.map((city) => (
                  <option
                    key={city.id}
                    value={city.id}
                  >
                    {city.name}
                  </option>
                ))}
              </select>
            </div>

            {hasActiveFilters && (
              <button
                type="button"
                className="organization-filter__clear"
                onClick={clearFilters}
                disabled={loading}
              >
                Clear filters
              </button>
            )}
          </div>

          {/* -----------------------------------------
              FILTER RESULT SUMMARY
              ----------------------------------------- */}
          <div className="organization-list__toolbar">
            <div>
              <strong>
                {filteredOrganizations.length}
              </strong>

              <span>
                {" "}
                of{" "}
                {organizations.length}{" "}
                verified{" "}
                {organizationLabel}
                {organizations.length === 1
                  ? ""
                  : "s"}
              </span>
            </div>

            {hasActiveFilters && (
              <span className="organization-list__filtered">
                Filters applied
              </span>
            )}
          </div>

          {/* -----------------------------------------
              ORGANIZATION LIST
              ----------------------------------------- */}
          {filteredOrganizations.length >
          0 ? (
            <div className="organization-list">
              {filteredOrganizations.map(
                (organization) => {
                  const city =
                    Array.isArray(
                      organization.cities,
                    )
                      ? organization
                          .cities[0]
                      : organization.cities;

                  const selected =
                    organizationId ===
                    organization.id;

                  return (
                    <button
                      key={
                        organization.id
                      }
                      type="button"
                      className={`organization-card ${
                        selected
                          ? "organization-card--selected"
                          : ""
                      }`}
                      onClick={() => {
                        setOrganizationId(
                          organization.id,
                        );
                        setError("");
                        setSuccessMessage(
                          "",
                        );
                      }}
                      disabled={loading}
                      aria-pressed={
                        selected
                      }
                    >
                      <div
                        className={`organization-card__icon ${
                          isHospital
                            ? "organization-card__icon--hospital"
                            : "organization-card__icon--blood-bank"
                        }`}
                      >
                        {isHospital
                          ? "H"
                          : "B"}
                      </div>

                      <div className="organization-card__content">
                        <div className="organization-card__heading">
                          <h4>
                            {
                              organization.name
                            }
                          </h4>

                          <span className="organization-card__verified">
                            <span />
                            Verified
                          </span>
                        </div>

                        <div className="organization-card__location">
                          <span>
                            {city?.name ??
                              "Unknown city"}
                          </span>

                          <span>
                            •
                          </span>

                          <span>
                            {
                              organization.address
                            }
                          </span>
                        </div>

                        <div className="organization-card__details">
                          {organization.registration_number && (
                            <span>
                              <strong>
                                Registration:
                              </strong>{" "}
                              {
                                organization.registration_number
                              }
                            </span>
                          )}

                          <span>
                            <strong>
                              Phone:
                            </strong>{" "}
                            {
                              organization.phone
                            }
                          </span>
                        </div>
                      </div>

                      <div
                        className={`organization-card__radio ${
                          selected
                            ? "organization-card__radio--selected"
                            : ""
                        }`}
                        aria-hidden="true"
                      >
                        {selected &&
                          "✓"}
                      </div>
                    </button>
                  );
                },
              )}
            </div>
          ) : (
            <div className="organization-list__no-results">
              <div className="organization-list__no-results-icon">
                🔍
              </div>

              <h4>
                No organizations found
              </h4>

              <p>
                No verified{" "}
                {organizationLabel}s
                match your current
                search or city filter.
              </p>

              <button
                type="button"
                className="organization-filter__clear"
                onClick={clearFilters}
                disabled={loading}
              >
                Clear filters
              </button>
            </div>
          )}

          {error && (
            <div
              className="onboarding-form__error"
              role="alert"
            >
              <span>!</span>
              <p>{error}</p>
            </div>
          )}

          <div className="onboarding-form__footer">
            <div>
              <strong>
                {organizationId
                  ? "Organization selected"
                  : "Select an organization"}
              </strong>

              <span>
                {organizationId
                  ? "A join request will be sent to this organization's administrator for approval."
                  : `Choose one of the verified ${organizationLabel}s above.`}
              </span>
            </div>

            <button
              type="submit"
              className="onboarding-submit"
              disabled={
                loading ||
                !organizationId
              }
            >
              {loading ? (
                <>
                  <span className="onboarding-submit__spinner" />
                  Sending request...
                </>
              ) : (
                <>
                  Request to join
                  <span>→</span>
                </>
              )}
            </button>
          </div>
        </form>
      ) : (
        <div className="onboarding-empty">
          <div className="onboarding-empty__icon">
            !
          </div>

          <h4>
            No verified{" "}
            {organizationLabel}s available
          </h4>

          <p>
            There are currently no verified{" "}
            {organizationLabel}s available for
            your account type.
          </p>

          <button
            type="button"
            className="onboarding-register__button"
            onClick={
              handleRegisterNewOrganization
            }
            disabled={loading}
          >
            Register new{" "}
            {organizationLabel}
            <span>→</span>
          </button>
        </div>
      )}

      {organizations.length > 0 && (
        <div className="onboarding-register">
          <div className="onboarding-register__content">
            <strong>
              Don&apos;t see your{" "}
              {organizationLabel}?
            </strong>

            <span>
              Register a new{" "}
              {organizationLabel}. Your
              organization will be reviewed by a
              LifeLynk administrator before being
              verified.
            </span>
          </div>

          <button
            type="button"
            className="onboarding-register__button"
            onClick={
              handleRegisterNewOrganization
            }
            disabled={loading}
          >
            Register new{" "}
            {organizationLabel}
            <span>→</span>
          </button>
        </div>
      )}
    </section>
  );
}

