"use client";

import "./organization-register.css";

import {
  FormEvent,
  useEffect,
  useMemo,
  useState,
} from "react";

import { useRouter } from "next/navigation";

import { createClient } from "@/lib/supabase/client";

type OrganizationType =
  | "HOSPITAL"
  | "BLOOD_BANK";

type Province = {
  id: string;
  name: string;
  code: string;
};

type City = {
  id: string;
  name: string;
  code: string;
  province_id: string;
  latitude: number | null;
  longitude: number | null;
};

type ExistingAccount = {
  id: string;
  email: string;
  fullName: string;
};

export default function OrganizationRegisterPage() {
  const router = useRouter();

  const supabase = useMemo(
    () => createClient(),
    [],
  );

  const [organizationType, setOrganizationType] =
    useState<OrganizationType>("HOSPITAL");

  const [account, setAccount] =
    useState<ExistingAccount | null>(null);

  const [accountLoading, setAccountLoading] =
    useState(true);

  const [provinces, setProvinces] =
    useState<Province[]>([]);

  const [cities, setCities] =
    useState<City[]>([]);

  const [locationsLoading, setLocationsLoading] =
    useState(true);

  const [locationsError, setLocationsError] =
    useState("");

  const [form, setForm] = useState({
    // ============================================================
    // ORGANIZATION
    // ============================================================

    organizationName: "",
    registrationNumber: "",
    phone: "",
    email: "",

    provinceId: "",
    cityId: "",

    address: "",

    latitude: "",
    longitude: "",

    // ============================================================
    // HOSPITAL
    // ============================================================

    hospitalType: "",
    hospitalLicenseNumber: "",

    emergencyService: true,
    bloodStorageAvailable: true,

    totalBeds: "",
    icuAvailable: true,

    // ============================================================
    // BLOOD BANK
    // ============================================================

    licenseNumber: "",
    storageCapacity: "",

    coldStorageAvailable: true,
    bloodProcessingAvailable: true,

    operatingHours: "",
  });

  const [loading, setLoading] =
    useState(false);

  const [error, setError] =
    useState("");

  const [success, setSuccess] =
    useState("");

  // ============================================================
  // LOAD EXISTING AUTHENTICATED ACCOUNT
  // ============================================================

  useEffect(() => {
    let cancelled = false;

    async function loadAuthenticatedAccount() {
      setAccountLoading(true);
      setError("");

      try {
        const {
          data: { user },
          error: userError,
        } = await supabase.auth.getUser();

        if (userError || !user) {
          if (!cancelled) {
            setError(
              "Your session has expired. Please sign in again.",
            );
          }

          return;
        }

        if (!user.email) {
          if (!cancelled) {
            setError(
              "Your authenticated account does not have an email address.",
            );
          }

          return;
        }

        const metadataFullName =
          typeof user.user_metadata
            ?.full_name === "string"
            ? user.user_metadata.full_name.trim()
            : "";

        /*
         * Prefer the application profile name when available.
         * The account is already authenticated, so this is NOT
         * another registration.
         */
        const {
          data: profile,
          error: profileError,
        } = await supabase
          .from("users")
          .select(`
            id,
            full_name,
            roles (
              id,
              name
            )
          `)
          .eq("id", user.id)
          .is("deleted_at", null)
          .maybeSingle();

        if (profileError) {
          console.warn(
            "Unable to load application profile:",
            profileError,
          );
        }

        const profileFullName =
          typeof profile?.full_name === "string"
            ? profile.full_name.trim()
            : "";

        const fullName =
          profileFullName ||
          metadataFullName ||
          "";

        if (!cancelled) {
          setAccount({
            id: user.id,
            email: user.email,
            fullName,
          });

          /*
           * Derive the UI organization type from the existing
           * authenticated application's role.
           */
          const roleData =
            Array.isArray(profile?.roles)
              ? profile.roles[0]
              : profile?.roles;

          if (
            roleData?.name ===
            "BLOOD_BANK_ADMIN"
          ) {
            setOrganizationType(
              "BLOOD_BANK",
            );
          } else if (
            roleData?.name ===
            "HOSPITAL_ADMIN"
          ) {
            setOrganizationType(
              "HOSPITAL",
            );
          }
        }
      } catch (err) {
        console.error(
          "Failed to load authenticated account:",
          err,
        );

        if (!cancelled) {
          setError(
            "Unable to load your account. Please sign in again.",
          );
        }
      } finally {
        if (!cancelled) {
          setAccountLoading(false);
        }
      }
    }

    loadAuthenticatedAccount();

    return () => {
      cancelled = true;
    };
  }, [supabase]);

  // ============================================================
  // LOAD PROVINCES
  // ============================================================

  useEffect(() => {
    let cancelled = false;

    async function loadProvinces() {
      setLocationsLoading(true);
      setLocationsError("");

      try {
        const {
          data,
          error: provincesError,
        } = await supabase
          .from("provinces")
          .select(`
            id,
            name,
            code
          `)
          .eq("is_active", true)
          .is("deleted_at", null)
          .order("name", {
            ascending: true,
          });

        if (provincesError) {
          throw provincesError;
        }

        if (!cancelled) {
          setProvinces(data ?? []);
        }
      } catch (err) {
        console.error(
          "Failed to load provinces:",
          err,
        );

        if (!cancelled) {
          setLocationsError(
            "Unable to load provinces. Please refresh the page and try again.",
          );
        }
      } finally {
        if (!cancelled) {
          setLocationsLoading(false);
        }
      }
    }

    loadProvinces();

    return () => {
      cancelled = true;
    };
  }, [supabase]);

  // ============================================================
  // LOAD CITIES WHEN PROVINCE CHANGES
  // ============================================================

  useEffect(() => {
    let cancelled = false;

    async function loadCities() {
      if (!form.provinceId) {
        setCities([]);
        return;
      }

      setLocationsLoading(true);
      setLocationsError("");

      try {
        const {
          data,
          error: citiesError,
        } = await supabase
          .from("cities")
          .select(`
            id,
            name,
            code,
            province_id,
            latitude,
            longitude
          `)
          .eq(
            "province_id",
            form.provinceId,
          )
          .eq("is_active", true)
          .is("deleted_at", null)
          .order("name", {
            ascending: true,
          });

        if (citiesError) {
          throw citiesError;
        }

        if (!cancelled) {
          setCities(data ?? []);
        }
      } catch (err) {
        console.error(
          "Failed to load cities:",
          err,
        );

        if (!cancelled) {
          setCities([]);

          setLocationsError(
            "Unable to load cities for the selected province.",
          );
        }
      } finally {
        if (!cancelled) {
          setLocationsLoading(false);
        }
      }
    }

    loadCities();

    return () => {
      cancelled = true;
    };
  }, [form.provinceId, supabase]);

  // ============================================================
  // SELECTED CITY
  // ============================================================

  const selectedCity = useMemo(
    () =>
      cities.find(
        (city) =>
          city.id === form.cityId,
      ) ?? null,
    [cities, form.cityId],
  );

  // ============================================================
  // FIELD UPDATE
  // ============================================================

  function updateField(
    field: keyof typeof form,
    value: string | boolean,
  ) {
    setForm((previous) => ({
      ...previous,
      [field]: value,
    }));
  }

  // ============================================================
  // PROVINCE CHANGE
  // ============================================================

  function handleProvinceChange(
    provinceId: string,
  ) {
    setForm((previous) => ({
      ...previous,

      provinceId,

      cityId: "",

      latitude: "",
      longitude: "",
    }));

    setCities([]);
  }

  // ============================================================
  // CITY CHANGE
  // ============================================================

  function handleCityChange(
    cityId: string,
  ) {
    const city = cities.find(
      (item) =>
        item.id === cityId,
    );

    setForm((previous) => ({
      ...previous,

      cityId,

      latitude:
        city?.latitude !== null &&
        city?.latitude !== undefined
          ? String(city.latitude)
          : previous.latitude,

      longitude:
        city?.longitude !== null &&
        city?.longitude !== undefined
          ? String(city.longitude)
          : previous.longitude,
    }));
  }

  // ============================================================
  // VALIDATE COORDINATES
  // ============================================================

  function validateCoordinates() {
    const latitude = Number(
      form.latitude,
    );

    const longitude = Number(
      form.longitude,
    );

    if (!form.latitude.trim()) {
      return "Organization latitude is required.";
    }

    if (!form.longitude.trim()) {
      return "Organization longitude is required.";
    }

    if (
      !Number.isFinite(latitude) ||
      latitude < -90 ||
      latitude > 90
    ) {
      return "Please enter a valid latitude between -90 and 90.";
    }

    if (
      !Number.isFinite(longitude) ||
      longitude < -180 ||
      longitude > 180
    ) {
      return "Please enter a valid longitude between -180 and 180.";
    }

    return null;
  }

  // ============================================================
  // FORM VALIDATION
  // ============================================================

  function validateForm() {
    if (!account) {
      return "Your authenticated account could not be loaded.";
    }

    // ----------------------------------------------------------
    // ORGANIZATION
    // ----------------------------------------------------------

    if (
      !form.organizationName.trim()
    ) {
      return "Organization name is required.";
    }

    if (
      !form.registrationNumber.trim()
    ) {
      return "Registration number is required.";
    }

    if (!form.phone.trim()) {
      return "Phone number is required.";
    }

    if (!form.email.trim()) {
      return "Organization email is required.";
    }

    if (!form.provinceId) {
      return "Please select a province.";
    }

    if (!form.cityId) {
      return "Please select a city.";
    }

    if (!form.address.trim()) {
      return "Organization address is required.";
    }

    const coordinateError =
      validateCoordinates();

    if (coordinateError) {
      return coordinateError;
    }

    // ----------------------------------------------------------
    // HOSPITAL
    // ----------------------------------------------------------

    if (
      organizationType ===
      "HOSPITAL"
    ) {
      if (
        !form.hospitalType.trim()
      ) {
        return "Hospital type is required.";
      }

      if (
        !form.hospitalLicenseNumber.trim()
      ) {
        return "Hospital license number is required.";
      }

      if (!form.totalBeds.trim()) {
        return "Total beds is required.";
      }

      const totalBeds = Number(
        form.totalBeds,
      );

      if (
        !Number.isInteger(
          totalBeds,
        ) ||
        totalBeds < 0
      ) {
        return "Please enter a valid total number of beds.";
      }
    }

    // ----------------------------------------------------------
    // BLOOD BANK
    // ----------------------------------------------------------

    if (
      organizationType ===
      "BLOOD_BANK"
    ) {
      if (
        !form.licenseNumber.trim()
      ) {
        return "Blood bank license number is required.";
      }

      if (
        !form.storageCapacity.trim()
      ) {
        return "Storage capacity is required.";
      }

      const storageCapacity =
        Number(
          form.storageCapacity,
        );

      if (
        !Number.isInteger(
          storageCapacity,
        ) ||
        storageCapacity < 0
      ) {
        return "Please enter a valid storage capacity.";
      }
    }

    return null;
  }

  // ============================================================
  // HANDLE SUBMIT
  // ============================================================

  async function handleSubmit(
    event: FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault();

    setError("");
    setSuccess("");

    const validationError =
      validateForm();

    if (validationError) {
      setError(validationError);
      return;
    }

    setLoading(true);

    try {
      /*
       * IMPORTANT:
       *
       * There is deliberately NO password here.
       * There is deliberately NO account creation here.
       *
       * The server identifies the existing authenticated
       * user from the Supabase session and uses that user's
       * auth.uid().
       */
      const payload = {
        organizationType,

        organizationName:
          form.organizationName.trim(),

        registrationNumber:
          form.registrationNumber.trim(),

        phone:
          form.phone.trim(),

        email:
          form.email
            .trim()
            .toLowerCase(),

        provinceId:
          form.provinceId,

        cityId:
          form.cityId,

        address:
          form.address.trim(),

        latitude:
          form.latitude.trim(),

        longitude:
          form.longitude.trim(),

        hospitalType:
          organizationType ===
          "HOSPITAL"
            ? form.hospitalType.trim()
            : "",

        hospitalLicenseNumber:
          organizationType ===
          "HOSPITAL"
            ? form.hospitalLicenseNumber.trim()
            : "",

        emergencyService:
          organizationType ===
          "HOSPITAL"
            ? form.emergencyService
            : false,

        bloodStorageAvailable:
          organizationType ===
          "HOSPITAL"
            ? form.bloodStorageAvailable
            : false,

        totalBeds:
          organizationType ===
          "HOSPITAL"
            ? form.totalBeds.trim()
            : "",

        icuAvailable:
          organizationType ===
          "HOSPITAL"
            ? form.icuAvailable
            : false,

        licenseNumber:
          organizationType ===
          "BLOOD_BANK"
            ? form.licenseNumber.trim()
            : "",

        storageCapacity:
          organizationType ===
          "BLOOD_BANK"
            ? form.storageCapacity.trim()
            : "",

        coldStorageAvailable:
          organizationType ===
          "BLOOD_BANK"
            ? form.coldStorageAvailable
            : false,

        bloodProcessingAvailable:
          organizationType ===
          "BLOOD_BANK"
            ? form.bloodProcessingAvailable
            : false,

        operatingHours:
          organizationType ===
          "BLOOD_BANK"
            ? form.operatingHours.trim()
            : "",
      };

      if (
        process.env.NODE_ENV ===
        "development"
      ) {
        console.log(
          "ORGANIZATION ONBOARDING PAYLOAD",
          {
            organizationType:
              payload.organizationType,

            organizationName:
              payload.organizationName,

            authenticatedUserId:
              account?.id,

            authenticatedEmail:
              account?.email,

            hasPassword:
              false,
          },
        );
      }

      const response =
        await fetch(
          "/api/organizations/register",
          {
            method: "POST",

            headers: {
              "Content-Type":
                "application/json",
            },

            credentials: "include",

            body:
              JSON.stringify(
                payload,
              ),
          },
        );

      const result =
        await response.json();

      if (!response.ok) {
        if (
          response.status ===
            409 &&
          result.code ===
            "ORGANIZATION_ALREADY_EXISTS"
        ) {
          setError(
            "An organization with this registration number already exists. Please use the existing organization instead.",
          );

          return;
        }

        if (
          response.status ===
            409 &&
          result.code ===
            "ALREADY_ASSIGNED"
        ) {
          setError(
            "Your account is already assigned to an organization.",
          );

          return;
        }

        setError(
          result.error ||
            "Unable to complete organization registration.",
        );

        return;
      }

      setSuccess(
        "Organization registration submitted successfully. Your organization is now pending LifeLynk verification.",
      );

      /*
       * The browser session is already authenticated.
       *
       * We DO NOT sign in again.
       *
       * We DO NOT create another Auth user.
       */
      router.replace(
        "/organization-verification/pending",
      );

      router.refresh();
    } catch (err) {
      console.error(
        "Organization registration request failed:",
        err,
      );

      setError(
        "Unable to connect to the registration service. Please try again.",
      );
    } finally {
      setLoading(false);
    }
  }

  // ============================================================
  // LOADING ACCOUNT
  // ============================================================

  if (accountLoading) {
    return (
      <main className="lifelynk-auth-page">
        <section className="lifelynk-auth-card lifelynk-organization-register">
          <div className="lifelynk-auth-card__header">
            <div>
              <span className="lifelynk-auth-card__eyebrow">
                LifeLynk Organization Portal
              </span>

              <h1>
                Loading your account
              </h1>

              <p>
                Preparing your existing
                LifeLynk account for
                organization onboarding.
              </p>
            </div>
          </div>
        </section>
      </main>
    );
  }

  // ============================================================
  // UI
  // ============================================================

  return (
    <main className="lifelynk-auth-page">
      <section className="lifelynk-auth-card lifelynk-organization-register">

        {/* ======================================================
            HEADER
        ======================================================= */}

        <div className="lifelynk-auth-card__header">
          <div>
            <span className="lifelynk-auth-card__eyebrow">
              LifeLynk Organization Portal
            </span>

            <h1>
              Register Organization
            </h1>

            <p>
              Register your hospital or
              blood bank using your
              existing LifeLynk account.
            </p>
          </div>
        </div>

        {/* ======================================================
            EXISTING ACCOUNT NOTICE
        ======================================================= */}

        {account && (
          <div className="lifelynk-alert lifelynk-alert--success">
            <div>
              <strong>
                Existing account
              </strong>

              <span>
                This organization will be
                connected to your existing
                LifeLynk account:
                {" "}
                {account.email}
              </span>
            </div>
          </div>
        )}

        {/* ======================================================
            LOCATION ERROR
        ======================================================= */}

        {locationsError && (
          <div className="lifelynk-alert lifelynk-alert--error">
            <div>
              <strong>
                Location Data Error
              </strong>

              <span>
                {locationsError}
              </span>
            </div>
          </div>
        )}

        {/* ======================================================
            FORM ERROR
        ======================================================= */}

        {error && (
          <div className="lifelynk-alert lifelynk-alert--error">
            <div>
              <strong>
                Registration Error
              </strong>

              <span>
                {error}
              </span>
            </div>
          </div>
        )}

        {/* ======================================================
            SUCCESS
        ======================================================= */}

        {success && (
          <div className="lifelynk-alert lifelynk-alert--success">
            <div>
              <strong>
                Registration Submitted
              </strong>

              <span>
                {success}
              </span>
            </div>
          </div>
        )}

        <form
          className="lifelynk-form organization-registration-form"
          onSubmit={handleSubmit}
        >

          {/* ====================================================
              ORGANIZATION TYPE
          ===================================================== */}

          <div className="organization-registration-section">
            <div className="organization-registration-section__header">
              <div>
                <h2>
                  Organization Type
                </h2>

                <p>
                  Select the type of
                  healthcare organization
                  you are registering.
                </p>
              </div>
            </div>

            <div className="organization-type-grid">

              {/* Hospital */}

              <button
                type="button"
                className={`organization-type-card ${
                  organizationType ===
                  "HOSPITAL"
                    ? "is-selected"
                    : ""
                }`}
                onClick={() =>
                  setOrganizationType(
                    "HOSPITAL",
                  )
                }
                disabled={loading}
              >
                <span className="organization-type-card__icon">
                  🏥
                </span>

                <span>
                  <strong>
                    Hospital
                  </strong>

                  <small>
                    Register a hospital
                    and its blood storage
                    services.
                  </small>
                </span>
              </button>

              {/* Blood Bank */}

              <button
                type="button"
                className={`organization-type-card ${
                  organizationType ===
                  "BLOOD_BANK"
                    ? "is-selected"
                    : ""
                }`}
                onClick={() =>
                  setOrganizationType(
                    "BLOOD_BANK",
                  )
                }
                disabled={loading}
              >
                <span className="organization-type-card__icon">
                  🩸
                </span>

                <span>
                  <strong>
                    Blood Bank
                  </strong>

                  <small>
                    Register a blood bank
                    and its inventory
                    facilities.
                  </small>
                </span>
              </button>
            </div>
          </div>

          {/* ====================================================
              ORGANIZATION INFORMATION
          ===================================================== */}

          <div className="organization-registration-section">
            <div className="organization-registration-section__header">
              <div>
                <h2>
                  Organization Information
                </h2>

                <p>
                  Enter the official
                  information of your
                  organization.
                </p>
              </div>
            </div>

            <div className="lifelynk-form__grid">

              {/* Organization Name */}

              <div className="lifelynk-form__field lifelynk-form__field--full">
                <label htmlFor="organizationName">
                  Organization Name
                </label>

                <input
                  id="organizationName"
                  value={
                    form.organizationName
                  }
                  onChange={(event) =>
                    updateField(
                      "organizationName",
                      event.target.value,
                    )
                  }
                  placeholder="e.g. Life Hospital Lahore"
                  disabled={loading}
                />
              </div>

              {/* Registration Number */}

              <div className="lifelynk-form__field">
                <label htmlFor="registrationNumber">
                  Registration Number
                </label>

                <input
                  id="registrationNumber"
                  value={
                    form.registrationNumber
                  }
                  onChange={(event) =>
                    updateField(
                      "registrationNumber",
                      event.target.value,
                    )
                  }
                  placeholder="Official registration number"
                  disabled={loading}
                />
              </div>

              {/* Phone */}

              <div className="lifelynk-form__field">
                <label htmlFor="phone">
                  Organization Phone
                </label>

                <input
                  id="phone"
                  type="tel"
                  value={form.phone}
                  onChange={(event) =>
                    updateField(
                      "phone",
                      event.target.value,
                    )
                  }
                  placeholder="+92 300 1234567"
                  disabled={loading}
                />
              </div>

              {/* Email */}

              <div className="lifelynk-form__field">
                <label htmlFor="email">
                  Organization Email
                </label>

                <input
                  id="email"
                  type="email"
                  value={form.email}
                  onChange={(event) =>
                    updateField(
                      "email",
                      event.target.value,
                    )
                  }
                  placeholder="organization@example.com"
                  disabled={loading}
                />
              </div>

              {/* Address */}

              <div className="lifelynk-form__field">
                <label htmlFor="address">
                  Address
                </label>

                <input
                  id="address"
                  value={form.address}
                  onChange={(event) =>
                    updateField(
                      "address",
                      event.target.value,
                    )
                  }
                  placeholder="Complete organization address"
                  disabled={loading}
                />
              </div>

              {/* Province */}

              <div className="lifelynk-form__field">
                <label htmlFor="provinceId">
                  Province
                </label>

                <select
                  id="provinceId"
                  value={form.provinceId}
                  onChange={(event) =>
                    handleProvinceChange(
                      event.target.value,
                    )
                  }
                  disabled={
                    loading ||
                    locationsLoading
                  }
                >
                  <option value="">
                    {locationsLoading
                      ? "Loading provinces..."
                      : "Select province"}
                  </option>

                  {provinces.map(
                    (province) => (
                      <option
                        key={
                          province.id
                        }
                        value={
                          province.id
                        }
                      >
                        {province.name}
                      </option>
                    ),
                  )}
                </select>
              </div>

              {/* City */}

              <div className="lifelynk-form__field">
                <label htmlFor="cityId">
                  City
                </label>

                <select
                  id="cityId"
                  value={form.cityId}
                  onChange={(event) =>
                    handleCityChange(
                      event.target.value,
                    )
                  }
                  disabled={
                    loading ||
                    !form.provinceId ||
                    locationsLoading
                  }
                >
                  <option value="">
                    {!form.provinceId
                      ? "Select province first"
                      : locationsLoading
                        ? "Loading cities..."
                        : "Select city"}
                  </option>

                  {cities.map(
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

              {/* Latitude */}

              <div className="lifelynk-form__field">
                <label htmlFor="latitude">
                  Latitude
                </label>

                <input
                  id="latitude"
                  type="number"
                  step="any"
                  value={form.latitude}
                  onChange={(event) =>
                    updateField(
                      "latitude",
                      event.target.value,
                    )
                  }
                  placeholder="31.5204"
                  disabled={loading}
                />

                {selectedCity?.latitude !==
                  null &&
                  selectedCity?.latitude !==
                    undefined && (
                    <small>
                      Automatically loaded
                      from the selected
                      city. You can adjust
                      it for the organization.
                    </small>
                  )}
              </div>

              {/* Longitude */}

              <div className="lifelynk-form__field">
                <label htmlFor="longitude">
                  Longitude
                </label>

                <input
                  id="longitude"
                  type="number"
                  step="any"
                  value={
                    form.longitude
                  }
                  onChange={(event) =>
                    updateField(
                      "longitude",
                      event.target.value,
                    )
                  }
                  placeholder="74.3587"
                  disabled={loading}
                />

                {selectedCity?.longitude !==
                  null &&
                  selectedCity?.longitude !==
                    undefined && (
                    <small>
                      Automatically loaded
                      from the selected
                      city. You can adjust
                      it for the organization.
                    </small>
                  )}
              </div>
            </div>
          </div>

          {/* ====================================================
              EXISTING ACCOUNT / ORGANIZATION ADMINISTRATOR
          ===================================================== */}

          <div className="organization-registration-section">
            <div className="organization-registration-section__header">
              <div>
                <h2>
                  Organization Administrator
                </h2>

                <p>
                  This is your existing
                  LifeLynk account. It will
                  become the primary staff
                  member for this organization.
                </p>
              </div>
            </div>

            <div className="lifelynk-form__grid">

              {/* Full Name */}

              <div className="lifelynk-form__field">
                <label htmlFor="fullName">
                  Full Name
                </label>

                <input
                  id="fullName"
                  value={
                    account?.fullName ??
                    ""
                  }
                  readOnly
                  disabled
                />

                <small>
                  Taken from your existing
                  LifeLynk account.
                </small>
              </div>

              {/* Account Email */}

              <div className="lifelynk-form__field">
                <label htmlFor="accountEmail">
                  Account Email
                </label>

                <input
                  id="accountEmail"
                  type="email"
                  value={
                    account?.email ??
                    ""
                  }
                  readOnly
                  disabled
                />

                <small>
                  This account is already
                  authenticated. No new
                  account will be created.
                </small>
              </div>
            </div>
          </div>

          {/* ====================================================
              HOSPITAL INFORMATION
          ===================================================== */}

          {organizationType ===
            "HOSPITAL" && (
            <div className="organization-registration-section">

              <div className="organization-registration-section__header">
                <div>
                  <h2>
                    Hospital Information
                  </h2>

                  <p>
                    Provide information
                    specific to your
                    hospital.
                  </p>
                </div>
              </div>

              <div className="lifelynk-form__grid">

                {/* Hospital Type */}

                <div className="lifelynk-form__field">
                  <label htmlFor="hospitalType">
                    Hospital Type
                  </label>

                  <select
                    id="hospitalType"
                    value={
                      form.hospitalType
                    }
                    onChange={(event) =>
                      updateField(
                        "hospitalType",
                        event.target.value,
                      )
                    }
                    disabled={loading}
                  >
                    <option value="">
                      Select hospital type
                    </option>

                    <option value="PUBLIC">
                      Public
                    </option>

                    <option value="PRIVATE">
                      Private
                    </option>

                    <option value="TEACHING">
                      Teaching
                    </option>

                    <option value="SPECIALIZED">
                      Specialized
                    </option>
                  </select>
                </div>

                {/* Hospital License */}

                <div className="lifelynk-form__field">
                  <label htmlFor="hospitalLicenseNumber">
                    Hospital License Number
                  </label>

                  <input
                    id="hospitalLicenseNumber"
                    name="hospitalLicenseNumber"
                    type="text"
                    autoComplete="off"
                    value={
                      form.hospitalLicenseNumber
                    }
                    onChange={(event) =>
                      updateField(
                        "hospitalLicenseNumber",
                        event.target.value,
                      )
                    }
                    placeholder="Official hospital license number"
                    disabled={loading}
                  />
                </div>

                {/* Total Beds */}

                <div className="lifelynk-form__field">
                  <label htmlFor="totalBeds">
                    Total Beds
                  </label>

                  <input
                    id="totalBeds"
                    type="number"
                    min="0"
                    step="1"
                    value={
                      form.totalBeds
                    }
                    onChange={(event) =>
                      updateField(
                        "totalBeds",
                        event.target.value,
                      )
                    }
                    placeholder="e.g. 150"
                    disabled={loading}
                  />
                </div>

                {/* Emergency */}

                <div className="organization-toggle">
                  <label>
                    <input
                      type="checkbox"
                      checked={
                        form.emergencyService
                      }
                      onChange={(event) =>
                        updateField(
                          "emergencyService",
                          event.target.checked,
                        )
                      }
                      disabled={loading}
                    />

                    <span>
                      <strong>
                        Emergency Service
                      </strong>

                      <small>
                        Hospital provides
                        emergency services.
                      </small>
                    </span>
                  </label>
                </div>

                {/* Blood Storage */}

                <div className="organization-toggle">
                  <label>
                    <input
                      type="checkbox"
                      checked={
                        form.bloodStorageAvailable
                      }
                      onChange={(event) =>
                        updateField(
                          "bloodStorageAvailable",
                          event.target.checked,
                        )
                      }
                      disabled={loading}
                    />

                    <span>
                      <strong>
                        Blood Storage
                      </strong>

                      <small>
                        Hospital maintains
                        blood storage.
                      </small>
                    </span>
                  </label>
                </div>

                {/* ICU */}

                <div className="organization-toggle">
                  <label>
                    <input
                      type="checkbox"
                      checked={
                        form.icuAvailable
                      }
                      onChange={(event) =>
                        updateField(
                          "icuAvailable",
                          event.target.checked,
                        )
                      }
                      disabled={loading}
                    />

                    <span>
                      <strong>
                        ICU Available
                      </strong>

                      <small>
                        ICU services are
                        available.
                      </small>
                    </span>
                  </label>
                </div>
              </div>
            </div>
          )}

          {/* ====================================================
              BLOOD BANK INFORMATION
          ===================================================== */}

          {organizationType ===
            "BLOOD_BANK" && (
            <div className="organization-registration-section">

              <div className="organization-registration-section__header">
                <div>
                  <h2>
                    Blood Bank Information
                  </h2>

                  <p>
                    Provide information
                    specific to your blood
                    bank.
                  </p>
                </div>
              </div>

              <div className="lifelynk-form__grid">

                {/* License */}

                <div className="lifelynk-form__field">
                  <label htmlFor="licenseNumber">
                    License Number
                  </label>

                  <input
                    id="licenseNumber"
                    name="licenseNumber"
                    type="text"
                    autoComplete="off"
                    value={
                      form.licenseNumber
                    }
                    onChange={(event) =>
                      updateField(
                        "licenseNumber",
                        event.target.value,
                      )
                    }
                    placeholder="Blood bank license number"
                    disabled={loading}
                  />
                </div>

                {/* Storage Capacity */}

                <div className="lifelynk-form__field">
                  <label htmlFor="storageCapacity">
                    Storage Capacity
                  </label>

                  <input
                    id="storageCapacity"
                    type="number"
                    min="0"
                    step="1"
                    value={
                      form.storageCapacity
                    }
                    onChange={(event) =>
                      updateField(
                        "storageCapacity",
                        event.target.value,
                      )
                    }
                    placeholder="Number of units"
                    disabled={loading}
                  />
                </div>

                {/* Operating Hours */}

                <div className="lifelynk-form__field">
                  <label htmlFor="operatingHours">
                    Operating Hours
                  </label>

                  <input
                    id="operatingHours"
                    value={
                      form.operatingHours
                    }
                    onChange={(event) =>
                      updateField(
                        "operatingHours",
                        event.target.value,
                      )
                    }
                    placeholder="e.g. 24/7"
                    disabled={loading}
                  />
                </div>

                {/* Cold Storage */}

                <div className="organization-toggle">
                  <label>
                    <input
                      type="checkbox"
                      checked={
                        form.coldStorageAvailable
                      }
                      onChange={(event) =>
                        updateField(
                          "coldStorageAvailable",
                          event.target.checked,
                        )
                      }
                      disabled={loading}
                    />

                    <span>
                      <strong>
                        Cold Storage
                      </strong>

                      <small>
                        Cold storage facilities
                        are available.
                      </small>
                    </span>
                  </label>
                </div>

                {/* Blood Processing */}

                <div className="organization-toggle">
                  <label>
                    <input
                      type="checkbox"
                      checked={
                        form.bloodProcessingAvailable
                      }
                      onChange={(event) =>
                        updateField(
                          "bloodProcessingAvailable",
                          event.target.checked,
                        )
                      }
                      disabled={loading}
                    />

                    <span>
                      <strong>
                        Blood Processing
                      </strong>

                      <small>
                        Blood processing
                        facilities are
                        available.
                      </small>
                    </span>
                  </label>
                </div>
              </div>
            </div>
          )}

          {/* ====================================================
              VERIFICATION + SUBMIT
          ===================================================== */}

          <div className="organization-registration-submit">

            <div>
              <strong>
                Verification Required
              </strong>

              <p>
                Your organization will
                remain pending until it is
                verified by a LifeLynk
                administrator. Your existing
                account will become the primary
                administrator for the organization.
              </p>
            </div>

            <button
              type="submit"
              className="lifelynk-button lifelynk-button--primary"
              disabled={
                loading ||
                locationsLoading ||
                !account
              }
            >
              {loading
                ? "Submitting..."
                : "Submit Organization Registration"}
            </button>
          </div>

        </form>
      </section>
    </main>
  );
}