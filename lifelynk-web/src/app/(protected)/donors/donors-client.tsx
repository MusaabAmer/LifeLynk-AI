"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Users,
  UserCheck,
  UserX,
  Droplets,
  MapPin,
  EyeOff,
  Search,
  X,
  Pencil,
  AlertTriangle,
  AlertCircle,
  LoaderCircle,
} from "lucide-react";

import { createClient } from "@/lib/supabase/client";
import type {
  DonorRecord,
  DonorsData,
} from "@/lib/dashboard/get-donors-data";
import type {
  CurrentUser,
  WebRole,
} from "@/lib/auth/get-current-user";

/* =========================================================
   DESIGN NOTES
   =========================================================
 * 1. The DONOR role cannot access the web dashboard — the
 *    (protected) layout blocks non-web roles. This page
 *    serves healthcare staff viewing donor records.
 * 2. The page is READ-ONLY for every role except SUPER_ADMIN,
 *    who may perform a limited edit (is_available,
 *    total_donations, last_donation_date).
 * 3. Phone numbers are masked in the list view (last 4
 *    digits only) to limit PII exposure.
 * 4. Age is computed from date_of_birth; the raw DOB is
 *    never rendered.
 * 5. donor_profiles is NOT queried — its RLS policies block
 *    dashboard access entirely.
 * 6. donation_history is NOT queried — the table has no RLS,
 *    so querying it would be a security concern.
 * 7. No CREATE action — the donors INSERT policy requires
 *    user_id = auth.uid(), so only the donor themselves can
 *    register (through the mobile app).
 * 8. No DELETE action — no DELETE policy exists on the
 *    donors table, so all deletes are blocked by RLS.
 * ========================================================= */

/* =========================================================
   TYPES
   ========================================================= */

interface DonorsClientProps {
  data: DonorsData;
  currentUser: CurrentUser;
}

type ModalState =
  | { type: "closed" }
  | { type: "edit"; record: DonorRecord };

interface DonorEditFormState {
  isAvailable: boolean;
  totalDonations: string;
  lastDonationDate: string;
}

/* =========================================================
   PERMISSIONS (mirror of the RLS policies)
   ========================================================= */

function canUpdateDonor(role: WebRole): boolean {
  /*
   * donors UPDATE policy: (user_id = auth.uid()) OR
   * is_super_admin(). Dashboard users are healthcare staff —
   * never the donor owner — so only SUPER_ADMIN sees edit
   * controls.
   */
  return role === "SUPER_ADMIN";
}

/* =========================================================
   FORMAT HELPERS
   ========================================================= */

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

/*
 * Age is derived from date_of_birth and rendered instead of
 * the raw DOB (privacy). The donors.date_of_birth column is
 * NOT NULL, but a defensive fallback keeps the table
 * rendering if the value is ever malformed.
 */
function computeAge(dateOfBirth: string): number | null {
  const dob = new Date(dateOfBirth);

  if (Number.isNaN(dob.getTime())) {
    return null;
  }

  const now = new Date();

  let age = now.getFullYear() - dob.getFullYear();

  const monthDiff = now.getMonth() - dob.getMonth();

  if (
    monthDiff < 0 ||
    (monthDiff === 0 && now.getDate() < dob.getDate())
  ) {
    age -= 1;
  }

  return age >= 0 ? age : null;
}

function formatGender(raw: string): string {
  return (
    raw.charAt(0).toUpperCase() + raw.slice(1).toLowerCase()
  );
}

/*
 * PII minimization: only the last 4 digits of the phone
 * number are ever displayed in the list view.
 */
function maskPhoneNumber(phone: string): string {
  const trimmed = phone.trim();

  if (trimmed.length < 4) {
    return "****";
  }

  return `****${trimmed.slice(-4)}`;
}

/* =========================================================
   BADGES
   ========================================================= */

