"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import {
  HeartHandshake,
  FileText,
  Clock,
  AlertTriangle,
  CheckCircle2,
  Search,
  X,
  Plus,
  Pencil,
  Trash2,
  AlertCircle,
  MapPin,
  LoaderCircle,
  Users,
} from "lucide-react";

import { createClient } from "@/lib/supabase/client";
import type {
  BloodGroup,
  BloodRequestsData,
  BloodRequestRecord,
  PatientRecord,
} from "@/lib/dashboard/get-blood-requests-data";
import type {
  CurrentUser,
  WebRole,
} from "@/lib/auth/get-current-user";

/* =========================================================
   DESIGN NOTES
   =========================================================
 * 1. `status` and `urgency` are free-text varchar(20) with no
 *    enum. Filter options and datalist suggestions are derived
 *    from values that actually exist in the data.
 * 2. blood_requests uses soft delete (deleted_at). Physical
 *    DELETE is blocked by RLS — there is no DELETE policy.
 * 3. id has NO default — must generate UUID client-side using
 *    crypto.randomUUID().
 * 4. requester_id MUST equal auth.uid() for INSERT — RLS
 *    enforces this.
 * 5. patient_id is required. The web form queries existing
 *    patients for selection. If no patients exist, the form
 *    explains that patients must be registered first.
 * ========================================================= */

/* =========================================================
   TYPES
   ========================================================= */
interface BloodRequestsClientProps {
  data: BloodRequestsData;
  currentUser: CurrentUser;
}

type ModalState =
  | { type: "closed" }
  | { type: "add" }
  | { type: "edit"; record: BloodRequestRecord }
  | { type: "delete"; record: BloodRequestRecord };

interface RequestFormState {
  organizationId: string;
  bloodGroupId: string;
  patientId: string;
  unitsRequired: string;
  urgency: string;
  status: string;
  requiredDate: string;
  notes: string;
}

/* =========================================================
   PERMISSIONS (mirror of the RLS policies)
   ========================================================= */
function canCreateRequest(): boolean {
  /*
   * INSERT policy: WITH CHECK requester_id = auth.uid().
   * All web roles can create as long as requester_id matches.
   */
  return true;
}

