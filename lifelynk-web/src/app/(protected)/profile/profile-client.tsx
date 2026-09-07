"use client";

import {
  useState,
  type ReactNode,
} from "react";

import {
  Building2,
  CheckCircle2,
  Clock3,
  ShieldCheck,
  Mail,
  Phone,
  MapPin,
  FileText,
  BedDouble,
  HeartPulse,
  Droplets,
  Snowflake,
  FlaskConical,
  CalendarDays,
  UserRound,
  AlertTriangle,
  Trash2,
  Pencil,
  Save,
  X,
  Loader2,
  CheckCircle,
} from "lucide-react";

import type { ProfileData } from "@/lib/dashboard/get-profile-data";

import {
  deleteMyAccount,
  updateMyProfile,
} from "@/lib/dashboard/profile-actions";

import "./profile.css";

interface ProfileClientProps {
  profile: ProfileData;
}

/* =========================================================
   HELPERS
   ========================================================= */

function formatRole(role: string): string {
  return role
    .replaceAll("_", " ")
    .toLowerCase()
    .replace(/\b\w/g, (letter) =>
      letter.toUpperCase(),
    );
}

function formatOrganizationType(
  type: string,
): string {
  return type === "BLOOD_BANK"
    ? "Blood Bank"
    : "Hospital";
}

function formatDate(
  value: string | null,
): string {
  if (!value) {
    return "Not available";
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return "Not available";
  }

  return new Intl.DateTimeFormat("en-PK", {
    dateStyle: "medium",
  }).format(date);
}

/* =========================================================
   VERIFICATION BADGE
   ========================================================= */

function VerificationBadge({
  status,
}: {
  status: string;
}) {
  const normalized = status.toUpperCase();

  if (normalized === "VERIFIED") {
    return (
      <span className="profile-status profile-status--verified">
        <CheckCircle2 size={15} />
        Verified
      </span>
    );
  }

  if (normalized === "REJECTED") {
    return (
      <span className="profile-status profile-status--rejected">
        <AlertTriangle size={15} />
        Rejected
      </span>
    );
  }

  return (
    <span className="profile-status profile-status--pending">
      <Clock3 size={15} />
      Pending
    </span>
  );
}

/* =========================================================
   READ-ONLY INFO ITEM
   ========================================================= */

function InfoItem({
  icon,
  label,
  value,
}: {
  icon: ReactNode;
  label: string;
  value: string;
}) {
  return (
    <div className="profile-info-item">
      <span className="profile-info-item__icon">
        {icon}
      </span>

      <div>
        <span className="profile-info-item__label">
          {label}
        </span>

        <strong className="profile-info-item__value">
          {value || "Not provided"}
        </strong>
      </div>
    </div>
  );
}

/* =========================================================
   EDIT FIELD
   ========================================================= */

function EditField({
  icon,
  label,
  value,
  onChange,
  type = "text",
  placeholder,
  disabled = false,
}: {
  icon: ReactNode;
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: string;
  placeholder?: string;
  disabled?: boolean;
}) {
  return (
    <label className="profile-edit-field">
      <span className="profile-edit-field__label">
        {label}
      </span>

      <div className="profile-edit-field__control">
        <span className="profile-edit-field__icon">
          {icon}
        </span>

        <input
          type={type}
          value={value}
          onChange={(event) =>
            onChange(event.target.value)
          }
          placeholder={placeholder}
          disabled={disabled}
        />
      </div>
    </label>
  );
}

/* =========================================================
   BOOLEAN DISPLAY
   ========================================================= */

function BooleanValue({
  value,
}: {
  value: boolean;
}) {
  return (
    <span
      className={
        value
          ? "profile-boolean profile-boolean--yes"
          : "profile-boolean profile-boolean--no"
      }
    >
      {value ? "Available" : "Not available"}
    </span>
  );
}

/* =========================================================
   EDIT TOGGLE
   ========================================================= */