function AvailabilityBadge({
  isAvailable,
}: {
  isAvailable: boolean;
}) {
  return (
    <span
      className={`donors-availability-badge${
        isAvailable
          ? " donors-availability-badge--available"
          : " donors-availability-badge--unavailable"
      }`}
    >
      {isAvailable ? "Available" : "Unavailable"}
    </span>
  );
}

function BloodGroupBadge({ code }: { code: string }) {
  return (
    <span className="donors-blood-badge">{code}</span>
  );
}

/* =========================================================
   MUTATION ERROR MAPPING
   ========================================================= */

function friendlyMutationError(
  mutationError: { code?: string; message?: string },
): string {
  const isRlsViolation =
    mutationError.code === "42501" ||
    (mutationError.message ?? "")
      .toLowerCase()
      .includes("row-level security");

  if (isRlsViolation) {
    return "You do not have permission to perform this action. Please contact your administrator if you believe this is a mistake.";
  }

  return "Something went wrong while saving. Please try again.";
}

/* =========================================================
   EDIT FORM HELPERS (SUPER_ADMIN only)
   ========================================================= */

function getEditFormInitial(
  record: DonorRecord,
): DonorEditFormState {
  return {
    isAvailable: record.is_available,
    totalDonations: String(record.total_donations),
    lastDonationDate: record.last_donation_date
      ? record.last_donation_date.slice(0, 10)
      : "",
  };
}

function validateEditForm(
  form: DonorEditFormState,
): string | null {
  const donations = Number(form.totalDonations);

  if (
    form.totalDonations.trim() === "" ||
    Number.isNaN(donations) ||
    !Number.isInteger(donations) ||
    donations < 0
  ) {
    return "Total donations must be a whole number of 0 or more.";
  }

  if (form.lastDonationDate) {
    const parsed = new Date(form.lastDonationDate);

    if (Number.isNaN(parsed.getTime())) {
      return "Please provide a valid last donation date.";
    }
  }

  return null;
}

/* =========================================================
   TABLE ROW (desktop)
   ========================================================= */

interface DonorRowProps {
  record: DonorRecord;
  canUpdate: boolean;
  onEdit: () => void;
}

function DonorTableRow({
  record,
  canUpdate,
  onEdit,
}: DonorRowProps) {
  const group = record.blood_groups;
  const city = record.cities;
  const province = city?.provinces;
  const age = computeAge(record.date_of_birth);

  return (
    <tr>
      <td>
        <div className="donors-table__donor">
          <strong>
            {record.users?.full_name ?? "Unknown donor"}
          </strong>

          <span>{maskPhoneNumber(record.phone_number)}</span>
        </div>
      </td>

      <td>
        <div className="donors-table__group">
          <BloodGroupBadge code={group?.code ?? "—"} />
          <span>{group?.name ?? "Unknown group"}</span>
        </div>
      </td>

      <td>{formatGender(record.gender)}</td>

      <td>{age !== null ? age : "—"}</td>

      <td>
        <div className="donors-table__location">
          <span>{city?.name ?? "—"}</span>
          <span>{province?.name ?? "—"}</span>
        </div>
      </td>

      <td>
        <AvailabilityBadge isAvailable={record.is_available} />
      </td>

      <td>
        <strong>{record.total_donations}</strong>
      </td>

      <td>
        {record.last_donation_date
          ? formatDate(record.last_donation_date)
          : "—"}
      </td>

      <td>{formatDate(record.created_at)}</td>

      {canUpdate && (
        <td>
          <div className="donors-table__actions">
            <button
              type="button"
              className="donors-icon-button"
              onClick={onEdit}
              aria-label="Edit donor record"
              title="Edit"
            >
              <Pencil />
            </button>
          </div>
        </td>
      )}
    </tr>
  );
}

/* =========================================================
   CARD (mobile)
   ========================================================= */

