"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Droplets,
  PackageCheck,
  Layers,
  FileStack,
  Search,
  X,
  Plus,
  Pencil,
  Trash2,
  AlertTriangle,
  AlertCircle,
  MapPin,
  LoaderCircle,
  Warehouse,
} from "lucide-react";

import { createClient } from "@/lib/supabase/client";
import type {
  BloodGroup,
  BloodInventoryData,
  BloodInventoryRecord,
} from "@/lib/dashboard/get-blood-inventory-data";
import type {
  CurrentUser,
  WebRole,
} from "@/lib/auth/get-current-user";

/* =========================================================
   DESIGN NOTES
   =========================================================
 * 1. LOW-STOCK THRESHOLD (see LOW_STOCK_THRESHOLD below) is a
 *    UI-only indicator — NOT a medically defined minimum. The
 *    blood_inventory schema has no minimum_threshold column.
 * 2. `status` is free-text varchar(20) with no enum or CHECK
 *    constraint. Filter options and the edit form's datalist
 *    suggestions are derived from statuses that actually exist
 *    in the data; nothing is hardcoded.
 * 3. blood_inventory has NO deleted_at column — deletion is a
 *    physical DELETE and is permanent.
 * 4. All writes go through the browser Supabase client. RLS is
 *    the enforcement layer (org admins write their own org,
 *    SUPER_ADMIN writes any org); no service role key is used.
 * 5. GOVERNMENT_ADMIN and STAFF are read-only per the RLS
 *    INSERT/UPDATE/DELETE policies — their action controls are
 *    hidden entirely rather than disabled.
 * 6. City filter is derived from the actual organization/city
 *    relationships returned with inventory records. It does
 *    not require a separate database query.
 * ========================================================= */

/* =========================================================
   CONSTANTS
   ========================================================= */

const LOW_STOCK_THRESHOLD = 10;

const EXPIRY_WARNING_DAYS = 7;

const DAY_IN_MS = 24 * 60 * 60 * 1000;

/* =========================================================
   TYPES
   ========================================================= */

interface BloodInventoryClientProps {
  data: BloodInventoryData;
  currentUser: CurrentUser;
}

type ModalState =
  | { type: "closed" }
  | { type: "add" }
  | { type: "edit"; record: BloodInventoryRecord }
  | { type: "delete"; record: BloodInventoryRecord };

interface InventoryFormState {
  organizationId: string;
  bloodGroupId: string;
  totalUnits: string;
  availableUnits: string;
  reservedUnits: string;
  donationDate: string;
  expiryDate: string;
  storageLocation: string;
  status: string;
}

type StockState = "none" | "empty" | "low" | "ok";

/* =========================================================
   PERMISSIONS (mirror of the RLS policies)
   ========================================================= */

function canManageInventory(role: WebRole): boolean {
  /*
   * RLS INSERT/UPDATE/DELETE allow SUPER_ADMIN (any org) and
   * organization admins (HOSPITAL_ADMIN, BLOOD_BANK_ADMIN —
   * own org only). GOVERNMENT_ADMIN and STAFF are read-only.
   */
  return (
    role === "HOSPITAL_ADMIN" ||
    role === "BLOOD_BANK_ADMIN" ||
    role === "SUPER_ADMIN"
  );
}

function canManageRecord(
  record: BloodInventoryRecord,
  role: WebRole,
  organizationId: string | null,
): boolean {
  if (role === "SUPER_ADMIN") return true;

  if (
    role !== "HOSPITAL_ADMIN" &&
    role !== "BLOOD_BANK_ADMIN"
  ) {
    return false;
  }

  return record.organization_id === organizationId;
}

/* =========================================================
   FORMAT HELPERS
   ========================================================= */