function canUpdateRequest(
  record: BloodRequestRecord,
  role: WebRole,
  userId: string,
  organizationId: string | null,
): boolean {
  /* UPDATE policy allows: requester, super_admin, government_admin, org members */
  if (record.requester_id === userId) return true;
  if (role === "SUPER_ADMIN") return true;
  if (role === "GOVERNMENT_ADMIN") return true;

  if (
    (role === "HOSPITAL_ADMIN" ||
      role === "BLOOD_BANK_ADMIN" ||
      role === "STAFF") &&
    organizationId !== null
  ) {
    return record.organization_id === organizationId;
  }

  return false;
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

function toISOLocalDateTime(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  const hours = String(date.getHours()).padStart(2, "0");
  const minutes = String(date.getMinutes()).padStart(2, "0");

  return `${year}-${month}-${day}T${hours}:${minutes}`;
}

function truncate(text: string, max: number): string {
  if (text.length <= max) return text;
  return text.slice(0, max) + "...";
}

/* =========================================================
   STATUS BADGE
   ========================================================= */
function getStatusBadgeModifier(status: string): string {
  const value = status.toLowerCase();

  if (
    value.includes("fulfill") ||
    value.includes("complete") ||
    value.includes("delivered") ||
    value.includes("closed")
  ) {
    return "--success";
  }

  if (
    value.includes("pending") ||
    value.includes("waiting") ||
    value.includes("requested")
  ) {
    return "--info";
  }

  if (
    value.includes("cancel") ||
    value.includes("reject") ||
    value.includes("expired")
  ) {
    return "--danger";
  }

  if (
    value.includes("progress") ||
    value.includes("processing") ||
    value.includes("allocated")
  ) {
    return "--warning";
  }

  return "";
}

function StatusBadge({ status }: { status: string }) {
  const modifier = getStatusBadgeModifier(status);

  return (
    <span
      className={`blood-requests-status-badge${
        modifier
          ? ` blood-requests-status-badge${modifier}`
          : ""
      }`}
    >
      {status}
    </span>
  );
}

/* =========================================================
   URGENCY BADGE
   ========================================================= */
function getUrgencyBadgeModifier(urgency: string): string {
  const value = urgency.toLowerCase();

  if (
    value.includes("urgent") ||
    value.includes("critical") ||
    value.includes("emergency")
  ) {
    return "--danger";
  }

  if (
    value.includes("high") ||
    value.includes("priority")
  ) {
    return "--warning";
  }

  if (
    value.includes("low") ||
    value.includes("routine") ||
    value.includes("normal")
  ) {
    return "--success";
  }

  return "--info";
}

function UrgencyBadge({ urgency }: { urgency: string }) {
  const modifier = getUrgencyBadgeModifier(urgency);

  return (
    <span
      className={`blood-requests-urgency-badge${
        modifier
          ? ` blood-requests-urgency-badge${modifier}`
          : ""
      }`}
    >
      {urgency}
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

  return "Something went wrong while saving. Please try again.";
}

/* ========================================================
   FORM STATE HELPERS
   ========================================================= */
function getAddFormInitial(
  defaultOrganizationId: string | null,
): RequestFormState {
  return {
    organizationId: defaultOrganizationId ?? "",
    bloodGroupId: "",
    patientId: "",
    unitsRequired: "",
    urgency: "",
    status: "Pending",
    requiredDate: toISOLocalDateTime(new Date()),
    notes: "",
  };
}

function getEditFormInitial(
  record: BloodRequestRecord,
): RequestFormState {
  return {
    organizationId: record.organization_id,
    bloodGroupId: record.blood_group_id,
    patientId: record.patient_id,
    unitsRequired: String(record.units_required),
    urgency: record.urgency,
    status: record.status,
    requiredDate: record.required_date.slice(0, 16),
    notes: record.notes ?? "",
  };
}

function validateForm(
  form: RequestFormState,
  requireOrganizationSelection: boolean,
  hasPatients: boolean,
): string | null {
  if (
    requireOrganizationSelection &&
    !form.organizationId
  ) {
    return "Please select the organization for this request.";
  }

  if (!form.organizationId) {
    return "No organization is associated with your account, so a request cannot be created.";
  }

  if (!form.bloodGroupId) {
    return "Please select a blood group.";
  }

  if (!hasPatients) {
    return "No patients are registered in the system. Patients must be registered before creating a blood request.";
  }

  if (!form.patientId) {
    return "Please select a patient.";
  }

  const units = Number(form.unitsRequired);

  if (
    form.unitsRequired.trim() === "" ||
    Number.isNaN(units) ||
    !Number.isInteger(units) ||
    units <= 0
  ) {
    return "Units required must be a whole number greater than 0.";
  }

  if (!form.urgency.trim()) {
    return "Please provide the urgency level.";
  }

  if (form.urgency.trim().length > 20) {
    return "Urgency must be 20 characters or fewer.";
  }

  if (!form.status.trim()) {
    return "Please provide a status.";
  }

  if (form.status.trim().length > 20) {
    return "Status must be 20 characters or fewer.";
  }

  if (!form.requiredDate) {
    return "Please provide the required date.";
  }

  if (form.notes.length > 1000) {
    return "Notes must be 1000 characters or fewer.";
  }

  return null;
}

/* =========================================================
   TABLE ROW (desktop)
   ========================================================= */

interface RecordActionProps {
  record: BloodRequestRecord;
  canUpdate: boolean;
  onEdit: () => void;
  onDelete: () => void;
}

function RequestTableRow({
  record,
  canUpdate,
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
        <div className="blood-requests-table__group">
          <strong>{group?.code ?? "—"}</strong>
          <span>{group?.name ?? "Unknown group"}</span>
        </div>
      </td>

      <td>
        <div className="blood-requests-table__org">
          <strong>
            {org?.name ?? "Unknown organization"}
          </strong>
          <span>
            {org ? formatType(org.organization_type) : "—"}
          </span>
        </div>
      </td>

      <td>
        <strong>{record.units_required}</strong>
      </td>

      <td>
        <UrgencyBadge urgency={record.urgency} />
      </td>

      <td>
        <StatusBadge status={record.status} />
      </td>

      <td>{formatDate(record.required_date)}</td>

      <td>
        <span className="blood-requests-table__notes">
          {record.notes ? truncate(record.notes, 40) : "—"}
        </span>
      </td>

      <td>
        <div className="blood-requests-table__location">
          <span>{city?.name ?? "—"}</span>
          <span>{province?.name ?? "—"}</span>
        </div>
      </td>

      <td>{formatDate(record.created_at)}</td>

      <td>
        {canUpdate && (
          <div className="blood-requests-table__actions">
            <button
              type="button"
              className="blood-requests-icon-button"
              onClick={onEdit}
              aria-label="Edit blood request"
              title="Edit"
            >
              <Pencil />
            </button>

            <button
              type="button"
              className="blood-requests-icon-button blood-requests-icon-button--danger"
              onClick={onDelete}
              aria-label="Delete blood request"
              title="Delete"
            >
              <Trash2 />
            </button>
          </div>
        )}
      </td>
    </tr>
  );
}

/* =========================================================
   CARD (mobile)
   ========================================================= */

function RequestCard({
  record,
  canUpdate,
  onEdit,
  onDelete,
}: RecordActionProps) {
  const group = record.blood_groups;
  const org = record.organizations;
  const city = org?.cities;
  const province = city?.provinces;

  return (
    <div className="blood-requests-card">
      <div className="blood-requests-card__top">
        <div className="blood-requests-card__group">
          <strong>{group?.code ?? "—"}</strong>
          <span>{group?.name ?? "Unknown group"}</span>
        </div>

        <div className="blood-requests-card__badges">
          <UrgencyBadge urgency={record.urgency} />
          <StatusBadge status={record.status} />
        </div>
      </div>

      <div className="blood-requests-card__org">
        {org?.name ?? "Unknown organization"}
      </div>

      <div className="blood-requests-card__location">
        <MapPin />
        {city?.name ?? "—"}, {province?.name ?? "—"}
      </div>

      <div className="blood-requests-card__grid">
        <div className="blood-requests-card__field">
          <span className="blood-requests-card__field-label">
            Units
          </span>
          <span className="blood-requests-card__field-value">
            {record.units_required}
          </span>
        </div>

        <div className="blood-requests-card__field">
          <span className="blood-requests-card__field-label">
            Required By
          </span>
          <span className="blood-requests-card__field-value">
            {formatDate(record.required_date)}
          </span>
        </div>

        <div className="blood-requests-card__field">
          <span className="blood-requests-card__field-label">
            Created
          </span>
          <span className="blood-requests-card__field-value">
            {formatDate(record.created_at)}
          </span>
        </div>

        <div className="blood-requests-card__field">
          <span className="blood-requests-card__field-label">
            Notes
          </span>
          <span className="blood-requests-card__field-value">
            {record.notes ? truncate(record.notes, 50) : "—"}
          </span>
        </div>
      </div>

      {canUpdate && (
        <div className="blood-requests-card__actions">
          <button
            type="button"
            className="blood-requests-card__action"
            onClick={onEdit}
          >
            <Pencil />
            Edit
          </button>

          <button
            type="button"
            className="blood-requests-card__action blood-requests-card__action--danger"
            onClick={onDelete}
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

export default function BloodRequestsClient({
  data,
  currentUser,
}: BloodRequestsClientProps) {
  const router = useRouter();

  const {
    records,
    bloodGroups,
    patients,
    summary,
    error,
  } = data;

  /* ------------------------------------------------
     Permissions
     ------------------------------------------------ */

  const isSuperAdmin = currentUser.role === "SUPER_ADMIN";
  const createEnabled = canCreateRequest();

  /* ------------------------------------------------
     Filters
     ------------------------------------------------ */

  const [groupFilter, setGroupFilter] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [urgencyFilter, setUrgencyFilter] = useState("");
  const [searchQuery, setSearchQuery] = useState("");

  const availableStatuses = useMemo(() => {
    const statuses = new Set<string>();

    for (const record of records) {
      statuses.add(record.status);
    }

    return Array.from(statuses).sort((a, b) =>
      a.toLowerCase().localeCompare(b.toLowerCase()),
    );
  }, [records]);

  const availableUrgencies = useMemo(() => {
    const urgencies = new Set<string>();

    for (const record of records) {
      urgencies.add(record.urgency);
    }

    return Array.from(urgencies).sort((a, b) =>
      a.toLowerCase().localeCompare(b.toLowerCase()),
    );
  }, [records]);

  const allGroups = useMemo(() => {
    const merged = new Map<string, BloodGroup>();

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

  const filteredRecords = useMemo(() => {
    const query = searchQuery.trim().toLowerCase();

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
        urgencyFilter &&
        record.urgency !== urgencyFilter
      ) {
        return false;
      }

      if (query) {
        const haystack = [
          record.organizations?.name ?? "",
          record.blood_groups?.code ?? "",
          record.blood_groups?.name ?? "",
          record.notes ?? "",
        ]
          .join(" ")
          .toLowerCase();

        if (!haystack.includes(query)) {
          return false;
        }
      }

      return true;
    });
  }, [records, groupFilter, statusFilter, urgencyFilter, searchQuery]);

  const hasActiveFilters =
    groupFilter !== "" ||
    statusFilter !== "" ||
    urgencyFilter !== "" ||
    searchQuery.trim() !== "";

  function clearFilters() {
    setGroupFilter("");
    setStatusFilter("");
    setUrgencyFilter("");
    setSearchQuery("");
  }

  /* ------------------------------------------------
     Organization options (SUPER_ADMIN add form)
     ------------------------------------------------ */

  const organizationOptions = useMemo(() => {
    if (data.availableOrganizations) {
      return data.availableOrganizations
        .map((org) => ({
          id: org.id,
          name: org.name,
          type: org.organization_type,
        }))
        .sort((a, b) => a.name.localeCompare(b.name));
    }

    const options = new Map<
      string,
      { id: string; name: string; type: string }
    >();

    for (const record of records) {
      const org = record.organizations;

      if (org && !options.has(org.id)) {
        options.set(org.id, {
          id: org.id,
          name: org.name,
          type: org.organization_type,
        });
      }
    }

    return Array.from(options.values()).sort((a, b) =>
      a.name.localeCompare(b.name),
    );
  }, [data.availableOrganizations, records]);

  /* ------------------------------------------------
     Patient options (for create/edit form)
     ------------------------------------------------ */

  const activePatients = useMemo(() => {
    return patients.filter((p) => !p.deleted_at);
  }, [patients]);

  function formatPatientLabel(patient: PatientRecord): string {
    const parts: string[] = [];

    if (patient.gender) {
      parts.push(patient.gender);
    }

    if (patient.date_of_birth) {
      parts.push(`DOB: ${formatDate(patient.date_of_birth)}`);
    }

    return parts.length > 0
      ? `ID: ${patient.id.slice(0, 8)}... (${parts.join(", ")})`
      : `ID: ${patient.id.slice(0, 8)}...`;
  }

  /* ------------------------------------------------
     Modal state
     ------------------------------------------------ */

  const [modal, setModal] = useState<ModalState>({
    type: "closed",
  });

  const [form, setForm] = useState<RequestFormState>(
    () => getAddFormInitial(currentUser.organizationId),
  );

  const [formError, setFormError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const isModalOpen = modal.type !== "closed";

  function openAddModal() {
    setForm(getAddFormInitial(currentUser.organizationId));
    setFormError(null);
    setActionError(null);
    setModal({ type: "add" });
  }

  function openEditModal(record: BloodRequestRecord) {
    setForm(getEditFormInitial(record));
    setFormError(null);
    setActionError(null);
    setModal({ type: "edit", record });
  }

  function openDeleteModal(record: BloodRequestRecord) {
    setFormError(null);
    setActionError(null);
    setModal({ type: "delete", record });
  }

  function closeModal() {
    if (submitting) return;

    setModal({ type: "closed" });
    setFormError(null);
    setActionError(null);
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
        setActionError(null);
      }
    }

    window.addEventListener("keydown", handleKeyDown);

    return () =>
      window.removeEventListener("keydown", handleKeyDown);
  }, [isModalOpen, submitting]);

  function updateForm(
    field: keyof RequestFormState,
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
      isSuperAdmin && modal.type === "add";

    const validationError = validateForm(
      form,
      requireOrgSelection,
      activePatients.length > 0,
    );

    if (validationError) {
      setFormError(validationError);
      return;
    }

    setFormError(null);
    setSubmitting(true);

    try {
      const supabase = createClient();

      let mutationError: {
        code?: string;
        message?: string;
      } | null = null;

      if (modal.type === "add") {
        const insertPayload = {
          id: crypto.randomUUID(),
          requester_id: currentUser.id,
          organization_id: form.organizationId,
          blood_group_id: form.bloodGroupId,
          patient_id: form.patientId,
          units_required: Number(form.unitsRequired),
          urgency: form.urgency.trim(),
          status: form.status.trim(),
          required_date: form.requiredDate,
          notes: form.notes.trim() || null,
        };

        const { error: insertError } = await supabase
          .from("blood_requests")
          .insert(insertPayload);

        mutationError = insertError;
      } else if (modal.type === "edit") {
        const updatePayload = {
          organization_id: form.organizationId,
          blood_group_id: form.bloodGroupId,
          patient_id: form.patientId,
          units_required: Number(form.unitsRequired),
          urgency: form.urgency.trim(),
          status: form.status.trim(),
          required_date: form.requiredDate,
          notes: form.notes.trim() || null,
          updated_at: new Date().toISOString(),
        };

        const { error: updateError } = await supabase
          .from("blood_requests")
          .update(updatePayload)
          .eq("id", modal.record.id);

        mutationError = updateError;
      }

      if (mutationError) {
        console.error(
          modal.type === "add"
            ? "BLOOD REQUESTS - INSERT ERROR"
            : "BLOOD REQUESTS - UPDATE ERROR",
          mutationError,
        );

        setFormError(friendlyMutationError(mutationError));
        return;
      }

      setModal({ type: "closed" });
      setFormError(null);
      setActionError(null);

      router.refresh();
    } catch (saveException) {
      console.error(
        "BLOOD REQUESTS - SAVE EXCEPTION",
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
     Soft delete (UPDATE deleted_at)
     ------------------------------------------------ */

  async function handleDelete(): Promise<void> {
    if (modal.type !== "delete") return;

    setActionError(null);
    setSubmitting(true);

    try {
      const supabase = createClient();

      const { error: deleteError } = await supabase
        .from("blood_requests")
        .update({
          deleted_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("id", modal.record.id);

      if (deleteError) {
        console.error(
          "BLOOD REQUESTS - SOFT DELETE ERROR",
          deleteError,
        );

        setActionError(friendlyMutationError(deleteError));
        return;
      }

      setModal({ type: "closed" });
      setFormError(null);
      setActionError(null);

      router.refresh();
    } catch (deleteException) {
      console.error(
        "BLOOD REQUESTS - DELETE EXCEPTION",
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
      <div className="blood-requests-page">
        <header className="blood-requests-header blood-requests-fade-in blood-requests-fade-in--1">
          <div className="blood-requests-header__content">
            <div className="blood-requests-header__icon">
              <HeartHandshake />
            </div>

            <div className="blood-requests-header__titles">
              <p className="blood-requests-header__eyebrow">
                BLOOD REQUEST MANAGEMENT
              </p>

              <h1 className="blood-requests-header__title">
                Blood Requests
              </h1>

              <p className="blood-requests-header__description">
                Track and manage blood requests across
                the LifeLynk healthcare network.
              </p>
            </div>
          </div>
        </header>

        <div className="blood-requests-error blood-requests-fade-in blood-requests-fade-in--2">
          <div className="blood-requests-error__icon">
            <AlertTriangle />
          </div>

          <strong>
            Unable to load blood request data
          </strong>

          <p>Please try again later.</p>
        </div>
      </div>
    );
  }

  /* ------------------------------------------------
     Render
     ------------------------------------------------ */

  return (
    <div className="blood-requests-page">
      {/* Header */}
      <header className="blood-requests-header blood-requests-fade-in blood-requests-fade-in--1">
        <div className="blood-requests-header__content">
          <div className="blood-requests-header__icon">
            <HeartHandshake />
          </div>

          <div className="blood-requests-header__titles">
            <p className="blood-requests-header__eyebrow">
              BLOOD REQUEST MANAGEMENT
            </p>

            <h1 className="blood-requests-header__title">
              Blood Requests
            </h1>

            <p className="blood-requests-header__description">
              Track and manage blood requests across
              the LifeLynk healthcare network.
            </p>
          </div>
        </div>

        {createEnabled && (
          <button
            type="button"
            className="blood-requests-add-button"
            onClick={openAddModal}
          >
            <Plus />
            New Request
          </button>
        )}
      </header>

      {/* Summary stats */}
      <section className="blood-requests-stats blood-requests-fade-in blood-requests-fade-in--2">
        <article className="blood-requests-stat">
          <span className="blood-requests-stat__icon">
            <FileText />
          </span>

          <div className="blood-requests-stat__content">
            <p>Total Requests</p>
            <strong>{summary.totalRequests}</strong>
          </div>

          <span className="blood-requests-stat__label">
            Total
          </span>
        </article>

        <article className="blood-requests-stat">
          <span className="blood-requests-stat__icon">
            <Clock />
          </span>

          <div className="blood-requests-stat__content">
            <p>Pending</p>
            <strong>{summary.pendingCount}</strong>
          </div>

          <span className="blood-requests-stat__label">
            Awaiting
          </span>
        </article>

        <article className="blood-requests-stat">
          <span className="blood-requests-stat__icon">
            <AlertTriangle />
          </span>

          <div className="blood-requests-stat__content">
            <p>Urgent</p>
            <strong>{summary.urgentCount}</strong>
          </div>

          <span className="blood-requests-stat__label">
            Critical
          </span>
        </article>

        <article className="blood-requests-stat">
          <span className="blood-requests-stat__icon">
            <CheckCircle2 />
          </span>

          <div className="blood-requests-stat__content">
            <p>Fulfilled</p>
            <strong>{summary.fulfilledCount}</strong>
          </div>

          <span className="blood-requests-stat__label">
            Done
          </span>
        </article>
      </section>

      {/* Records section */}
      {records.length > 0 && (
        <section className="blood-requests-records blood-requests-fade-in blood-requests-fade-in--3">
          <div className="blood-requests-records__header">
            <div>
              <p>REQUEST RECORDS</p>
              <h3>Blood requests log</h3>
            </div>

            <span className="blood-requests-records__count">
              {hasActiveFilters
                ? `${filteredRecords.length} of ${records.length}`
                : records.length}{" "}
              {records.length === 1 ? "request" : "requests"}
            </span>
          </div>

          {/* Filters */}
          <div className="blood-requests-filters">
            <div className="blood-requests-filters__field">
              <label htmlFor="blood-requests-group-filter">
                Blood group
              </label>

              <select
                id="blood-requests-group-filter"
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

            <div className="blood-requests-filters__field">
              <label htmlFor="blood-requests-status-filter">
                Status
              </label>

              <select
                id="blood-requests-status-filter"
                value={statusFilter}
                onChange={(event) =>
                  setStatusFilter(event.target.value)
                }
              >
                <option value="">All statuses</option>

                {availableStatuses.map((status) => (
                  <option key={status} value={status}>
                    {status}
                  </option>
                ))}
              </select>
            </div>

            <div className="blood-requests-filters__field">
              <label htmlFor="blood-requests-urgency-filter">
                Urgency
              </label>

              <select
                id="blood-requests-urgency-filter"
                value={urgencyFilter}
                onChange={(event) =>
                  setUrgencyFilter(event.target.value)
                }
              >
                <option value="">All urgencies</option>

                {availableUrgencies.map((urgency) => (
                  <option key={urgency} value={urgency}>
                    {urgency}
                  </option>
                ))}
              </select>
            </div>

            <div className="blood-requests-filters__field blood-requests-filters__field--search">
              <label htmlFor="blood-requests-search">
                Search
              </label>

              <div className="blood-requests-filters__search-wrap">
                <Search />

                <input
                  id="blood-requests-search"
                  type="text"
                  value={searchQuery}
                  placeholder="Organization, blood group, or notes"
                  onChange={(event) =>
                    setSearchQuery(event.target.value)
                  }
                />
              </div>
            </div>

            <button
              type="button"
              className="blood-requests-filters__clear"
              onClick={clearFilters}
              disabled={!hasActiveFilters}
            >
              <X />
              Clear filters
            </button>
          </div>

          {/* Desktop table */}
          <div className="blood-requests-table-wrap">
            <table className="blood-requests-table">
              <thead>
                <tr>
                  <th>Blood Group</th>
                  <th>Organization</th>
                  <th>Units</th>
                  <th>Urgency</th>
                  <th>Status</th>
                  <th>Required Date</th>
                  <th>Notes</th>
                  <th>Location</th>
                  <th>Created</th>
                  <th>Actions</th>
                </tr>
              </thead>

              <tbody>
                {filteredRecords.map((record) => (
                  <RequestTableRow
                    key={record.id}
                    record={record}
                    canUpdate={canUpdateRequest(
                      record,
                      currentUser.role,
                      currentUser.id,
                      currentUser.organizationId,
                    )}
                    onEdit={() => openEditModal(record)}
                    onDelete={() => openDeleteModal(record)}
                  />
                ))}
              </tbody>
            </table>
          </div>

          {/* Mobile cards */}
          <div className="blood-requests-cards">
            {filteredRecords.map((record) => (
              <RequestCard
                key={record.id}
                record={record}
                canUpdate={canUpdateRequest(
                  record,
                  currentUser.role,
                  currentUser.id,
                  currentUser.organizationId,
                )}
                onEdit={() => openEditModal(record)}
                onDelete={() => openDeleteModal(record)}
              />
            ))}
          </div>

          {/* No filter matches */}
          {filteredRecords.length === 0 && (
            <div className="blood-requests-filtered-empty">
              <div className="blood-requests-filtered-empty__icon">
                <Search />
              </div>

              <strong>
                No requests match your filters
              </strong>

              <p>
                Try adjusting the blood group, status,
                urgency, or search query.
              </p>

              <button
                type="button"
                className="blood-requests-filtered-empty__clear"
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
        <section className="blood-requests-records blood-requests-fade-in blood-requests-fade-in--3">
          <div className="blood-requests-empty">
            <div className="blood-requests-empty__icon">
              <HeartHandshake />
            </div>

            <strong>No blood requests found</strong>

            <p>
              Requests will appear here once they are
              submitted through the LifeLynk network.
            </p>
          </div>
        </section>
      )}

      {/* Add / Edit modal */}
      {(modal.type === "add" || modal.type === "edit") && (
        <div
          className="blood-requests-modal-overlay"
          onClick={closeModal}
          role="presentation"
        >
          <div
            className="blood-requests-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="blood-requests-modal-title"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="blood-requests-modal__header">
              <div>
                <p className="blood-requests-modal__eyebrow">
                  {modal.type === "add"
                    ? "NEW REQUEST"
                    : "EDIT REQUEST"}
                </p>

                <h3
                  id="blood-requests-modal-title"
                  className="blood-requests-modal__title"
                >
                  {modal.type === "add"
                    ? "Create blood request"
                    : "Edit blood request"}
                </h3>
              </div>

              <button
                type="button"
                className="blood-requests-modal__close"
                onClick={closeModal}
                aria-label="Close dialog"
              >
                <X />
              </button>
            </div>

            <form
              className="blood-requests-modal__form"
              onSubmit={(event) => {
                event.preventDefault();
                void handleSave();
              }}
            >
              {/* Organization */}
              <div className="blood-requests-form-field blood-requests-form-field--full">
                <label htmlFor="blood-requests-form-org">
                  Organization
                </label>

                {isSuperAdmin && modal.type === "add" ? (
                  <select
                    id="blood-requests-form-org"
                    value={form.organizationId}
                    onChange={(event) =>
                      updateForm(
                        "organizationId",
                        event.target.value,
                      )
                    }
                  >
                    <option value="">
                      Select an organization
                    </option>

                    {organizationOptions.map((org) => (
                      <option
                        key={org.id}
                        value={org.id}
                      >
                        {org.name} ({formatType(org.type)})
                      </option>
                    ))}
                  </select>
                ) : (
                  <p className="blood-requests-form-static">
                    {modal.type === "edit"
                      ? modal.record.organizations?.name ??
                        "Unknown organization"
                      : currentUser.organizationName ??
                        "Your organization"}
                  </p>
                )}

                {isSuperAdmin &&
                  modal.type === "add" &&
                  organizationOptions.length === 0 && (
                    <span className="blood-requests-form-hint">
                      No verified organizations are
                      available yet.
                    </span>
                  )}
              </div>

              {/* Blood group */}
              <div className="blood-requests-form-field">
                <label htmlFor="blood-requests-form-group">
                  Blood group
                </label>

                <select
                  id="blood-requests-form-group"
                  value={form.bloodGroupId}
                  onChange={(event) =>
                    updateForm(
                      "bloodGroupId",
                      event.target.value,
                    )
                  }
                >
                  <option value="">
                    Select a blood group
                  </option>

                  {allGroups.map((group) => (
                    <option
                      key={group.id}
                      value={group.id}
                    >
                      {group.code} — {group.name}
                    </option>
                  ))}
                </select>
              </div>

              {/* Patient */}
              <div className="blood-requests-form-field">
                <label htmlFor="blood-requests-form-patient">
                  Patient
                </label>

                {activePatients.length > 0 ? (
                  <select
                    id="blood-requests-form-patient"
                    value={form.patientId}
                    onChange={(event) =>
                      updateForm(
                        "patientId",
                        event.target.value,
                      )
                    }
                  >
                    <option value="">
                      Select a patient
                    </option>

                    {activePatients.map((patient) => (
                      <option
                        key={patient.id}
                        value={patient.id}
                      >
                        {formatPatientLabel(patient)}
                      </option>
                    ))}
                  </select>
                ) : (
                  <div className="blood-requests-form-no-patients">
                    <Users />
                    <span>
                      No patients registered. Patients must
                      be registered in the system before
                      creating a blood request.
                    </span>
                  </div>
                )}
              </div>

              {/* Units required */}
              <div className="blood-requests-form-field">
                <label htmlFor="blood-requests-form-units">
                  Units required
                </label>

                <input
                  id="blood-requests-form-units"
                  type="number"
                  min={1}
                  step={1}
                  value={form.unitsRequired}
                  onChange={(event) =>
                    updateForm(
                      "unitsRequired",
                      event.target.value,
                    )
                  }
                />
              </div>

              {/* Required date */}
              <div className="blood-requests-form-field">
                <label htmlFor="blood-requests-form-date">
                  Required date
                </label>

                <input
                  id="blood-requests-form-date"
                  type="datetime-local"
                  value={form.requiredDate}
                  onChange={(event) =>
                    updateForm(
                      "requiredDate",
                      event.target.value,
                    )
                  }
                />
              </div>

              {/* Urgency (free text, varchar(20)) */}
              <div className="blood-requests-form-field">
                <label htmlFor="blood-requests-form-urgency">
                  Urgency
                </label>

                <input
                  id="blood-requests-form-urgency"
                  type="text"
                  maxLength={20}
                  list="blood-requests-urgency-suggestions"
                  placeholder="e.g. Urgent, Routine, Critical"
                  value={form.urgency}
                  onChange={(event) =>
                    updateForm(
                      "urgency",
                      event.target.value,
                    )
                  }
                />

                <datalist id="blood-requests-urgency-suggestions">
                  {availableUrgencies.map((urgency) => (
                    <option
                      key={urgency}
                      value={urgency}
                    />
                  ))}
                </datalist>

                <span className="blood-requests-form-hint">
                  Free text, up to 20 characters.
                </span>
              </div>

              {/* Status (free text, varchar(20)) */}
              <div className="blood-requests-form-field">
                <label htmlFor="blood-requests-form-status">
                  Status
                </label>

                <input
                  id="blood-requests-form-status"
                  type="text"
                  maxLength={20}
                  list="blood-requests-status-suggestions"
                  placeholder="e.g. Pending, Fulfilled"
                  value={form.status}
                  onChange={(event) =>
                    updateForm(
                      "status",
                      event.target.value,
                    )
                  }
                />

                <datalist id="blood-requests-status-suggestions">
                  {availableStatuses.map((status) => (
                    <option
                      key={status}
                      value={status}
                    />
                  ))}
                </datalist>

                <span className="blood-requests-form-hint">
                  Free text, up to 20 characters.
                </span>
              </div>

              {/* Notes (optional) */}
              <div className="blood-requests-form-field blood-requests-form-field--full">
                <label htmlFor="blood-requests-form-notes">
                  Notes{" "}
                  <span className="blood-requests-form-optional">
                    (optional)
                  </span>
                </label>

                <textarea
                  id="blood-requests-form-notes"
                  rows={3}
                  maxLength={1000}
                  placeholder="Additional details about this request"
                  value={form.notes}
                  onChange={(event) =>
                    updateForm("notes", event.target.value)
                  }
                />

              </div>

              {formError && (
                <div
                  className="blood-requests-modal__error"
                  role="alert"
                >
                  <AlertCircle />
                  {formError}
                </div>
              )}

              <div className="blood-requests-modal__footer">
                <button
                  type="button"
                  className="blood-requests-modal__cancel"
                  onClick={closeModal}
                  disabled={submitting}
                >
                  Cancel
                </button>

                <button
                  type="submit"
                  className="blood-requests-modal__submit"
                  disabled={submitting}
                >
                  {submitting ? (
                    <>
                      <LoaderCircle className="blood-requests-spin" />
                      Saving
                    </>
                  ) : (
                    <>
                      {modal.type === "add" ? (
                        <Plus />
                      ) : (
                        <Pencil />
                      )}
                      {modal.type === "add"
                        ? "Create request"
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
          className="blood-requests-modal-overlay"
          onClick={closeModal}
          role="presentation"
        >
          <div
            className="blood-requests-modal blood-requests-modal--danger"
            role="dialog"
            aria-modal="true"
            aria-labelledby="blood-requests-delete-title"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="blood-requests-modal__header">
              <div>
                <p className="blood-requests-modal__eyebrow">
                  CONFIRM DELETION
                </p>

                <h3
                  id="blood-requests-delete-title"
                  className="blood-requests-modal__title"
                >
                  Delete blood request?
                </h3>
              </div>

              <button
                type="button"
                className="blood-requests-modal__close"
                onClick={closeModal}
                aria-label="Close dialog"
              >
                <X />
              </button>
            </div>

            <div className="blood-requests-modal__body">
              <div className="blood-requests-modal__warning">
                <AlertTriangle />
              </div>

              <p className="blood-requests-modal__summary">
                <strong>
                  {modal.record.blood_groups?.code ?? "—"}
                </strong>{" "}
                — {modal.record.units_required} units
                requested from{" "}
                {modal.record.organizations?.name ??
                  "an unknown organization"}{" "}
                with status{" "}
                <strong>{modal.record.status}</strong>.
              </p>

              <p className="blood-requests-modal__warning-text">
                This request will be soft-deleted and
                removed from the active list. This action
                can be reversed by an administrator.
              </p>

              {actionError && (
                <div
                  className="blood-requests-modal__error"
                  role="alert"
                >
                  <AlertCircle />
                  {actionError}
                </div>
              )}
            </div>

            <div className="blood-requests-modal__footer">
              <button
                type="button"
                className="blood-requests-modal__cancel"
                onClick={closeModal}
                disabled={submitting}
              >
                Cancel
              </button>

              <button
                type="button"
                className="blood-requests-modal__delete"
                onClick={() => void handleDelete()}
                disabled={submitting}
              >
                {submitting ? (
                  <>
                    <LoaderCircle className="blood-requests-spin" />
                    Deleting
                  </>
                ) : (
                  <>
                    <Trash2 />
                    Delete request
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