function EditToggle({
  label,
  value,
  onChange,
}: {
  label: string;
  value: boolean;
  onChange: (value: boolean) => void;
}) {
  return (
    <div className="profile-toggle-field">
      <span className="profile-edit-field__label">
        {label}
      </span>

      <button
        type="button"
        role="switch"
        aria-checked={value}
        aria-label={`${label}: ${
          value ? "Available" : "Not available"
        }`}
        className={
          value
            ? "profile-toggle profile-toggle--active"
            : "profile-toggle"
        }
        onClick={() => onChange(!value)}
      >
        <span className="profile-toggle__track">
          <span className="profile-toggle__thumb" />
        </span>

        <strong>
          {value ? "Available" : "Not available"}
        </strong>
      </button>
    </div>
  );
}

/* =========================================================
   MAIN COMPONENT
   ========================================================= */

export default function ProfileClient({
  profile,
}: ProfileClientProps) {
  const organization = profile.organization;

  const organizationType =
    organization?.organizationType ?? null;

  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);

  const [saveError, setSaveError] =
    useState("");

  const [saveSuccess, setSaveSuccess] =
    useState("");

  /* =======================================================
     PERSONAL
     ======================================================= */

  const [fullName, setFullName] = useState(
    profile.user.fullName,
  );

  const [email, setEmail] = useState(
    profile.user.email,
  );

  /* =======================================================
     ORGANIZATION
     ======================================================= */

  const [organizationName, setOrganizationName] =
    useState(organization?.name ?? "");

  const [organizationPhone, setOrganizationPhone] =
    useState(organization?.phone ?? "");

  const [organizationEmail, setOrganizationEmail] =
    useState(organization?.email ?? "");

  const [organizationAddress, setOrganizationAddress] =
    useState(organization?.address ?? "");

  /* =======================================================
     HOSPITAL
     ======================================================= */

  const [hospitalType, setHospitalType] =
    useState(
      profile.hospital?.hospitalType ?? "",
    );

  const [hospitalLicenseNumber, setHospitalLicenseNumber] =
    useState(
      profile.hospital?.licenseNumber ?? "",
    );

  const [emergencyService, setEmergencyService] =
    useState(
      profile.hospital?.emergencyService ?? false,
    );

  const [bloodStorageAvailable, setBloodStorageAvailable] =
    useState(
      profile.hospital?.bloodStorageAvailable ??
        false,
    );

  const [totalBeds, setTotalBeds] = useState(
    profile.hospital?.totalBeds != null
      ? String(profile.hospital.totalBeds)
      : "",
  );

  const [icuAvailable, setIcuAvailable] =
    useState(
      profile.hospital?.icuAvailable ?? false,
    );

  /* =======================================================
     BLOOD BANK
     ======================================================= */

  const [bloodBankLicenseNumber, setBloodBankLicenseNumber] =
    useState(
      profile.bloodBank?.licenseNumber ?? "",
    );

  const [storageCapacity, setStorageCapacity] =
    useState(
      profile.bloodBank?.storageCapacity != null
        ? String(profile.bloodBank.storageCapacity)
        : "",
    );

  const [coldStorageAvailable, setColdStorageAvailable] =
    useState(
      profile.bloodBank?.coldStorageAvailable ??
        false,
    );

  const [bloodProcessingAvailable, setBloodProcessingAvailable] =
    useState(
      profile.bloodBank
        ?.bloodProcessingAvailable ?? false,
    );

  const [operatingHours, setOperatingHours] =
    useState(
      profile.bloodBank?.operatingHours ?? "",
    );

  /* =======================================================
     DELETE
     ======================================================= */

  const [deleteOpen, setDeleteOpen] =
    useState(false);

  const [deleteLoading, setDeleteLoading] =
    useState(false);

  const [error, setError] = useState("");

  /* =======================================================
     RESET FORM
     ======================================================= */

  function resetForm() {
    setFullName(profile.user.fullName);
    setEmail(profile.user.email);

    setOrganizationName(
      profile.organization?.name ?? "",
    );

    setOrganizationPhone(
      profile.organization?.phone ?? "",
    );

    setOrganizationEmail(
      profile.organization?.email ?? "",
    );

    setOrganizationAddress(
      profile.organization?.address ?? "",
    );

    setHospitalType(
      profile.hospital?.hospitalType ?? "",
    );

    setHospitalLicenseNumber(
      profile.hospital?.licenseNumber ?? "",
    );

    setEmergencyService(
      profile.hospital?.emergencyService ?? false,
    );

    setBloodStorageAvailable(
      profile.hospital?.bloodStorageAvailable ??
        false,
    );

    setTotalBeds(
      profile.hospital?.totalBeds != null
        ? String(profile.hospital.totalBeds)
        : "",
    );

    setIcuAvailable(
      profile.hospital?.icuAvailable ?? false,
    );

    setBloodBankLicenseNumber(
      profile.bloodBank?.licenseNumber ?? "",
    );

    setStorageCapacity(
      profile.bloodBank?.storageCapacity != null
        ? String(profile.bloodBank.storageCapacity)
        : "",
    );

    setColdStorageAvailable(
      profile.bloodBank?.coldStorageAvailable ??
        false,
    );

    setBloodProcessingAvailable(
      profile.bloodBank
        ?.bloodProcessingAvailable ?? false,
    );

    setOperatingHours(
      profile.bloodBank?.operatingHours ?? "",
    );
  }

  /* =======================================================
     START EDIT
     ======================================================= */

  function handleStartEditing() {
    setSaveError("");
    setSaveSuccess("");
    setError("");
    setEditing(true);
  }

  /* =======================================================
     CANCEL EDIT
     ======================================================= */

  function handleCancelEditing() {
    resetForm();

    setSaveError("");
    setEditing(false);
  }

  /* =======================================================
     SAVE
     ======================================================= */

  async function handleSaveProfile() {
    setSaveError("");
    setSaveSuccess("");

    if (!fullName.trim()) {
      setSaveError("Full name is required.");
      return;
    }

    if (!email.trim()) {
      setSaveError(
        "Email address is required.",
      );
      return;
    }

    const emailPattern =
      /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (!emailPattern.test(email.trim())) {
      setSaveError(
        "Please enter a valid email address.",
      );
      return;
    }

    if (
      organization &&
      !organizationName.trim()
    ) {
      setSaveError(
        "Organization name is required.",
      );
      return;
    }

    let parsedTotalBeds:
      | number
      | null = null;

    if (totalBeds.trim()) {
      parsedTotalBeds = Number(totalBeds);

      if (
        !Number.isInteger(parsedTotalBeds) ||
        parsedTotalBeds < 0
      ) {
        setSaveError(
          "Total beds must be a valid non-negative whole number.",
        );
        return;
      }
    }

    let parsedStorageCapacity:
      | number
      | null = null;

    if (storageCapacity.trim()) {
      parsedStorageCapacity =
        Number(storageCapacity);

      if (
        Number.isNaN(parsedStorageCapacity) ||
        parsedStorageCapacity < 0
      ) {
        setSaveError(
          "Storage capacity must be a valid non-negative number.",
        );
        return;
      }
    }

    setSaving(true);

    try {
      const result = await updateMyProfile({
        fullName: fullName.trim(),
        email: email.trim(),

        organization: organization
          ? {
              name: organizationName.trim(),
              phone:
                organizationPhone.trim() ||
                null,
              email:
                organizationEmail.trim() ||
                null,
              address:
                organizationAddress.trim() ||
                null,
            }
          : null,

        hospital:
          organizationType === "HOSPITAL"
            ? {
                hospitalType:
                  hospitalType.trim() || null,

                licenseNumber:
                  hospitalLicenseNumber.trim() ||
                  null,

                emergencyService,
                bloodStorageAvailable,
                totalBeds: parsedTotalBeds,
                icuAvailable,
              }
            : null,

        bloodBank:
          organizationType === "BLOOD_BANK"
            ? {
                licenseNumber:
                  bloodBankLicenseNumber.trim() ||
                  null,

                storageCapacity:
                  parsedStorageCapacity,

                coldStorageAvailable,
                bloodProcessingAvailable,

                operatingHours:
                  operatingHours.trim() || null,
              }
            : null,
      });

      if (!result.success) {
        setSaveError(
          result.error ??
            "Unable to update your profile.",
        );

        return;
      }

      setSaveSuccess(
        "Profile updated successfully.",
      );

      setEditing(false);
    } catch (saveException) {
      console.error(
        "PROFILE UPDATE ERROR",
        saveException,
      );

      setSaveError(
        "Something went wrong while updating your profile.",
      );
    } finally {
      setSaving(false);
    }
  }

  /* =======================================================
     DELETE ACCOUNT
     ======================================================= */

  async function handleDeleteAccount() {
    setDeleteLoading(true);
    setError("");

    try {
      const result =
        await deleteMyAccount();

      if (!result.success) {
        setError(
          result.error ??
            "Unable to delete your account.",
        );

        return;
      }

      window.location.replace("/login");
    } catch {
      setError(
        "Something went wrong while deleting your account.",
      );
    } finally {
      setDeleteLoading(false);
    }
  }

  /* =======================================================
     INITIALS
     ======================================================= */

  const initials =
    profile.user.fullName
      .trim()
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) =>
        part.charAt(0).toUpperCase(),
      )
      .join("") || "U";

  /* =======================================================
     RENDER
     ======================================================= */

  return (
    <div className="profile-page">
      {/* =================================================
          HEADER
          ================================================= */}

      <header className="profile-header">
        <div className="profile-header__icon">
          <UserRound />
        </div>

        <div className="profile-header__content">
          <p className="profile-eyebrow">
            ACCOUNT PROFILE
          </p>

          <h1>My Profile</h1>

          <p>
            View and manage your LifeLynk
            account and organization
            information.
          </p>
        </div>

        <div className="profile-header__actions">
          {!editing ? (
            <button
              type="button"
              className="profile-edit-button"
              onClick={handleStartEditing}
            >
              <Pencil size={17} />
              Edit Profile
            </button>
          ) : (
            <>
              <button
                type="button"
                className="profile-cancel-button"
                onClick={handleCancelEditing}
                disabled={saving}
              >
                <X size={17} />
                Cancel
              </button>

              <button
                type="button"
                className="profile-save-button"
                onClick={handleSaveProfile}
                disabled={saving}
              >
                {saving ? (
                  <>
                    <Loader2
                      size={17}
                      className="profile-button-spinner"
                    />
                    Saving...
                  </>
                ) : (
                  <>
                    <Save size={17} />
                    Save Changes
                  </>
                )}
              </button>
            </>
          )}
        </div>
      </header>

      {/* =================================================
          FEEDBACK
          ================================================= */}

      {saveSuccess && (
        <div className="profile-success" role="status">
          <CheckCircle size={18} />
          <span>{saveSuccess}</span>
        </div>
      )}

      {saveError && (
        <div
          className="profile-error"
          role="alert"
        >
          {saveError}
        </div>
      )}

      {/* =================================================
          ACCOUNT SUMMARY
          ================================================= */}

      <section className="profile-card profile-identity">
        <div className="profile-avatar">
          {initials}
        </div>

        <div className="profile-identity__content">
          <div>
            <p className="profile-eyebrow">
              ACCOUNT
            </p>

            <h2>
              {profile.user.fullName ||
                "LifeLynk User"}
            </h2>

            <p>
              {formatRole(
                profile.user.role,
              )}
            </p>
          </div>

          {organization && (
            <div className="profile-identity__organization">
              <Building2 size={18} />

              <div>
                <strong>
                  {organization.name}
                </strong>

                <span>
                  {formatOrganizationType(
                    organization.organizationType,
                  )}
                </span>
              </div>
            </div>
          )}
        </div>
      </section>

      {/* =================================================
          PERSONAL ACCOUNT
          ================================================= */}

      <section className="profile-section">
        <div className="profile-section__heading">
          <div>
            <p className="profile-eyebrow">
              ACCOUNT INFORMATION
            </p>

            <h2>Personal account</h2>
          </div>

          <ShieldCheck />
        </div>

        {editing ? (
          <div className="profile-edit-grid">
            <EditField
              icon={
                <UserRound size={18} />
              }
              label="Full name"
              value={fullName}
              onChange={setFullName}
              placeholder="Enter your full name"
            />

            <EditField
              icon={<Mail size={18} />}
              label="Email address"
              value={email}
              onChange={setEmail}
              type="email"
              placeholder="Enter your email address"
            />

            <InfoItem
              icon={
                <ShieldCheck size={18} />
              }
              label="Account role"
              value={formatRole(
                profile.user.role,
              )}
            />
          </div>
        ) : (
          <div className="profile-grid">
            <InfoItem
              icon={
                <UserRound size={18} />
              }
              label="Full name"
              value={
                profile.user.fullName
              }
            />

            <InfoItem
              icon={<Mail size={18} />}
              label="Email address"
              value={
                profile.user.email
              }
            />

            <InfoItem
              icon={
                <ShieldCheck size={18} />
              }
              label="Account role"
              value={formatRole(
                profile.user.role,
              )}
            />
          </div>
        )}
      </section>

      {/* =================================================
          ORGANIZATION
          ================================================= */}

      {organization && (
        <>
          <section className="profile-section">
            <div className="profile-section__heading">
              <div>
                <p className="profile-eyebrow">
                  ORGANIZATION
                </p>

                <h2>
                  Organization information
                </h2>
              </div>

              <Building2 />
            </div>

            {editing ? (
              <>
                <div className="profile-edit-grid">
                  <EditField
                    icon={
                      <Building2 size={18} />
                    }
                    label="Organization name"
                    value={
                      organizationName
                    }
                    onChange={
                      setOrganizationName
                    }
                    placeholder="Enter organization name"
                  />

                  <InfoItem
                    icon={
                      <FileText
                        size={18}
                      />
                    }
                    label="Registration number"
                    value={
                      organization.registrationNumber ??
                      "Not provided"
                    }
                  />

                  <EditField
                    icon={
                      <Phone size={18} />
                    }
                    label="Phone"
                    value={
                      organizationPhone
                    }
                    onChange={
                      setOrganizationPhone
                    }
                    type="tel"
                    placeholder="Enter phone number"
                  />

                  <EditField
                    icon={
                      <Mail size={18} />
                    }
                    label="Organization email"
                    value={
                      organizationEmail
                    }
                    onChange={
                      setOrganizationEmail
                    }
                    type="email"
                    placeholder="Enter organization email"
                  />

                  <InfoItem
                    icon={
                      <MapPin
                        size={18}
                      />
                    }
                    label="City"
                    value={
                      profile.location
                        ?.city ??
                      "Not provided"
                    }
                  />

                  <InfoItem
                    icon={
                      <MapPin
                        size={18}
                      />
                    }
                    label="Province"
                    value={
                      profile.location
                        ?.province ??
                      "Not provided"
                    }
                  />

                  <EditField
                    icon={
                      <MapPin
                        size={18}
                      />
                    }
                    label="Address"
                    value={
                      organizationAddress
                    }
                    onChange={
                      setOrganizationAddress
                    }
                    placeholder="Enter organization address"
                  />

                  <div className="profile-info-item">
                    <span className="profile-info-item__icon">
                      <ShieldCheck
                        size={18}
                      />
                    </span>

                    <div>
                      <span className="profile-info-item__label">
                        Verification status
                      </span>

                      <VerificationBadge
                        status={
                          organization.verificationStatus
                        }
                      />
                    </div>
                  </div>

                  <InfoItem
                    icon={
                      <CalendarDays
                        size={18}
                      />
                    }
                    label="Registered"
                    value={formatDate(
                      organization.createdAt,
                    )}
                  />

                  <InfoItem
                    icon={
                      <CalendarDays
                        size={18}
                      />
                    }
                    label="Verified"
                    value={formatDate(
                      organization.verifiedAt,
                    )}
                  />
                </div>

                {organization.verificationNotes && (
                  <div className="profile-note">
                    <strong>
                      Verification notes
                    </strong>

                    <p>
                      {
                        organization.verificationNotes
                      }
                    </p>
                  </div>
                )}
              </>
            ) : (
              <div className="profile-grid">
                <InfoItem
                  icon={
                    <Building2
                      size={18}
                    />
                  }
                  label="Organization name"
                  value={
                    organization.name
                  }
                />

                <InfoItem
                  icon={
                    <FileText
                      size={18}
                    />
                  }
                  label="Registration number"
                  value={
                    organization.registrationNumber ??
                    "Not provided"
                  }
                />

                <InfoItem
                  icon={
                    <Phone size={18} />
                  }
                  label="Phone"
                  value={
                    organization.phone ??
                    "Not provided"
                  }
                />

                <InfoItem
                  icon={
                    <Mail size={18} />
                  }
                  label="Organization email"
                  value={
                    organization.email ??
                    "Not provided"
                  }
                />

                <InfoItem
                  icon={
                    <MapPin
                      size={18}
                    />
                  }
                  label="City"
                  value={
                    profile.location
                      ?.city ??
                    "Not provided"
                  }
                />

                <InfoItem
                  icon={
                    <MapPin
                      size={18}
                    />
                  }
                  label="Province"
                  value={
                    profile.location
                      ?.province ??
                    "Not provided"
                  }
                />

                <InfoItem
                  icon={
                    <MapPin
                      size={18}
                    />
                  }
                  label="Address"
                  value={
                    organization.address ??
                    "Not provided"
                  }
                />

                <div className="profile-info-item">
                  <span className="profile-info-item__icon">
                    <ShieldCheck
                      size={18}
                    />
                  </span>

                  <div>
                    <span className="profile-info-item__label">
                      Verification status
                    </span>

                    <VerificationBadge
                      status={
                        organization.verificationStatus
                      }
                    />
                  </div>
                </div>

                <InfoItem
                  icon={
                    <CalendarDays
                      size={18}
                    />
                  }
                  label="Registered"
                  value={formatDate(
                    organization.createdAt,
                  )}
                />

                <InfoItem
                  icon={
                    <CalendarDays
                      size={18}
                    />
                  }
                  label="Verified"
                  value={formatDate(
                    organization.verifiedAt,
                  )}
                />
              </div>
            )}

            {!editing &&
              organization.verificationNotes && (
                <div className="profile-note">
                  <strong>
                    Verification notes
                  </strong>

                  <p>
                    {
                      organization.verificationNotes
                    }
                  </p>
                </div>
              )}
          </section>

          {/* =============================================
              HOSPITAL
              ============================================= */}

          {organizationType ===
            "HOSPITAL" && (
            <section className="profile-section">
              <div className="profile-section__heading">
                <div>
                  <p className="profile-eyebrow">
                    HOSPITAL PROFILE
                  </p>

                  <h2>
                    Hospital information
                  </h2>
                </div>

                <HeartPulse />
              </div>

              {editing ? (
                <div className="profile-edit-grid">
                  <EditField
                    icon={
                      <Building2
                        size={18}
                      />
                    }
                    label="Hospital type"
                    value={hospitalType}
                    onChange={
                      setHospitalType
                    }
                    placeholder="e.g. Public, Private"
                  />

                  <EditField
                    icon={
                      <FileText
                        size={18}
                      />
                    }
                    label="License number"
                    value={
                      hospitalLicenseNumber
                    }
                    onChange={
                      setHospitalLicenseNumber
                    }
                    placeholder="Enter license number"
                  />

                  <EditToggle
                    label="Emergency service"
                    value={
                      emergencyService
                    }
                    onChange={
                      setEmergencyService
                    }
                  />

                  <EditToggle
                    label="Blood storage"
                    value={
                      bloodStorageAvailable
                    }
                    onChange={
                      setBloodStorageAvailable
                    }
                  />

                  <EditField
                    icon={
                      <BedDouble
                        size={18}
                      />
                    }
                    label="Total beds"
                    value={totalBeds}
                    onChange={setTotalBeds}
                    type="number"
                    placeholder="Enter total beds"
                  />

                  <EditToggle
                    label="ICU availability"
                    value={
                      icuAvailable
                    }
                    onChange={
                      setIcuAvailable
                    }
                  />
                </div>
              ) : (
                <div className="profile-grid">
                  <InfoItem
                    icon={
                      <Building2
                        size={18}
                      />
                    }
                    label="Hospital type"
                    value={
                      profile.hospital
                        ?.hospitalType ??
                      "Not provided"
                    }
                  />

                  <InfoItem
                    icon={
                      <FileText
                        size={18}
                      />
                    }
                    label="License number"
                    value={
                      profile.hospital
                        ?.licenseNumber ??
                      "Not provided"
                    }
                  />

                  <div className="profile-info-item">
                    <span className="profile-info-item__icon">
                      <HeartPulse
                        size={18}
                      />
                    </span>

                    <div>
                      <span className="profile-info-item__label">
                        Emergency service
                      </span>

                      <BooleanValue
                        value={
                          profile.hospital
                            ?.emergencyService ??
                          false
                        }
                      />
                    </div>
                  </div>

                  <div className="profile-info-item">
                    <span className="profile-info-item__icon">
                      <Droplets
                        size={18}
                      />
                    </span>

                    <div>
                      <span className="profile-info-item__label">
                        Blood storage
                      </span>

                      <BooleanValue
                        value={
                          profile.hospital
                            ?.bloodStorageAvailable ??
                          false
                        }
                      />
                    </div>
                  </div>

                  <InfoItem
                    icon={
                      <BedDouble
                        size={18}
                      />
                    }
                    label="Total beds"
                    value={
                      profile.hospital
                        ?.totalBeds != null
                        ? String(
                            profile.hospital
                              .totalBeds,
                          )
                        : "Not provided"
                    }
                  />

                  <div className="profile-info-item">
                    <span className="profile-info-item__icon">
                      <HeartPulse
                        size={18}
                      />
                    </span>

                    <div>
                      <span className="profile-info-item__label">
                        ICU availability
                      </span>

                      <BooleanValue
                        value={
                          profile.hospital
                            ?.icuAvailable ??
                          false
                        }
                      />
                    </div>
                  </div>
                </div>
              )}
            </section>
          )}

          {/* =============================================
              BLOOD BANK
              ============================================= */}

          {organizationType ===
            "BLOOD_BANK" && (
            <section className="profile-section">
              <div className="profile-section__heading">
                <div>
                  <p className="profile-eyebrow">
                    BLOOD BANK PROFILE
                  </p>

                  <h2>
                    Blood bank information
                  </h2>
                </div>

                <Droplets />
              </div>

              {editing ? (
                <div className="profile-edit-grid">
                  <EditField
                    icon={
                      <FileText
                        size={18}
                      />
                    }
                    label="License number"
                    value={
                      bloodBankLicenseNumber
                    }
                    onChange={
                      setBloodBankLicenseNumber
                    }
                    placeholder="Enter license number"
                  />

                  <EditField
                    icon={
                      <Droplets
                        size={18}
                      />
                    }
                    label="Storage capacity"
                    value={
                      storageCapacity
                    }
                    onChange={
                      setStorageCapacity
                    }
                    type="number"
                    placeholder="Enter storage capacity"
                  />

                  <EditToggle
                    label="Cold storage"
                    value={
                      coldStorageAvailable
                    }
                    onChange={
                      setColdStorageAvailable
                    }
                  />

                  <EditToggle
                    label="Blood processing"
                    value={
                      bloodProcessingAvailable
                    }
                    onChange={
                      setBloodProcessingAvailable
                    }
                  />

                  <EditField
                    icon={
                      <CalendarDays
                        size={18}
                      />
                    }
                    label="Operating hours"
                    value={
                      operatingHours
                    }
                    onChange={
                      setOperatingHours
                    }
                    placeholder="e.g. 24/7"
                  />
                </div>
              ) : (
                <div className="profile-grid">
                  <InfoItem
                    icon={
                      <FileText
                        size={18}
                      />
                    }
                    label="License number"
                    value={
                      profile.bloodBank
                        ?.licenseNumber ??
                      "Not provided"
                    }
                  />

                  <InfoItem
                    icon={
                      <Droplets
                        size={18}
                      />
                    }
                    label="Storage capacity"
                    value={
                      profile.bloodBank
                        ?.storageCapacity !=
                      null
                        ? `${profile.bloodBank.storageCapacity} units`
                        : "Not provided"
                    }
                  />

                  <div className="profile-info-item">
                    <span className="profile-info-item__icon">
                      <Snowflake
                        size={18}
                      />
                    </span>

                    <div>
                      <span className="profile-info-item__label">
                        Cold storage
                      </span>

                      <BooleanValue
                        value={
                          profile.bloodBank
                            ?.coldStorageAvailable ??
                          false
                        }
                      />
                    </div>
                  </div>

                  <div className="profile-info-item">
                    <span className="profile-info-item__icon">
                      <FlaskConical
                        size={18}
                      />
                    </span>

                    <div>
                      <span className="profile-info-item__label">
                        Blood processing
                      </span>

                      <BooleanValue
                        value={
                          profile.bloodBank
                            ?.bloodProcessingAvailable ??
                          false
                        }
                      />
                    </div>
                  </div>

                  <InfoItem
                    icon={
                      <CalendarDays
                        size={18}
                      />
                    }
                    label="Operating hours"
                    value={
                      profile.bloodBank
                        ?.operatingHours ??
                      "Not provided"
                    }
                  />
                </div>
              )}
            </section>
          )}
        </>
      )}

      {/* =================================================
          DANGER ZONE
          ================================================= */}

      <section className="profile-section profile-danger">
        <div className="profile-section__heading">
          <div>
            <p className="profile-eyebrow">
              DANGER ZONE
            </p>

            <h2>Delete account</h2>
          </div>

          <AlertTriangle />
        </div>

        <p className="profile-danger__description">
          This permanently deletes your
          LifeLynk login account from the
          database. Your organization and
          historical healthcare records will
          not be deleted.
        </p>

        {error && (
          <div
            className="profile-error"
            role="alert"
          >
            {error}
          </div>
        )}

        {!deleteOpen ? (
          <button
            type="button"
            className="profile-delete-button"
            onClick={() => {
              setDeleteOpen(true);
              setError("");
            }}
          >
            <Trash2 size={18} />
            Delete my account
          </button>
        ) : (
          <div className="profile-delete-confirm">
            <div>
              <strong>
                Permanently delete your
                account?
              </strong>

              <p>
                This will permanently remove
                your LifeLynk login account.
                This action cannot be undone.
              </p>

              <p>
                Your organization and
                historical healthcare
                records will remain in the
                LifeLynk system.
              </p>
            </div>

            <div className="profile-delete-actions">
              <button
                type="button"
                className="profile-cancel-button"
                disabled={deleteLoading}
                onClick={() => {
                  setDeleteOpen(false);
                  setError("");
                }}
              >
                Cancel
              </button>

              <button
                type="button"
                className="profile-confirm-delete-button"
                disabled={deleteLoading}
                onClick={
                  handleDeleteAccount
                }
              >
                {deleteLoading ? (
                  <>
                    <span className="profile-spinner" />
                    Deleting account...
                  </>
                ) : (
                  <>
                    <Trash2 size={17} />
                    Permanently delete
                    account
                  </>
                )}
              </button>
            </div>
          </div>
        )}
      </section>
    </div>
  );
}