function formatType(raw: string): string {
  return raw
    .split("_")
    .map(
      (word) =>
        word.charAt(0).toUpperCase() +
        word.slice(1).toLowerCase(),
    )
    .join(" ");
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

function toISODate(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(
    2,
    "0",
  );
  const day = String(date.getDate()).padStart(2, "0");

  return `${year}-${month}-${day}`;
}

function getExpiryState(
  expiryDate: string,
): "expired" | "expiring" | "ok" {
  const remaining =
    new Date(expiryDate).getTime() - Date.now();

  if (remaining < 0) return "expired";

  if (remaining <= EXPIRY_WARNING_DAYS * DAY_IN_MS) {
    return "expiring";
  }

  return "ok";
}

function getEffectiveStatus(
  record: BloodInventoryRecord,
): string {
  if (getExpiryState(record.expiry_date) === "expired") {
    return "Expired";
  }

  if (record.available_units === 0) {
    return "Depleted";
  }

  return record.status;
}

function daysUntil(expiryDate: string): number {
  return Math.ceil(
    (new Date(expiryDate).getTime() - Date.now()) /
      DAY_IN_MS,
  );
}

/* =========================================================
   STATUS BADGE
   ========================================================= */

/*
 * `status` is free-text — there is no enum. Colors are matched
 * by common word patterns with a neutral fallback so unknown
 * values still render sensibly.
 */
function getStatusBadgeModifier(
  status: string,
): string {
  const value = status.toLowerCase();

  if (
    value.includes("expire") ||
    value.includes("discard")
  ) {
    return "--danger";
  }

  if (
    value.includes("quarantine") ||
    value.includes("hold") ||
    value.includes("reject")
  ) {
    return "--warning";
  }

  if (
    value.includes("reserve") ||
    value.includes("allocat")
  ) {
    return "--info";
  }

  if (
    value.includes("available") ||
    value.includes("ready") ||
    value.includes("active")
  ) {
    return "--success";
  }

  return "";
}

function StatusBadge({ status }: { status: string }) {
  const modifier = getStatusBadgeModifier(status);

  return (
    <span
      className={`blood-inventory-status-badge${
        modifier
          ? ` blood-inventory-status-badge${modifier}`
          : ""
      }`}
    >
      {status}
    </span>
  );
}

/* =========================================================
   EXPIRY CELL
   ========================================================= */

function ExpiryCell({
  expiryDate,
}: {
  expiryDate: string;
}) {
  const state = getExpiryState(expiryDate);
  const days = daysUntil(expiryDate);

  return (
    <span
      className={`blood-inventory-expiry blood-inventory-expiry--${state}`}
    >
      <span className="blood-inventory-expiry__date">
        {formatDate(expiryDate)}
      </span>

      {state === "expired" && (
        <span className="blood-inventory-expiry__hint">
          Expired {Math.abs(days)}d ago
        </span>
      )}

      {state === "expiring" && (
        <span className="blood-inventory-expiry__hint">
          Expires in {days}d
        </span>
      )}
    </span>
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

  if (mutationError.code === "23503") {
    return "This inventory record cannot be deleted because it is linked to an existing blood reservation. Resolve the related reservation first.";
  }

  return "Something went wrong while saving. Please try again.";
}

/* =========================================================
   FORM STATE HELPERS
   ========================================================= */

function getAddFormInitial(
  defaultOrganizationId: string | null,
): InventoryFormState {
  return {
    organizationId: defaultOrganizationId ?? "",
    bloodGroupId: "",
    totalUnits: "",
    availableUnits: "",
    reservedUnits: "0",
    donationDate: toISODate(new Date()),
    expiryDate: "",
    storageLocation: "",
    status: "",
  };
}

function getEditFormInitial(
  record: BloodInventoryRecord,
): InventoryFormState {
  return {
    organizationId: record.organization_id,
    bloodGroupId: record.blood_group_id,
    totalUnits: String(record.total_units),
    availableUnits: String(record.available_units),
    reservedUnits: String(record.reserved_units),
    donationDate: record.donation_date.slice(0, 10),
    expiryDate: record.expiry_date.slice(0, 10),
    storageLocation: record.storage_location ?? "",
    status: record.status,
  };
}

function validateForm(
  form: InventoryFormState,
  requireOrganizationSelection: boolean,
): string | null {
  if (
    requireOrganizationSelection &&
    !form.organizationId
  ) {
    return "Please select the organization this inventory belongs to.";
  }

  if (!form.organizationId) {
    return "No organization is associated with your account, so inventory cannot be recorded.";
  }

  if (!form.bloodGroupId) {
    return "Please select a blood group.";
  }

  const total = Number(form.totalUnits);
  const available = Number(form.availableUnits);
  const reserved = Number(form.reservedUnits);

  if (
    form.totalUnits.trim() === "" ||
    Number.isNaN(total) ||
    !Number.isInteger(total) ||
    total < 0
  ) {
    return "Total units must be a whole number of 0 or more.";
  }

  if (
    form.availableUnits.trim() === "" ||
    Number.isNaN(available) ||
    !Number.isInteger(available) ||
    available < 0
  ) {
    return "Available units must be a whole number of 0 or more.";
  }

  if (
    form.reservedUnits.trim() === "" ||
    Number.isNaN(reserved) ||
    !Number.isInteger(reserved) ||
    reserved < 0
  ) {
    return "Reserved units must be a whole number of 0 or more.";
  }

  // Mirrors the DB CHECK constraint:
  // (available_units + reserved_units) <= total_units
  if (available + reserved > total) {
    return "Available and reserved units together cannot exceed total units.";
  }

  if (!form.donationDate) {
    return "Please provide the donation date.";
  }

  if (!form.expiryDate) {
    return "Please provide the expiry date.";
  }

  if (
    new Date(form.expiryDate) <=
    new Date(form.donationDate)
  ) {
    return "Expiry date must be after the donation date.";
  }

  if (!form.status.trim()) {
    return "Please provide a status describing the current stock state.";
  }

  if (form.status.trim().length > 20) {
    return "Status must be 20 characters or fewer.";
  }

  if (form.storageLocation.length > 100) {
    return "Storage location must be 100 characters or fewer.";
  }

  return null;
}

/* =========================================================
   AVAILABILITY CARD
   ========================================================= */

const STOCK_STATE_LABELS: Record<StockState, string> = {
  none: "No stock reported",
  empty: "None available",
  low: "Low stock",
  ok: "In stock",
};

function getStockState(
  availableUnits: number,
  recordCount: number,
): StockState {
  if (recordCount === 0) return "none";

  if (availableUnits <= 0) return "empty";

  if (availableUnits < LOW_STOCK_THRESHOLD) {
    return "low";
  }

  return "ok";
}

interface AvailabilityCardProps {
  id: string;
  code: string;
  name: string;
  availableUnits: number;
  totalUnits: number;
  reservedUnits: number;
  recordCount: number;
}

function AvailabilityCard({
  code,
  name,
  availableUnits,
  totalUnits,
  reservedUnits,
  recordCount,
}: AvailabilityCardProps) {
  const state = getStockState(
    availableUnits,
    recordCount,
  );

  const availablePct =
    totalUnits > 0
      ? (availableUnits / totalUnits) * 100
      : 0;

  const reservedPct =
    totalUnits > 0
      ? (reservedUnits / totalUnits) * 100
      : 0;

  return (
    <article
      className={`blood-inventory-group blood-inventory-group--${state}`}
    >
      <div className="blood-inventory-group__head">
        <span className="blood-inventory-group__icon">
          <Droplets />
        </span>

        <span className="blood-inventory-group__state">
          {STOCK_STATE_LABELS[state]}
        </span>
      </div>

      <div className="blood-inventory-group__identity">
        <strong>{code}</strong>
        <span>{name}</span>
      </div>

      <div className="blood-inventory-group__units">
        <span className="blood-inventory-group__available">
          {availableUnits}
          <small> available</small>
        </span>

        <span className="blood-inventory-group__total">
          of {totalUnits} total units
        </span>
      </div>

      <div className="blood-inventory-group__bar">
        {totalUnits > 0 && (
          <>
            <span
              className="blood-inventory-group__bar-available"
              style={{ width: `${availablePct}%` }}
            />

            <span
              className="blood-inventory-group__bar-reserved"
              style={{ width: `${reservedPct}%` }}
            />
          </>
        )}
      </div>

      <div className="blood-inventory-group__meta">
        <span>{reservedUnits} reserved</span>

        <span>
          {recordCount}{" "}
          {recordCount === 1 ? "record" : "records"}
        </span>
      </div>
    </article>
  );
}

/* =========================================================
   TABLE ROW (desktop)
   ========================================================= */

interface RecordActionProps {
  record: BloodInventoryRecord;
  manageEnabled: boolean;
  canManage: boolean;
  onEdit: () => void;
  onDelete: () => void;
}

function InventoryTableRow({
  record,
  manageEnabled,
  canManage,
  onEdit,
  onDelete,
}: RecordActionProps) {
  const group = record.blood_groups;
  const org = record.organizations;
  const city = org?.cities;
  const province = city?.provinces;

  return (
    <tr>
      <td>
        <div className="blood-inventory-table__group">
          <strong>{group?.code ?? "—"}</strong>

          <span>
            {group?.name ?? "Unknown group"}
          </span>
        </div>
      </td>

      <td>
        <div className="blood-inventory-table__org">
          <strong>
            {org?.name ?? "Unknown organization"}
          </strong>

          <span>
            {org
              ? formatType(org.organization_type)
              : "—"}
          </span>
        </div>
      </td>

      <td>
        <div className="blood-inventory-table__units">
          <strong>{record.available_units}</strong>

          <span>
            / {record.total_units} total
          </span>
        </div>
      </td>

      <td>{record.reserved_units}</td>

      <td>
        <StatusBadge
          status={getEffectiveStatus(record)}
        />
      </td>

      <td>
        {formatDate(record.donation_date)}
      </td>

      <td>
        <ExpiryCell
          expiryDate={record.expiry_date}
        />
      </td>

      <td>
        {record.storage_location ?? "—"}
      </td>

      <td>
        <div className="blood-inventory-table__location">
          <span>{city?.name ?? "—"}</span>

          <span>
            {province?.name ?? "—"}
          </span>
        </div>
      </td>

      {manageEnabled && (
        <td>
          {canManage && (
            <div className="blood-inventory-table__actions">
              <button
                type="button"
                className="blood-inventory-icon-button"
                onClick={onEdit}
                aria-label="Edit inventory record"
                title="Edit"
              >
                <Pencil />
              </button>

              <button
                type="button"
                className="blood-inventory-icon-button blood-inventory-icon-button--danger"
                onClick={onDelete}
                aria-label={
                  record.reservation_count > 0
                    ? "Cannot delete inventory record because it has reservations"
                    : "Delete inventory record"
                }
                title={
                  record.reservation_count > 0
                    ? `Cannot delete: ${
                        record.reservation_count
                      } ${
                        record.reservation_count === 1
                          ? "reservation"
                          : "reservations"
                      } linked`
                    : "Delete"
                }
              >
                <Trash2 />
              </button>
            </div>
          )}
        </td>
      )}
    </tr>
  );
}

/* =========================================================
   CARD (mobile)
   ========================================================= */

function InventoryCard({
  record,
  manageEnabled,
  canManage,
  onEdit,
  onDelete,
}: RecordActionProps) {
  const group = record.blood_groups;
  const org = record.organizations;
  const city = org?.cities;
  const province = city?.provinces;

  return (
    <div className="blood-inventory-card">
      <div className="blood-inventory-card__top">
        <div className="blood-inventory-card__group">
          <strong>{group?.code ?? "—"}</strong>

          <span>
            {group?.name ?? "Unknown group"}
          </span>
        </div>

        <StatusBadge
          status={getEffectiveStatus(record)}
        />
      </div>

      <div className="blood-inventory-card__org">
        {org?.name ?? "Unknown organization"}
      </div>

      <div className="blood-inventory-card__location">
        <MapPin />

        {city?.name ?? "—"}, {province?.name ?? "—"}
      </div>

      <div className="blood-inventory-card__grid">
        <div className="blood-inventory-card__field">
          <span className="blood-inventory-card__field-label">
            Available
          </span>

          <span className="blood-inventory-card__field-value">
            {record.available_units} of{" "}
            {record.total_units}
          </span>
        </div>

        <div className="blood-inventory-card__field">
          <span className="blood-inventory-card__field-label">
            Reserved
          </span>

          <span className="blood-inventory-card__field-value">
            {record.reserved_units}
          </span>
        </div>

        <div className="blood-inventory-card__field">
          <span className="blood-inventory-card__field-label">
            Donation
          </span>

          <span className="blood-inventory-card__field-value">
            {formatDate(record.donation_date)}
          </span>
        </div>

        <div className="blood-inventory-card__field">
          <span className="blood-inventory-card__field-label">
            Expiry
          </span>

          <span className="blood-inventory-card__field-value">
            <ExpiryCell
              expiryDate={record.expiry_date}
            />
          </span>
        </div>

        <div className="blood-inventory-card__field">
          <span className="blood-inventory-card__field-label">
            Storage
          </span>

          <span className="blood-inventory-card__field-value">
            {record.storage_location ?? "—"}
          </span>
        </div>
      </div>

      {manageEnabled && canManage && (
        <div className="blood-inventory-card__actions">
          <button
            type="button"
            className="blood-inventory-card__action"
            onClick={onEdit}
          >
            <Pencil />
            Edit
          </button>

          <button
            type="button"
            className="blood-inventory-card__action blood-inventory-card__action--danger"
            onClick={onDelete}
            title={
              record.reservation_count > 0
                ? `Cannot delete: ${
                    record.reservation_count
                  } ${
                    record.reservation_count === 1
                      ? "reservation"
                      : "reservations"
                  } linked`
                : "Delete"
            }
          >
            <Trash2 />
            Delete
          </button>
        </div>
      )}
    </div>
  );
}

/* =========================================================
   MAIN CLIENT COMPONENT
   ========================================================= */

export default function BloodInventoryClient({
  data,
  currentUser,
}: BloodInventoryClientProps) {
  const router = useRouter();

  const {
    records,
    bloodGroups,
    groupSummaries,
    summary,
    error,
  } = data;

  /* ------------------------------------------------
     Permissions
     ------------------------------------------------ */

  const isSuperAdmin =
    currentUser.role === "SUPER_ADMIN";

  const manageEnabled = canManageInventory(
    currentUser.role,
  );

  /* ------------------------------------------------
     Filters
     ------------------------------------------------ */

  const [groupFilter, setGroupFilter] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [cityFilter, setCityFilter] = useState("");
  const [searchQuery, setSearchQuery] = useState("");

  /*
   * `status` is free-text — derive the filter options from
   * statuses that actually exist in the records.
   */
  const availableStatuses = useMemo(() => {
    const statuses = new Set<string>();

    for (const record of records) {
      statuses.add(record.status);
    }

    return Array.from(statuses).sort((a, b) =>
      a.toLowerCase().localeCompare(
        b.toLowerCase(),
      ),
    );
  }, [records]);

  /*
   * Active blood groups, plus any groups that still have
   * records but are no longer active.
   */
  const allGroups = useMemo(() => {
    const merged = new Map<string, BloodGroup>();

    for (const group of bloodGroups) {
      merged.set(group.id, group);
    }

    for (const record of records) {
      const joined = record.blood_groups;

      if (
        joined &&
        !merged.has(joined.id)
      ) {
        merged.set(joined.id, {
          id: joined.id,
          code: joined.code,
          name: joined.name,
        });
      }
    }

    return Array.from(merged.values()).sort(
      (a, b) =>
        a.code.localeCompare(b.code),
    );
  }, [bloodGroups, records]);

  /*
   * City filter options are derived from the actual cities
   * attached to the organizations represented in inventory.
   *
   * No extra database query is needed.
   */
  const availableCities = useMemo(() => {
    const cities = new Map<string, string>();

    for (const record of records) {
      const city = record.organizations?.cities;

      if (city?.id && city.name) {
        cities.set(city.id, city.name);
      }
    }

    return Array.from(cities.entries())
      .map(([id, name]) => ({
        id,
        name,
      }))
      .sort((a, b) =>
        a.name.localeCompare(b.name),
      );
  }, [records]);

  /*
   * Apply all inventory filters.
   */
  const filteredRecords = useMemo(() => {
    const query = searchQuery
      .trim()
      .toLowerCase();

    return records.filter((record) => {
      if (
        groupFilter &&
        record.blood_group_id !== groupFilter
      ) {
        return false;
      }

      if (
        statusFilter &&
        record.status !== statusFilter
      ) {
        return false;
      }

      if (
        cityFilter &&
        record.organizations?.cities?.id !==
          cityFilter
      ) {
        return false;
      }

      if (query) {
        const haystack = [
          record.organizations?.name ?? "",
          record.blood_groups?.code ?? "",
          record.blood_groups?.name ?? "",
          record.organizations?.cities?.name ?? "",
          record.organizations?.cities?.provinces
            ?.name ?? "",
          record.storage_location ?? "",
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
    statusFilter,
    cityFilter,
    searchQuery,
  ]);

  const hasActiveFilters =
    groupFilter !== "" ||
    statusFilter !== "" ||
    cityFilter !== "" ||
    searchQuery.trim() !== "";

  function clearFilters() {
    setGroupFilter("");
    setStatusFilter("");
    setCityFilter("");
    setSearchQuery("");
  }

  /* ------------------------------------------------
     Availability grid (server-computed summaries)
     ------------------------------------------------ */

  const availabilityCards = useMemo(() => {
    const summaryByCode = new Map(
      groupSummaries.map((groupSummary) => [
        groupSummary.code,
        groupSummary,
      ]),
    );

    return allGroups.map((group) => {
      const groupSummary =
        summaryByCode.get(group.code);

      return {
        id: group.id,
        code: group.code,
        name: group.name,
        availableUnits:
          groupSummary?.availableUnits ?? 0,
        totalUnits:
          groupSummary?.totalUnits ?? 0,
        reservedUnits:
          groupSummary?.reservedUnits ?? 0,
        recordCount:
          groupSummary?.recordCount ?? 0,
      };
    });
  }, [allGroups, groupSummaries]);

  /* ------------------------------------------------
     Organization options (SUPER_ADMIN add form)
     ------------------------------------------------ */

  /*
   * SUPER_ADMIN has no organization of their own, so the add
   * form needs a target. When availableOrganizations is
   * provided by the server (SUPER_ADMIN only), it contains
   * all VERIFIED organizations from the organizations table.
   */
  const organizationOptions = useMemo(() => {
    if (data.availableOrganizations) {
      return data.availableOrganizations
        .map((org) => ({
          id: org.id,
          name: org.name,
          type: org.organization_type,
        }))
        .sort((a, b) =>
          a.name.localeCompare(b.name),
        );
    }

    /*
     * Fallback: derive from existing records.
     */
    const options = new Map<
      string,
      {
        id: string;
        name: string;
        type: string;
      }
    >();

    for (const record of records) {
      const org = record.organizations;

      if (
        org &&
        !options.has(org.id)
      ) {
        options.set(org.id, {
          id: org.id,
          name: org.name,
          type: org.organization_type,
        });
      }
    }

    return Array.from(options.values()).sort(
      (a, b) =>
        a.name.localeCompare(b.name),
    );
  }, [
    data.availableOrganizations,
    records,
  ]);

  /* ------------------------------------------------
     Modal state
     ------------------------------------------------ */

  const [modal, setModal] =
    useState<ModalState>({
      type: "closed",
    });

  const [form, setForm] =
    useState<InventoryFormState>(() =>
      getAddFormInitial(
        currentUser.organizationId,
      ),
    );

  const [formError, setFormError] =
    useState<string | null>(null);

  const [actionError, setActionError] =
    useState<string | null>(null);

  const [submitting, setSubmitting] =
    useState(false);

  const isModalOpen =
    modal.type !== "closed";

  function openAddModal() {
    setForm(
      getAddFormInitial(
        currentUser.organizationId,
      ),
    );

    setFormError(null);
    setActionError(null);

    setModal({
      type: "add",
    });
  }

  function openEditModal(
    record: BloodInventoryRecord,
  ) {
    setForm(
      getEditFormInitial(record),
    );

    setFormError(null);
    setActionError(null);

    setModal({
      type: "edit",
      record,
    });
  }

  function openDeleteModal(
    record: BloodInventoryRecord,
  ) {
    setFormError(null);
    setActionError(null);

    setModal({
      type: "delete",
      record,
    });
  }

  function closeModal() {
    if (submitting) return;

    setModal({
      type: "closed",
    });

    setFormError(null);
    setActionError(null);
  }

  /* Lock body scroll while a modal is open */
  useEffect(() => {
    if (!isModalOpen) return;

    const previousOverflow =
      document.body.style.overflow;

    document.body.style.overflow = "hidden";

    return () => {
      document.body.style.overflow =
        previousOverflow;
    };
  }, [isModalOpen]);

  /* Escape closes the open modal */
  useEffect(() => {
    if (!isModalOpen) return;

    function handleKeyDown(
      event: KeyboardEvent,
    ) {
      if (
        event.key === "Escape" &&
        !submitting
      ) {
        setModal({
          type: "closed",
        });

        setFormError(null);
        setActionError(null);
      }
    }

    window.addEventListener(
      "keydown",
      handleKeyDown,
    );

    return () =>
      window.removeEventListener(
        "keydown",
        handleKeyDown,
      );
  }, [isModalOpen, submitting]);

  function updateForm(
    field: keyof InventoryFormState,
    value: string,
  ): void {
    setForm((current) => ({
      ...current,
      [field]: value,
    }));
  }

  /* ------------------------------------------------
     Save (insert / update)
     ------------------------------------------------ */

  async function handleSave(): Promise<void> {
    const requireOrgSelection =
      isSuperAdmin &&
      modal.type === "add";

    const validationError =
      validateForm(
        form,
        requireOrgSelection,
      );

    if (validationError) {
      setFormError(
        validationError,
      );
      return;
    }

    setFormError(null);
    setSubmitting(true);

    try {
      /*
       * Browser client + RLS: org admins may only write their
       * own organization's records, SUPER_ADMIN may write any.
       */
      const supabase = createClient();

      const payload = {
        organization_id:
          form.organizationId,
        blood_group_id:
          form.bloodGroupId,
        total_units:
          Number(form.totalUnits),
        available_units:
          Number(form.availableUnits),
        reserved_units:
          Number(form.reservedUnits),
        donation_date:
          form.donationDate,
        expiry_date:
          form.expiryDate,
        storage_location:
          form.storageLocation.trim() ||
          null,
        status:
          form.status.trim(),
      };

      let mutationError: {
        code?: string;
        message?: string;
      } | null = null;

      if (modal.type === "add") {
        const {
          error: insertError,
        } = await supabase
          .from("blood_inventory")
          .insert(payload);

        mutationError =
          insertError;
      } else if (
        modal.type === "edit"
      ) {
        const {
          error: updateError,
        } = await supabase
          .from("blood_inventory")
          .update(payload)
          .eq(
            "id",
            modal.record.id,
          );

        mutationError =
          updateError;
      }

      if (mutationError) {
        console.error(
          modal.type === "add"
            ? "BLOOD INVENTORY - INSERT ERROR"
            : "BLOOD INVENTORY - UPDATE ERROR",
          mutationError,
        );

        setFormError(
          friendlyMutationError(
            mutationError,
          ),
        );

        return;
      }

      setModal({
        type: "closed",
      });

      setFormError(null);
      setActionError(null);

      /*
       * Re-run the server component with fresh RLS data.
       * Supabase Realtime on the government dashboard can
       * also refresh this data when another client changes it.
       */
      router.refresh();
    } catch (saveException) {
      console.error(
        "BLOOD INVENTORY - SAVE EXCEPTION",
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
     Delete (physical — no soft delete)
     ------------------------------------------------ */

  async function handleDelete(): Promise<void> {
    if (
      modal.type !== "delete"
    ) {
      return;
    }

    setActionError(null);
    setSubmitting(true);

    try {
      const supabase =
        createClient();

      const {
        error: deleteError,
      } = await supabase
        .from("blood_inventory")
        .delete()
        .eq(
          "id",
          modal.record.id,
        );

      if (deleteError) {
        console.error(
          "BLOOD INVENTORY - DELETE ERROR",
          deleteError,
        );

        setActionError(
          friendlyMutationError(
            deleteError,
          ),
        );

        return;
      }

      setModal({
        type: "closed",
      });

      setFormError(null);
      setActionError(null);

      router.refresh();
    } catch (deleteException) {
      console.error(
        "BLOOD INVENTORY - DELETE EXCEPTION",
        deleteException,
      );

      setActionError(
        "Something went wrong while deleting. Please try again.",
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
      <div className="blood-inventory-page">
        <header className="blood-inventory-header blood-inventory-fade-in blood-inventory-fade-in--1">
          <div className="blood-inventory-header__content">
            <div className="blood-inventory-header__icon">
              <Droplets />
            </div>

            <div className="blood-inventory-header__titles">
              <p className="blood-inventory-header__eyebrow">
                BLOOD STOCK MANAGEMENT
              </p>

              <h1 className="blood-inventory-header__title">
                Blood Inventory
              </h1>

              <p className="blood-inventory-header__description">
                Monitor and manage blood stock
                availability across the LifeLynk
                healthcare network.
              </p>
            </div>
          </div>
        </header>

        <div className="blood-inventory-error blood-inventory-fade-in blood-inventory-fade-in--2">
          <div className="blood-inventory-error__icon">
            <AlertTriangle />
          </div>

          <strong>
            Unable to load blood inventory data
          </strong>

          <p>
            Please try again later.
          </p>
        </div>
      </div>
    );
  }

  /* ------------------------------------------------
     Render
     ------------------------------------------------ */

  return (
    <div className="blood-inventory-page">
      {/* Header */}
      <header className="blood-inventory-header blood-inventory-fade-in blood-inventory-fade-in--1">
        <div className="blood-inventory-header__content">
          <div className="blood-inventory-header__icon">
            <Droplets />
          </div>

          <div className="blood-inventory-header__titles">
            <p className="blood-inventory-header__eyebrow">
              BLOOD STOCK MANAGEMENT
            </p>

            <h1 className="blood-inventory-header__title">
              Blood Inventory
            </h1>

            <p className="blood-inventory-header__description">
              Monitor and manage blood stock
              availability across the LifeLynk
              healthcare network.
            </p>
          </div>
        </div>

        {manageEnabled && (
          <button
            type="button"
            className="blood-inventory-add-button"
            onClick={openAddModal}
          >
            <Plus />
            Add Inventory
          </button>
        )}
      </header>

      {/* Summary stats */}
      <section className="blood-inventory-stats blood-inventory-fade-in blood-inventory-fade-in--2">
        <article className="blood-inventory-stat">
          <span className="blood-inventory-stat__icon">
            <Droplets />
          </span>

          <div className="blood-inventory-stat__content">
            <p>
              Total Available Units
            </p>

            <strong>
              {summary.totalAvailableUnits}
            </strong>
          </div>

          <span className="blood-inventory-stat__label">
            Ready
          </span>
        </article>

        <article className="blood-inventory-stat">
          <span className="blood-inventory-stat__icon">
            <PackageCheck />
          </span>

          <div className="blood-inventory-stat__content">
            <p>
              Total Reserved Units
            </p>

            <strong>
              {summary.totalReservedUnits}
            </strong>
          </div>

          <span className="blood-inventory-stat__label">
            Held
          </span>
        </article>

        <article className="blood-inventory-stat">
          <span className="blood-inventory-stat__icon">
            <Layers />
          </span>

          <div className="blood-inventory-stat__content">
            <p>
              Blood Groups
            </p>

            <strong>
              {summary.bloodGroupCount}
            </strong>
          </div>

          <span className="blood-inventory-stat__label">
            Tracked
          </span>
        </article>

        <article className="blood-inventory-stat">
          <span className="blood-inventory-stat__icon">
            <FileStack />
          </span>

          <div className="blood-inventory-stat__content">
            <p>
              Inventory Records
            </p>

            <strong>
              {summary.totalRecords}
            </strong>
          </div>

          <span className="blood-inventory-stat__label">
            Reported
          </span>
        </article>
      </section>

      {/* Blood group availability */}
      {availabilityCards.length > 0 && (
        <section className="blood-inventory-groups-section blood-inventory-fade-in blood-inventory-fade-in--3">
          <div className="blood-inventory-groups-section__header">
            <div>
              <p>
                BLOOD GROUP AVAILABILITY
              </p>

              <h3>
                Stock levels by blood group
              </h3>
            </div>
          </div>

          <p className="blood-inventory-groups-note">
            <AlertCircle />
            Low stock flags groups with fewer
            than{" "}
            {LOW_STOCK_THRESHOLD}{" "}
            available units. This threshold
            is a UI indicator only — not a
            medically defined minimum.
          </p>

          <div className="blood-inventory-groups">
            {availabilityCards.map(
              (card) => (
                <AvailabilityCard
                  key={card.id}
                  id={card.id}
                  code={card.code}
                  name={card.name}
                  availableUnits={
                    card.availableUnits
                  }
                  totalUnits={
                    card.totalUnits
                  }
                  reservedUnits={
                    card.reservedUnits
                  }
                  recordCount={
                    card.recordCount
                  }
                />
              ),
            )}
          </div>
        </section>
      )}

      {/* Inventory records */}
      {records.length > 0 && (
        <section className="blood-inventory-records blood-inventory-fade-in blood-inventory-fade-in--4">
          <div className="blood-inventory-records__header">
            <div>
              <p>
                INVENTORY RECORDS
              </p>

              <h3>
                Reported stock
              </h3>
            </div>

            <span className="blood-inventory-records__count">
              {hasActiveFilters
                ? `${filteredRecords.length} of ${records.length}`
                : records.length}{" "}
              {records.length === 1
                ? "record"
                : "records"}
            </span>
          </div>

          {/* Filters */}
          <div className="blood-inventory-filters">
            {/* Blood group */}
            <div className="blood-inventory-filters__field">
              <label htmlFor="blood-inventory-group-filter">
                Blood group
              </label>

              <select
                id="blood-inventory-group-filter"
                value={groupFilter}
                onChange={(event) =>
                  setGroupFilter(
                    event.target.value,
                  )
                }
              >
                <option value="">
                  All blood groups
                </option>

                {allGroups.map(
                  (group) => (
                    <option
                      key={group.id}
                      value={group.id}
                    >
                      {group.code} —{" "}
                      {group.name}
                    </option>
                  ),
                )}
              </select>
            </div>

            {/* Status */}
            <div className="blood-inventory-filters__field">
              <label htmlFor="blood-inventory-status-filter">
                Status
              </label>

              <select
                id="blood-inventory-status-filter"
                value={statusFilter}
                onChange={(event) =>
                  setStatusFilter(
                    event.target.value,
                  )
                }
              >
                <option value="">
                  All statuses
                </option>

                {availableStatuses.map(
                  (status) => (
                    <option
                      key={status}
                      value={status}
                    >
                      {status}
                    </option>
                  ),
                )}
              </select>
            </div>

            {/* City */}
            <div className="blood-inventory-filters__field">
              <label htmlFor="blood-inventory-city-filter">
                City
              </label>

              <select
                id="blood-inventory-city-filter"
                value={cityFilter}
                onChange={(event) =>
                  setCityFilter(
                    event.target.value,
                  )
                }
              >
                <option value="">
                  All cities
                </option>

                {availableCities.map(
                  (city) => (
                    <option
                      key={city.id}
                      value={city.id}
                    >
                      {city.name}
                    </option>
                  ),
                )}
              </select>
            </div>

            {/* Search */}
            <div className="blood-inventory-filters__field blood-inventory-filters__field--search">
              <label htmlFor="blood-inventory-search">
                Search
              </label>

              <div className="blood-inventory-filters__search-wrap">
                <Search />

                <input
                  id="blood-inventory-search"
                  type="text"
                  value={searchQuery}
                  placeholder="Organization, blood group, city, or storage location"
                  onChange={(event) =>
                    setSearchQuery(
                      event.target.value,
                    )
                  }
                />
              </div>
            </div>

            {/* Clear */}
            <button
              type="button"
              className="blood-inventory-filters__clear"
              onClick={clearFilters}
              disabled={
                !hasActiveFilters
              }
            >
              <X />
              Clear filters
            </button>
          </div>

          {/* Desktop table */}
          <div className="blood-inventory-table-wrap">
            <table className="blood-inventory-table">
              <thead>
                <tr>
                  <th>
                    Blood Group
                  </th>

                  <th>
                    Organization
                  </th>

                  <th>
                    Available / Total
                  </th>

                  <th>
                    Reserved
                  </th>

                  <th>
                    Status
                  </th>

                  <th>
                    Donation Date
                  </th>

                  <th>
                    Expiry Date
                  </th>

                  <th>
                    Storage
                  </th>

                  <th>
                    Location
                  </th>

                  {manageEnabled && (
                    <th>
                      Actions
                    </th>
                  )}
                </tr>
              </thead>

              <tbody>
                {filteredRecords.map(
                  (record) => (
                    <InventoryTableRow
                      key={record.id}
                      record={record}
                      manageEnabled={
                        manageEnabled
                      }
                      canManage={canManageRecord(
                        record,
                        currentUser.role,
                        currentUser.organizationId,
                      )}
                      onEdit={() =>
                        openEditModal(
                          record,
                        )
                      }
                      onDelete={() =>
                        openDeleteModal(
                          record,
                        )
                      }
                    />
                  ),
                )}
              </tbody>
            </table>
          </div>

          {/* Mobile cards */}
          <div className="blood-inventory-cards">
            {filteredRecords.map(
              (record) => (
                <InventoryCard
                  key={record.id}
                  record={record}
                  manageEnabled={
                    manageEnabled
                  }
                  canManage={canManageRecord(
                    record,
                    currentUser.role,
                    currentUser.organizationId,
                  )}
                  onEdit={() =>
                    openEditModal(
                      record,
                    )
                  }
                  onDelete={() =>
                    openDeleteModal(
                      record,
                    )
                  }
                />
              ),
            )}
          </div>

          {/* No filter matches */}
          {filteredRecords.length ===
            0 && (
            <div className="blood-inventory-filtered-empty">
              <div className="blood-inventory-filtered-empty__icon">
                <Search />
              </div>

              <strong>
                No records match your
                filters
              </strong>

              <p>
                Try adjusting the blood
                group, status, city, or
                search query.
              </p>

              <button
                type="button"
                className="blood-inventory-filtered-empty__clear"
                onClick={
                  clearFilters
                }
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
        <section className="blood-inventory-records blood-inventory-fade-in blood-inventory-fade-in--4">
          <div className="blood-inventory-empty">
            <div className="blood-inventory-empty__icon">
              <Droplets />
            </div>

            <strong>
              No blood inventory records
              found
            </strong>

            <p>
              Blood inventory data will
              appear here once
              organizations begin
              reporting their stock.
            </p>
          </div>
        </section>
      )}

      {/* Add / Edit modal */}
      {(modal.type === "add" ||
        modal.type === "edit") && (
        <div
          className="blood-inventory-modal-overlay"
          onClick={closeModal}
          role="presentation"
        >
          <div
            className="blood-inventory-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="blood-inventory-modal-title"
            onClick={(event) =>
              event.stopPropagation()
            }
          >
            <div className="blood-inventory-modal__header">
              <div>
                <p className="blood-inventory-modal__eyebrow">
                  {modal.type === "add"
                    ? "NEW RECORD"
                    : "EDIT RECORD"}
                </p>

                <h3
                  id="blood-inventory-modal-title"
                  className="blood-inventory-modal__title"
                >
                  {modal.type === "add"
                    ? "Add blood inventory"
                    : "Edit blood inventory"}
                </h3>
              </div>

              <button
                type="button"
                className="blood-inventory-modal__close"
                onClick={closeModal}
                aria-label="Close dialog"
              >
                <X />
              </button>
            </div>

            <form
              className="blood-inventory-modal__form"
              onSubmit={(event) => {
                event.preventDefault();
                void handleSave();
              }}
            >
              {/* Organization */}
              <div className="blood-inventory-form-field blood-inventory-form-field--full">
                <label htmlFor="blood-inventory-form-org">
                  Organization
                </label>

                {isSuperAdmin &&
                modal.type === "add" ? (
                  <select
                    id="blood-inventory-form-org"
                    value={
                      form.organizationId
                    }
                    onChange={(event) =>
                      updateForm(
                        "organizationId",
                        event.target
                          .value,
                      )
                    }
                  >
                    <option value="">
                      Select an organization
                    </option>

                    {organizationOptions.map(
                      (org) => (
                        <option
                          key={org.id}
                          value={org.id}
                        >
                          {org.name} (
                          {formatType(
                            org.type,
                          )}
                          )
                        </option>
                      ),
                    )}
                  </select>
                ) : (
                  <p className="blood-inventory-form-static">
                    {modal.type ===
                    "edit"
                      ? modal.record
                          .organizations
                          ?.name ??
                        "Unknown organization"
                      : currentUser.organizationName ??
                        "Your organization"}
                  </p>
                )}

                {isSuperAdmin &&
                  modal.type === "add" &&
                  organizationOptions.length ===
                    0 && (
                    <span className="blood-inventory-form-hint">
                      No verified
                      organizations are
                      available yet.
                    </span>
                  )}
              </div>

              {/* Blood group */}
              <div className="blood-inventory-form-field">
                <label htmlFor="blood-inventory-form-group">
                  Blood group
                </label>

                <select
                  id="blood-inventory-form-group"
                  value={
                    form.bloodGroupId
                  }
                  onChange={(event) =>
                    updateForm(
                      "bloodGroupId",
                      event.target
                        .value,
                    )
                  }
                >
                  <option value="">
                    Select a blood group
                  </option>

                  {allGroups.map(
                    (group) => (
                      <option
                        key={group.id}
                        value={group.id}
                      >
                        {group.code} —{" "}
                        {group.name}
                      </option>
                    ),
                  )}
                </select>
              </div>

              {/* Units */}
              <div className="blood-inventory-form-field">
                <label htmlFor="blood-inventory-form-total">
                  Total units
                </label>

                <input
                  id="blood-inventory-form-total"
                  type="number"
                  min={0}
                  step={1}
                  value={
                    form.totalUnits
                  }
                  onChange={(event) =>
                    updateForm(
                      "totalUnits",
                      event.target
                        .value,
                    )
                  }
                />
              </div>

              <div className="blood-inventory-form-field">
                <label htmlFor="blood-inventory-form-available">
                  Available units
                </label>

                <input
                  id="blood-inventory-form-available"
                  type="number"
                  min={0}
                  step={1}
                  value={
                    form.availableUnits
                  }
                  onChange={(event) =>
                    updateForm(
                      "availableUnits",
                      event.target
                        .value,
                    )
                  }
                />
              </div>

              <div className="blood-inventory-form-field">
                <label htmlFor="blood-inventory-form-reserved">
                  Reserved units
                </label>

                <input
                  id="blood-inventory-form-reserved"
                  type="number"
                  min={0}
                  step={1}
                  value={
                    form.reservedUnits
                  }
                  onChange={(event) =>
                    updateForm(
                      "reservedUnits",
                      event.target
                        .value,
                    )
                  }
                />

                <span className="blood-inventory-form-hint">
                  Available + reserved
                  cannot exceed total
                  units.
                </span>
              </div>

              {/* Dates */}
              <div className="blood-inventory-form-field">
                <label htmlFor="blood-inventory-form-donation">
                  Donation date
                </label>

                <input
                  id="blood-inventory-form-donation"
                  type="date"
                  value={
                    form.donationDate
                  }
                  onChange={(event) =>
                    updateForm(
                      "donationDate",
                      event.target
                        .value,
                    )
                  }
                />
              </div>

              <div className="blood-inventory-form-field">
                <label htmlFor="blood-inventory-form-expiry">
                  Expiry date
                </label>

                <input
                  id="blood-inventory-form-expiry"
                  type="date"
                  value={
                    form.expiryDate
                  }
                  onChange={(event) =>
                    updateForm(
                      "expiryDate",
                      event.target
                        .value,
                    )
                  }
                />
              </div>

              {/* Storage location */}
              <div className="blood-inventory-form-field">
                <label htmlFor="blood-inventory-form-storage">
                  Storage location{" "}
                  <span className="blood-inventory-form-optional">
                    (optional)
                  </span>
                </label>

                <div className="blood-inventory-form-input-wrap">
                  <Warehouse />

                  <input
                    id="blood-inventory-form-storage"
                    type="text"
                    maxLength={100}
                    placeholder="e.g. Fridge A, Shelf 2"
                    value={
                      form.storageLocation
                    }
                    onChange={(event) =>
                      updateForm(
                        "storageLocation",
                        event.target
                          .value,
                      )
                    }
                  />
                </div>
              </div>

              {/* Status */}
              <div className="blood-inventory-form-field">
                <label htmlFor="blood-inventory-form-status">
                  Status
                </label>

                <input
                  id="blood-inventory-form-status"
                  type="text"
                  maxLength={20}
                  list="blood-inventory-status-suggestions"
                  placeholder="Current stock state"
                  value={form.status}
                  onChange={(event) =>
                    updateForm(
                      "status",
                      event.target
                        .value,
                    )
                  }
                />

                <datalist id="blood-inventory-status-suggestions">
                  {availableStatuses.map(
                    (status) => (
                      <option
                        key={status}
                        value={status}
                      />
                    ),
                  )}
                </datalist>

                <span className="blood-inventory-form-hint">
                  Free text, up to 20
                  characters.
                  Suggestions come from
                  statuses already used in
                  your records.
                </span>
              </div>

              {formError && (
                <div
                  className="blood-inventory-modal__error"
                  role="alert"
                >
                  <AlertCircle />
                  {formError}
                </div>
              )}

              <div className="blood-inventory-modal__footer">
                <button
                  type="button"
                  className="blood-inventory-modal__cancel"
                  onClick={closeModal}
                  disabled={submitting}
                >
                  Cancel
                </button>

                <button
                  type="submit"
                  className="blood-inventory-modal__submit"
                  disabled={
                    submitting
                  }
                >
                  {submitting ? (
                    <>
                      <LoaderCircle className="blood-inventory-spin" />
                      Saving
                    </>
                  ) : (
                    <>
                      {modal.type ===
                      "add" ? (
                        <Plus />
                      ) : (
                        <Pencil />
                      )}

                      {modal.type ===
                      "add"
                        ? "Add record"
                        : "Save changes"}
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete confirmation modal */}
      {modal.type === "delete" && (
        <div
          className="blood-inventory-modal-overlay"
          onClick={closeModal}
          role="presentation"
        >
          <div
            className="blood-inventory-modal blood-inventory-modal--danger"
            role="dialog"
            aria-modal="true"
            aria-labelledby="blood-inventory-delete-title"
            onClick={(event) =>
              event.stopPropagation()
            }
          >
            <div className="blood-inventory-modal__header">
              <div>
                <p className="blood-inventory-modal__eyebrow">
                  CONFIRM DELETION
                </p>

                <h3
                  id="blood-inventory-delete-title"
                  className="blood-inventory-modal__title"
                >
                  Delete inventory
                  record?
                </h3>
              </div>

              <button
                type="button"
                className="blood-inventory-modal__close"
                onClick={closeModal}
                aria-label="Close dialog"
              >
                <X />
              </button>
            </div>

            <div className="blood-inventory-modal__body">
              <div className="blood-inventory-modal__warning">
                <AlertTriangle />
              </div>

              <p className="blood-inventory-modal__summary">
                <strong>
                  {modal.record
                    .blood_groups
                    ?.code ?? "—"}
                </strong>{" "}
                —{" "}
                {
                  modal.record
                    .available_units
                }{" "}
                available of{" "}
                {
                  modal.record
                    .total_units
                }{" "}
                total units at{" "}
                {modal.record
                  .organizations
                  ?.name ??
                  "an unknown organization"}
                .
              </p>

              {modal.record
                .reservation_count >
              0 ? (
                <p className="blood-inventory-modal__warning-text">
                  This inventory record
                  is linked to{" "}
                  <strong>
                    {
                      modal.record
                        .reservation_count
                    }{" "}
                    {
                      modal.record
                        .reservation_count ===
                      1
                        ? "blood reservation"
                        : "blood reservations"
                    }
                  </strong>
                  . It cannot be
                  deleted while those
                  reservations exist.
                </p>
              ) : (
                <p className="blood-inventory-modal__warning-text">
                  Blood inventory uses
                  physical deletion —
                  this record will be
                  removed permanently
                  and cannot be
                  recovered.
                </p>
              )}

              {actionError && (
                <div
                  className="blood-inventory-modal__error"
                  role="alert"
                >
                  <AlertCircle />
                  {actionError}
                </div>
              )}
            </div>

            <div className="blood-inventory-modal__footer">
              <button
                type="button"
                className="blood-inventory-modal__cancel"
                onClick={closeModal}
                disabled={
                  submitting
                }
              >
                Cancel
              </button>

              <button
                type="button"
                className="blood-inventory-modal__delete"
                onClick={() =>
                  void handleDelete()
                }
                disabled={
                  submitting ||
                  modal.record
                    .reservation_count >
                    0
                }
              >
                {submitting ? (
                  <>
                    <LoaderCircle className="blood-inventory-spin" />
                    Deleting
                  </>
                ) : modal.record
                    .reservation_count >
                  0 ? (
                  <>
                    <AlertTriangle />
                    Cannot delete
                  </>
                ) : (
                  <>
                    <Trash2 />
                    Delete record
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}