function DonorCard({
  record,
  canUpdate,
  onEdit,
}: DonorRowProps) {
  const group = record.blood_groups;
  const city = record.cities;
  const province = city?.provinces;
  const age = computeAge(record.date_of_birth);

  return (
    <div className="donors-card">
      <div className="donors-card__top">
        <div className="donors-card__donor">
          <strong>
            {record.users?.full_name ?? "Unknown donor"}
          </strong>

          <span>{maskPhoneNumber(record.phone_number)}</span>
        </div>

        <div className="donors-card__badges">
          <BloodGroupBadge code={group?.code ?? "—"} />
          <AvailabilityBadge isAvailable={record.is_available} />
        </div>
      </div>

      <div className="donors-card__location">
        <MapPin />
        {city?.name ?? "—"}
        {province ? `, ${province.name}` : ""}
      </div>

      <div className="donors-card__grid">
        <div className="donors-card__field">
          <span className="donors-card__field-label">
            Gender
          </span>

          <span className="donors-card__field-value">
            {formatGender(record.gender)}
          </span>
        </div>

        <div className="donors-card__field">
          <span className="donors-card__field-label">
            Age
          </span>

          <span className="donors-card__field-value">
            {age !== null ? age : "—"}
          </span>
        </div>

        <div className="donors-card__field">
          <span className="donors-card__field-label">
            Donations
          </span>

          <span className="donors-card__field-value">
            {record.total_donations}
          </span>
        </div>

        <div className="donors-card__field">
          <span className="donors-card__field-label">
            Last Donation
          </span>

          <span className="donors-card__field-value">
            {record.last_donation_date
              ? formatDate(record.last_donation_date)
              : "—"}
          </span>
        </div>
      </div>

      {canUpdate && (
        <div className="donors-card__actions">
          <button
            type="button"
            className="donors-card__action"
            onClick={onEdit}
          >
            <Pencil />
            Edit
          </button>
        </div>
      )}
    </div>
  );
}

/* =========================================================
   MAIN CLIENT COMPONENT
   ========================================================= */

export default function DonorsClient({
  data,
  currentUser,
}: DonorsClientProps) {
  const router = useRouter();

  const {
    records,
    bloodGroups,
    summary,
    error,
  } = data;

  /* ------------------------------------------------
     Permissions
     ------------------------------------------------ */

  const canUpdate = canUpdateDonor(currentUser.role);

  /* ------------------------------------------------
     Filters
     ------------------------------------------------ */

  const [groupFilter, setGroupFilter] = useState("");
  const [availabilityFilter, setAvailabilityFilter] =
    useState("");
  const [genderFilter, setGenderFilter] = useState("");
  const [cityFilter, setCityFilter] = useState("");
  const [searchQuery, setSearchQuery] = useState("");

  const allGroups = useMemo(() => {
    /*
     * Merge the blood_groups reference list with any
     * groups present on the records (covers the case
     * where a group was soft-deleted after donors
     * referenced it).
     */
    const merged = new Map<
      string,
      {
        id: string;
        code: string;
        name: string;
      }
    >();

    for (const group of bloodGroups) {
      merged.set(group.id, group);
    }

    for (const record of records) {
      const joined = record.blood_groups;

      if (joined && !merged.has(joined.id)) {
        merged.set(joined.id, {
          id: joined.id,
          code: joined.code,
          name: joined.name,
        });
      }
    }

    return Array.from(merged.values()).sort((a, b) =>
      a.code.localeCompare(b.code),
    );
  }, [bloodGroups, records]);

  const availableGenders = useMemo(() => {
    const genders = new Set<string>();

    for (const record of records) {
      genders.add(record.gender);
    }

    return Array.from(genders).sort((a, b) =>
      a.toLowerCase().localeCompare(b.toLowerCase()),
    );
  }, [records]);

  const availableCities = useMemo(() => {
    const cities = new Map<string, string>();

    for (const record of records) {
      const city = record.cities;

      if (city && !cities.has(city.id)) {
        cities.set(city.id, city.name);
      }
    }

    return Array.from(cities.entries())
      .map(([id, name]) => ({ id, name }))
      .sort((a, b) => a.name.localeCompare(b.name));
  }, [records]);

  const filteredRecords = useMemo(() => {
    const query = searchQuery.trim().toLowerCase();

    return records.filter((record) => {
      if (
        groupFilter &&
        record.blood_group_id !== groupFilter
      ) {
        return false;
      }

      if (availabilityFilter) {
        const wantsAvailable =
          availabilityFilter === "available";

        if (record.is_available !== wantsAvailable) {
          return false;
        }
      }

      if (genderFilter && record.gender !== genderFilter) {
        return false;
      }

      if (cityFilter && record.city_id !== cityFilter) {
        return false;
      }

      if (query) {
        const haystack = [
          record.users?.full_name ?? "",
          record.cities?.name ?? "",
        ]
          .join(" ")
          .toLowerCase();

        if (!haystack.includes(query)) {
          return false;
        }
      }

      return true;
    });
  }, [
    records,
    groupFilter,
    availabilityFilter,
    genderFilter,
    cityFilter,
    searchQuery,
  ]);

  const hasActiveFilters =
    groupFilter !== "" ||
    availabilityFilter !== "" ||
    genderFilter !== "" ||
    cityFilter !== "" ||
    searchQuery.trim() !== "";

  function clearFilters() {
    setGroupFilter("");
    setAvailabilityFilter("");
    setGenderFilter("");
    setCityFilter("");
    setSearchQuery("");
  }

  /* ------------------------------------------------
     Edit modal state (SUPER_ADMIN only)
     ------------------------------------------------ */

  const [modal, setModal] = useState<ModalState>({
    type: "closed",
  });

  const [form, setForm] = useState<DonorEditFormState>({
    isAvailable: false,
    totalDonations: "0",
    lastDonationDate: "",
  });

  const [formError, setFormError] = useState<string | null>(
    null,
  );

  const [submitting, setSubmitting] = useState(false);

  const isModalOpen = modal.type !== "closed";

  function openEditModal(record: DonorRecord) {
    setForm(getEditFormInitial(record));
    setFormError(null);
    setModal({ type: "edit", record });
  }

  function closeModal() {
    if (submitting) return;

    setModal({ type: "closed" });
    setFormError(null);
  }

  useEffect(() => {
    if (!isModalOpen) return;

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, [isModalOpen]);

  useEffect(() => {
    if (!isModalOpen) return;

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape" && !submitting) {
        setModal({ type: "closed" });
        setFormError(null);
      }
    }

    window.addEventListener("keydown", handleKeyDown);

    return () =>
      window.removeEventListener("keydown", handleKeyDown);
  }, [isModalOpen, submitting]);

  /* ------------------------------------------------
     Save (limited SUPER_ADMIN update)
     ------------------------------------------------ */

  async function handleSave(): Promise<void> {
    if (modal.type !== "edit") return;

    const validationError = validateEditForm(form);

    if (validationError) {
      setFormError(validationError);
      return;
    }

    setFormError(null);
    setSubmitting(true);

    try {
      const supabase = createClient();

      /*
       * Limited operational edit only — PII columns
       * (phone_number, date_of_birth) are never edited
       * from the web dashboard.
       */
      const updatePayload = {
        is_available: form.isAvailable,
        total_donations: Number(form.totalDonations),
        last_donation_date: form.lastDonationDate
          ? new Date(form.lastDonationDate).toISOString()
          : null,
        updated_at: new Date().toISOString(),
      };

      const { error: updateError } = await supabase
        .from("donors")
        .update(updatePayload)
        .eq("id", modal.record.id);

      if (updateError) {
        console.error(
          "DONORS - UPDATE ERROR",
          updateError,
        );

        setFormError(friendlyMutationError(updateError));
        return;
      }

      setModal({ type: "closed" });
      setFormError(null);

      router.refresh();
    } catch (saveException) {
      console.error(
        "DONORS - SAVE EXCEPTION",
        saveException,
      );

      setFormError(
        "Something went wrong while saving. Please try again.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  /* ------------------------------------------------
     Error state
     ------------------------------------------------ */

  if (error) {
    return (
      <div className="donors-page">
        <header className="donors-header donors-fade-in donors-fade-in--1">
          <div className="donors-header__content">
            <div className="donors-header__icon">
              <Users />
            </div>

            <div className="donors-header__titles">
              <p className="donors-header__eyebrow">
                DONOR REGISTRY
              </p>

              <h1 className="donors-header__title">
                Donors
              </h1>

              <p className="donors-header__description">
                View registered blood donors across
                the LifeLynk healthcare network.
              </p>
            </div>
          </div>
        </header>

        <div className="donors-error donors-fade-in donors-fade-in--2">
          <div className="donors-error__icon">
            <AlertTriangle />
          </div>

          <strong>Unable to load donor data</strong>

          <p>Please try again later.</p>
        </div>
      </div>
    );
  }

  /* ------------------------------------------------
     Render
     ------------------------------------------------ */

  return (
    <div className="donors-page">
      {/* Header */}
      <header className="donors-header donors-fade-in donors-fade-in--1">
        <div className="donors-header__content">
          <div className="donors-header__icon">
            <Users />
          </div>

          <div className="donors-header__titles">
            <p className="donors-header__eyebrow">
              DONOR REGISTRY
            </p>

            <h1 className="donors-header__title">
              Donors
            </h1>

            <p className="donors-header__description">
              View registered blood donors across the
              LifeLynk healthcare network.
            </p>
          </div>
        </div>

        {/*
         * No create action: the donors INSERT policy
         * requires user_id = auth.uid(), so only donors
         * themselves can register. Non-super-admin roles
         * see a read-only indicator instead.
         */}
        {!canUpdate && (
          <span className="donors-header__badge">
            <EyeOff />
            Read-only
          </span>
        )}
      </header>

      {/* Summary stats */}
      <section className="donors-stats donors-fade-in donors-fade-in--2">
        <article className="donors-stat">
          <span className="donors-stat__icon">
            <Users />
          </span>

          <div className="donors-stat__content">
            <p>Total Donors</p>
            <strong>{summary.totalDonors}</strong>
          </div>

          <span className="donors-stat__label">
            Registered
          </span>
        </article>

        <article className="donors-stat">
          <span className="donors-stat__icon">
            <UserCheck />
          </span>

          <div className="donors-stat__content">
            <p>Available Donors</p>
            <strong>{summary.availableDonors}</strong>
          </div>

          <span className="donors-stat__label">
            Ready
          </span>
        </article>

        <article className="donors-stat">
          <span className="donors-stat__icon">
            <UserX />
          </span>

          <div className="donors-stat__content">
            <p>Unavailable Donors</p>
            <strong>{summary.unavailableDonors}</strong>
          </div>

          <span className="donors-stat__label">
            Resting
          </span>
        </article>

        <article className="donors-stat">
          <span className="donors-stat__icon">
            <Droplets />
          </span>

          <div className="donors-stat__content">
            <p>Blood Groups</p>
            <strong>{summary.bloodGroupCount}</strong>
          </div>

          <span className="donors-stat__label">
            Types
          </span>
        </article>

        <article className="donors-stat">
          <span className="donors-stat__icon">
            <MapPin />
          </span>

          <div className="donors-stat__content">
            <p>Cities Covered</p>
            <strong>{summary.cityCount}</strong>
          </div>

          <span className="donors-stat__label">
            Regions
          </span>
        </article>
      </section>

      {/* Records section */}
      {records.length > 0 && (
        <section className="donors-records donors-fade-in donors-fade-in--3">
          <div className="donors-records__header">
            <div>
              <p>DONOR RECORDS</p>
              <h3>Donor registry</h3>
            </div>

            <span className="donors-records__count">
              {hasActiveFilters
                ? `${filteredRecords.length} of ${records.length}`
                : records.length}{" "}
              {records.length === 1 ? "donor" : "donors"}
            </span>
          </div>

          {/* Filters */}
          <div className="donors-filters">
            <div className="donors-filters__field">
              <label htmlFor="donors-group-filter">
                Blood group
              </label>

              <select
                id="donors-group-filter"
                value={groupFilter}
                onChange={(event) =>
                  setGroupFilter(event.target.value)
                }
              >
                <option value="">All blood groups</option>

                {allGroups.map((group) => (
                  <option key={group.id} value={group.id}>
                    {group.code} — {group.name}
                  </option>
                ))}
              </select>
            </div>

            <div className="donors-filters__field">
              <label htmlFor="donors-availability-filter">
                Availability
              </label>

              <select
                id="donors-availability-filter"
                value={availabilityFilter}
                onChange={(event) =>
                  setAvailabilityFilter(event.target.value)
                }
              >
                <option value="">All availability</option>
                <option value="available">Available</option>
                <option value="unavailable">
                  Unavailable
                </option>
              </select>
            </div>

            <div className="donors-filters__field">
              <label htmlFor="donors-gender-filter">
                Gender
              </label>

              <select
                id="donors-gender-filter"
                value={genderFilter}
                onChange={(event) =>
                  setGenderFilter(event.target.value)
                }
              >
                <option value="">All genders</option>

                {availableGenders.map((gender) => (
                  <option key={gender} value={gender}>
                    {formatGender(gender)}
                  </option>
                ))}
              </select>
            </div>

            <div className="donors-filters__field">
              <label htmlFor="donors-city-filter">
                City
              </label>

              <select
                id="donors-city-filter"
                value={cityFilter}
                onChange={(event) =>
                  setCityFilter(event.target.value)
                }
              >
                <option value="">All cities</option>

                {availableCities.map((city) => (
                  <option key={city.id} value={city.id}>
                    {city.name}
                  </option>
                ))}
              </select>
            </div>

            <div className="donors-filters__field donors-filters__field--search">
              <label htmlFor="donors-search">
                Search
              </label>

              <div className="donors-filters__search-wrap">
                <Search />

                <input
                  id="donors-search"
                  type="text"
                  value={searchQuery}
                  placeholder="Donor name or city"
                  onChange={(event) =>
                    setSearchQuery(event.target.value)
                  }
                />
              </div>
            </div>

            <button
              type="button"
              className="donors-filters__clear"
              onClick={clearFilters}
              disabled={!hasActiveFilters}
            >
              <X />
              Clear filters
            </button>
          </div>

          {/* Desktop table */}
          <div className="donors-table-wrap">
            <table className="donors-table">
              <thead>
                <tr>
                  <th>Donor Name</th>
                  <th>Blood Group</th>
                  <th>Gender</th>
                  <th>Age</th>
                  <th>City / Province</th>
                  <th>Availability</th>
                  <th>Total Donations</th>
                  <th>Last Donation</th>
                  <th>Registered</th>
                  {canUpdate && <th>Actions</th>}
                </tr>
              </thead>

              <tbody>
                {filteredRecords.map((record) => (
                  <DonorTableRow
                    key={record.id}
                    record={record}
                    canUpdate={canUpdate}
                    onEdit={() => openEditModal(record)}
                  />
                ))}
              </tbody>
            </table>
          </div>

          {/* Mobile cards */}
          <div className="donors-cards">
            {filteredRecords.map((record) => (
              <DonorCard
                key={record.id}
                record={record}
                canUpdate={canUpdate}
                onEdit={() => openEditModal(record)}
              />
            ))}
          </div>

          {/* No filter matches */}
          {filteredRecords.length === 0 && (
            <div className="donors-filtered-empty">
              <div className="donors-filtered-empty__icon">
                <Search />
              </div>

              <strong>
                No donors match your filters
              </strong>

              <p>
                Try adjusting the blood group,
                availability, gender, city, or search
                query.
              </p>

              <button
                type="button"
                className="donors-filtered-empty__clear"
                onClick={clearFilters}
              >
                <X />
                Clear filters
              </button>
            </div>
          )}
        </section>
      )}

      {/* Empty state */}
      {records.length === 0 && (
        <section className="donors-records donors-fade-in donors-fade-in--3">
          <div className="donors-empty">
            <div className="donors-empty__icon">
              <Users />
            </div>

            <strong>No donors found</strong>

            <p>
              Donor profiles will appear here once users
              register as blood donors through the
              LifeLynk network.
            </p>
          </div>
        </section>
      )}

      {/* Edit modal (SUPER_ADMIN only) */}
      {modal.type === "edit" && (
        <div
          className="donors-modal-overlay"
          onClick={closeModal}
          role="presentation"
        >
          <div
            className="donors-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="donors-modal-title"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="donors-modal__header">
              <div>
                <p className="donors-modal__eyebrow">
                  EDIT DONOR
                </p>

                <h3
                  id="donors-modal-title"
                  className="donors-modal__title"
                >
                  Update donor record
                </h3>
              </div>

              <button
                type="button"
                className="donors-modal__close"
                onClick={closeModal}
                aria-label="Close dialog"
              >
                <X />
              </button>
            </div>

            <form
              className="donors-modal__form"
              onSubmit={(event) => {
                event.preventDefault();
                void handleSave();
              }}
            >
              {/* Read-only donor context */}
              <div className="donors-form-field donors-form-field--full">
                <label>Donor</label>

                <p className="donors-form-static">
                  {modal.record.users?.full_name ??
                    "Unknown donor"}{" "}
                  — {modal.record.blood_groups?.code ?? "—"}{" "}
                  — {modal.record.cities?.name ?? "—"}
                </p>
              </div>

              {/* Availability */}
              <div className="donors-form-field">
                <label htmlFor="donors-form-availability">
                  Availability
                </label>

                <select
                  id="donors-form-availability"
                  value={
                    form.isAvailable
                      ? "available"
                      : "unavailable"
                  }
                  onChange={(event) =>
                    setForm((current) => ({
                      ...current,
                      isAvailable:
                        event.target.value === "available",
                    }))
                  }
                >
                  <option value="available">
                    Available
                  </option>
                  <option value="unavailable">
                    Unavailable
                  </option>
                </select>

                <span className="donors-form-hint">
                  Availability determines whether the donor
                  appears in matching searches.
                </span>
              </div>

              {/* Total donations */}
              <div className="donors-form-field">
                <label htmlFor="donors-form-donations">
                  Total donations
                </label>

                <input
                  id="donors-form-donations"
                  type="number"
                  min={0}
                  step={1}
                  value={form.totalDonations}
                  onChange={(event) =>
                    setForm((current) => ({
                      ...current,
                      totalDonations: event.target.value,
                    }))
                  }
                />
              </div>

              {/* Last donation date (optional) */}
              <div className="donors-form-field donors-form-field--full">
                <label htmlFor="donors-form-last-donation">
                  Last donation date{" "}
                  <span className="donors-form-optional">
                    (optional)
                  </span>
                </label>

                <input
                  id="donors-form-last-donation"
                  type="date"
                  value={form.lastDonationDate}
                  onChange={(event) =>
                    setForm((current) => ({
                      ...current,
                      lastDonationDate: event.target.value,
                    }))
                  }
                />

                <span className="donors-form-hint">
                  Leave empty if the donor has never
                  donated.
                </span>
              </div>

              {formError && (
                <div
                  className="donors-modal__error"
                  role="alert"
                >
                  <AlertCircle />
                  {formError}
                </div>
              )}

              <div className="donors-modal__footer">
                <button
                  type="button"
                  className="donors-modal__cancel"
                  onClick={closeModal}
                  disabled={submitting}
                >
                  Cancel
                </button>

                <button
                  type="submit"
                  className="donors-modal__submit"
                  disabled={submitting}
                >
                  {submitting ? (
                    <>
                      <LoaderCircle className="donors-spin" />
                      Saving
                    </>
                  ) : (
                    <>
                      <Pencil />
                      Save changes
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
