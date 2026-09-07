"use client";

import Image from "next/image";
import { useEffect, useMemo, useState } from "react";

import { createClient } from "@/lib/supabase/client";

import {
  useTheme,
  type Appearance,
} from "@/components/theme/theme-provider";

import "./settings.css";

type UserSettings = {
  notifications_enabled: boolean;
  location_enabled: boolean;
  appearance: Appearance;
};

type SettingToggle = {
  notifications: boolean;
  location: boolean;
};

export default function SettingsPage() {
  const supabase = useMemo(
    () => createClient(),
    [],
  );

  const {
    appearance,
    setAppearance,
  } = useTheme();

  const [toggles, setToggles] =
    useState<SettingToggle>({
      notifications: true,
      location: true,
    });

  const [settingsLoading, setSettingsLoading] =
    useState(true);

  const [settingsSaving, setSettingsSaving] =
    useState(false);

  const [settingsError, setSettingsError] =
    useState<string | null>(null);

  const [showPasswordForm, setShowPasswordForm] =
    useState(false);

  const [newPassword, setNewPassword] =
    useState("");

  const [confirmPassword, setConfirmPassword] =
    useState("");

  const [passwordLoading, setPasswordLoading] =
    useState(false);

  const [passwordMessage, setPasswordMessage] =
    useState<string | null>(null);

  const [passwordError, setPasswordError] =
    useState<string | null>(null);

  const [showAbout, setShowAbout] =
    useState(false);

  /* 
   * ---------------------------------------------------- 
   * LOAD USER SETTINGS 
   * ---------------------------------------------------- 
   */

  useEffect(() => {
    let mounted = true;

    async function loadSettings() {
      setSettingsLoading(true);
      setSettingsError(null);

      const {
        data: { user },
        error: userError,
      } = await supabase.auth.getUser();

      if (userError || !user) {
        if (mounted) {
          setSettingsError(
            "Unable to identify the current user.",
          );
          setSettingsLoading(false);
        }

        return;
      }

      /*
       * First try to load the existing row.
       */

      const {
        data,
        error,
      } = await supabase
        .from("user_settings")
        .select(
          `
            user_id,
            notifications_enabled,
            location_enabled,
            appearance,
            deleted_at
          `,
        )
        .eq("user_id", user.id)
        .maybeSingle();

      if (error) {
        console.error(
          "SETTINGS LOAD ERROR",
          {
            message: error.message,
            details: error.details,
            hint: error.hint,
            code: error.code,
          },
        );

        if (mounted) {
          setSettingsError(
            "Unable to load your settings.",
          );
          setSettingsLoading(false);
        }

        return;
      }

      /*
       * ------------------------------------------------
       * NO ROW EXISTS
       * ------------------------------------------------
       *
       * Create default settings.
       *
       * If another request creates the row at the same
       * time, handle the duplicate-key case by fetching
       * the existing row instead of treating it as a
       * fatal error.
       */

      if (!data) {
        const defaultSettings: UserSettings = {
          notifications_enabled: true,
          location_enabled: true,
          appearance: "light",
        };

        const {
          error: insertError,
        } = await supabase
          .from("user_settings")
          .insert({
            user_id: user.id,
            notifications_enabled:
              defaultSettings.notifications_enabled,
            location_enabled:
              defaultSettings.location_enabled,
            appearance:
              defaultSettings.appearance,
          });

        if (insertError) {
          /*
           * Another request may have created the row
           * between SELECT and INSERT.
           *
           * PostgreSQL duplicate-key code:
           * 23505
           */

          if (
            insertError.code === "23505"
          ) {
            const {
              data: existingSettings,
              error: retryError,
            } = await supabase
              .from("user_settings")
              .select(
                `
                  notifications_enabled,
                  location_enabled,
                  appearance,
                  deleted_at
                `,
              )
              .eq("user_id", user.id)
              .maybeSingle();

            if (
              retryError ||
              !existingSettings
            ) {
              console.error(
                "SETTINGS RETRY LOAD ERROR",
                {
                  message:
                    retryError?.message,
                  details:
                    retryError?.details,
                  hint:
                    retryError?.hint,
                  code:
                    retryError?.code,
                },
              );

              if (mounted) {
                setSettingsError(
                  "Unable to load your settings.",
                );
                setSettingsLoading(
                  false,
                );
              }

              return;
            }

            if (
              existingSettings.deleted_at !==
              null
            ) {
              const {
                data: restored,
                error: restoreError,
              } = await supabase
                .from("user_settings")
                .update({
                  deleted_at: null,
                  updated_at:
                    new Date().toISOString(),
                })
                .eq(
                  "user_id",
                  user.id,
                )
                .select(
                  `
                    notifications_enabled,
                    location_enabled,
                    appearance
                  `,
                )
                .single();

              if (
                restoreError ||
                !restored
              ) {
                console.error(
                  "SETTINGS RESTORE ERROR",
                  {
                    message:
                      restoreError?.message,
                    details:
                      restoreError?.details,
                    hint:
                      restoreError?.hint,
                    code:
                      restoreError?.code,
                  },
                );

                if (mounted) {
                  setSettingsError(
                    "Unable to restore your settings.",
                  );
                  setSettingsLoading(
                    false,
                  );
                }

                return;
              }

              if (mounted) {
                setToggles({
                  notifications:
                    restored.notifications_enabled,
                  location:
                    restored.location_enabled,
                });

                setAppearance(
                  restored.appearance ===
                    "dark"
                    ? "dark"
                    : restored.appearance ===
                        "system"
                      ? "system"
                      : "light",
                );

                setSettingsLoading(
                  false,
                );
              }

              return;
            }

            if (mounted) {
              setToggles({
                notifications:
                  existingSettings.notifications_enabled,
                location:
                  existingSettings.location_enabled,
              });

              setAppearance(
                existingSettings.appearance ===
                  "dark"
                  ? "dark"
                  : existingSettings.appearance ===
                      "system"
                    ? "system"
                    : "light",
              );

              setSettingsLoading(
                false,
              );
            }

            return;
          }

          console.error(
            "SETTINGS CREATE ERROR",
            {
              message:
                insertError.message,
              details:
                insertError.details,
              hint: insertError.hint,
              code: insertError.code,
            },
          );

          if (mounted) {
            setSettingsError(
              "Unable to initialize your settings.",
            );
            setSettingsLoading(
              false,
            );
          }

          return;
        }

        if (mounted) {
          setToggles({
            notifications:
              defaultSettings.notifications_enabled,
            location:
              defaultSettings.location_enabled,
          });

          setAppearance(
            defaultSettings.appearance,
          );

          setSettingsLoading(false);
        }

        return;
      }

      /*
       * ------------------------------------------------
       * EXISTING ROW IS SOFT-DELETED
       * ------------------------------------------------
       */

      if (data.deleted_at !== null) {
        const {
          data: restored,
          error: restoreError,
        } = await supabase
          .from("user_settings")
          .update({
            deleted_at: null,
            updated_at:
              new Date().toISOString(),
          })
          .eq("user_id", user.id)
          .select(
            `
              notifications_enabled,
              location_enabled,
              appearance
            `,
          )
          .single();

        if (
          restoreError ||
          !restored
        ) {
          console.error(
            "SETTINGS RESTORE ERROR",
            {
              message:
                restoreError?.message,
              details:
                restoreError?.details,
              hint:
                restoreError?.hint,
              code:
                restoreError?.code,
            },
          );

          if (mounted) {
            setSettingsError(
              "Unable to restore your settings.",
            );
            setSettingsLoading(
              false,
            );
          }

          return;
        }

        if (mounted) {
          setToggles({
            notifications:
              restored.notifications_enabled,
            location:
              restored.location_enabled,
          });

          setAppearance(
            restored.appearance ===
              "dark"
              ? "dark"
              : restored.appearance ===
                  "system"
                ? "system"
                : "light",
          );

          setSettingsLoading(false);
        }

        return;
      }

      /*
       * ------------------------------------------------
       * NORMAL ACTIVE SETTINGS
       * ------------------------------------------------
       */

      if (mounted) {
        setToggles({
          notifications:
            data.notifications_enabled,
          location:
            data.location_enabled,
        });

        setAppearance(
          data.appearance === "dark"
            ? "dark"
            : data.appearance === "system"
              ? "system"
              : "light",
        );

        setSettingsLoading(false);
      }
    }

    void loadSettings();

    return () => {
      mounted = false;
    };
  }, [setAppearance, supabase]);

  /*
   * ----------------------------------------------------
   * SAVE SETTINGS
   * ----------------------------------------------------
   */

  async function saveSettings(
    updates: Partial<UserSettings>,
  ) {
    setSettingsSaving(true);
    setSettingsError(null);

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      setSettingsError(
        "Unable to identify the current user.",
      );

      setSettingsSaving(false);
      return false;
    }

    const { error } = await supabase
      .from("user_settings")
      .update({
        ...updates,
        updated_at:
          new Date().toISOString(),
      })
      .eq("user_id", user.id)
      .is("deleted_at", null);

    if (error) {
      console.error(
        "SETTINGS SAVE ERROR",
        {
          message: error.message,
          details: error.details,
          hint: error.hint,
          code: error.code,
        },
      );

      setSettingsError(
        "Unable to save your setting. Please try again.",
      );

      setSettingsSaving(false);
      return false;
    }

    setSettingsSaving(false);
    return true;
  }

  /*
   * ----------------------------------------------------
   * TOGGLE SETTING
   * ----------------------------------------------------
   */

  async function toggleSetting(
    key: keyof SettingToggle,
  ) {
    if (
      settingsLoading ||
      settingsSaving
    ) {
      return;
    }

    const previousValue =
      toggles[key];

    const newValue =
      !previousValue;

    setToggles((current) => ({
      ...current,
      [key]: newValue,
    }));

    const success =
      await saveSettings(
        key === "notifications"
          ? {
              notifications_enabled:
                newValue,
            }
          : {
              location_enabled:
                newValue,
            },
      );

    if (!success) {
      setToggles((current) => ({
        ...current,
        [key]: previousValue,
      }));
    }
  }

  /*
   * ----------------------------------------------------
   * APPEARANCE
   * ----------------------------------------------------
   */

  async function changeAppearance(
    value: Appearance,
  ) {
    if (
      settingsLoading ||
      settingsSaving
    ) {
      return;
    }

    const previousAppearance =
      appearance;

    setAppearance(value);

    const success =
      await saveSettings({
        appearance: value,
      });

    if (!success) {
      setAppearance(
        previousAppearance,
      );
    }
  }

  /*
   * ----------------------------------------------------
   * PASSWORD
   * ----------------------------------------------------
   */

  function openPasswordForm() {
    setPasswordMessage(null);
    setPasswordError(null);
    setNewPassword("");
    setConfirmPassword("");
    setShowPasswordForm(true);
  }

  function closePasswordForm() {
    if (passwordLoading) return;

    setShowPasswordForm(false);
    setPasswordMessage(null);
    setPasswordError(null);
    setNewPassword("");
    setConfirmPassword("");
  }

  async function handlePasswordUpdate() {
    setPasswordMessage(null);
    setPasswordError(null);

    if (
      !newPassword ||
      !confirmPassword
    ) {
      setPasswordError(
        "Please enter and confirm your new password.",
      );
      return;
    }

    if (newPassword.length < 6) {
      setPasswordError(
        "Password must be at least 6 characters long.",
      );
      return;
    }

    if (
      newPassword !==
      confirmPassword
    ) {
      setPasswordError(
        "New password and confirmation do not match.",
      );
      return;
    }

    setPasswordLoading(true);

    const { error } =
      await supabase.auth.updateUser(
        {
          password:
            newPassword,
        },
      );

    setPasswordLoading(false);

    if (error) {
      setPasswordError(
        error.message,
      );
      return;
    }

    setPasswordMessage(
      "Your password has been updated successfully.",
    );

    setNewPassword("");
    setConfirmPassword("");

    window.setTimeout(() => {
      setShowPasswordForm(false);
      setPasswordMessage(null);
    }, 2500);
  }

  /*
   * ----------------------------------------------------
   * RENDER
   * ----------------------------------------------------
   */

  return (
    <section className="settings-page">
      <div className="settings-page__header">
        <div>
          <p className="settings-page__eyebrow">
            ACCOUNT & SYSTEM
          </p>

          <h2>Settings</h2>

          <p className="settings-page__description">
            Manage your LifeLynk AI dashboard
            preferences, security, and system
            settings.
          </p>
        </div>
      </div>

      {settingsError && (
        <div className="settings-notice settings-notice--error">
          {settingsError}
        </div>
      )}

      <div className="settings-page__content">
        {/* Preferences */}

        <section className="settings-card">
          <div className="settings-card__header">
            <div className="settings-card__icon">
              ⚙
            </div>

            <div>
              <h3>Preferences</h3>

              <p>
                Control how LifeLynk AI behaves
                for your account.
              </p>
            </div>
          </div>

          <div className="settings-list">
            {/* Notifications */}

            <div className="settings-row">
              <div className="settings-row__icon">
                🔔
              </div>

              <div className="settings-row__content">
                <strong>
                  Notifications
                </strong>

                <span>
                  Receive alerts and important
                  healthcare network
                  notifications.
                </span>
              </div>

              <button
                type="button"
                className={`settings-toggle ${
                  toggles.notifications
                    ? "settings-toggle--active"
                    : ""
                }`}
                aria-pressed={
                  toggles.notifications
                }
                disabled={
                  settingsLoading ||
                  settingsSaving
                }
                onClick={() =>
                  void toggleSetting(
                    "notifications",
                  )
                }
              >
                <span className="settings-toggle__track">
                  <span className="settings-toggle__thumb" />
                </span>

                <span className="settings-toggle__label">
                  {settingsLoading
                    ? "..."
                    : toggles.notifications
                      ? "On"
                      : "Off"}
                </span>
              </button>
            </div>

            {/* Appearance */}

            <div className="settings-row">
              <div className="settings-row__icon">
                ◐
              </div>

              <div className="settings-row__content">
                <strong>
                  Appearance
                </strong>

                <span>
                  Choose the dashboard
                  interface appearance.
                </span>
              </div>

              <select
                className="settings-value settings-value--select"
                value={appearance}
                disabled={
                  settingsLoading ||
                  settingsSaving
                }
                onChange={(event) =>
                  void changeAppearance(
                    event.target
                      .value as Appearance,
                  )
                }
                aria-label="Appearance"
              >
                <option value="light">
                  Light
                </option>

                <option value="dark">
                  Dark
                </option>

                <option value="system">
                  System
                </option>
              </select>
            </div>

            {/* Location */}

            <div className="settings-row">
              <div className="settings-row__icon">
                ⌖
              </div>

              <div className="settings-row__content">
                <strong>
                  Location Services
                </strong>

                <span>
                  Allow the dashboard to use
                  location-aware healthcare
                  network features.
                </span>
              </div>

              <button
                type="button"
                className={`settings-toggle ${
                  toggles.location
                    ? "settings-toggle--active"
                    : ""
                }`}
                aria-pressed={
                  toggles.location
                }
                disabled={
                  settingsLoading ||
                  settingsSaving
                }
                onClick={() =>
                  void toggleSetting(
                    "location",
                  )
                }
              >
                <span className="settings-toggle__track">
                  <span className="settings-toggle__thumb" />
                </span>

                <span className="settings-toggle__label">
                  {settingsLoading
                    ? "..."
                    : toggles.location
                      ? "On"
                      : "Off"}
                </span>
              </button>
            </div>
          </div>
        </section>

        {/* Security */}

        <section className="settings-card">
          <div className="settings-card__header">
            <div className="settings-card__icon">
              🔒
            </div>

            <div>
              <h3>Security</h3>

              <p>
                Manage your account security
                and password.
              </p>
            </div>
          </div>

          <div className="settings-list">
            <div className="settings-row settings-row--action">
              <div className="settings-row__icon">
                🔑
              </div>

              <div className="settings-row__content">
                <strong>
                  Password & Security
                </strong>

                <span>
                  Keep your LifeLynk AI account
                  secure by managing your
                  password.
                </span>
              </div>

              {!showPasswordForm && (
                <button
                  type="button"
                  className="settings-action"
                  onClick={
                    openPasswordForm
                  }
                >
                  Manage
                  <span>→</span>
                </button>
              )}
            </div>
          </div>

          {showPasswordForm && (
            <div className="settings-password">
              <div className="settings-password__header">
                <div>
                  <h4>
                    Change Password
                  </h4>

                  <p>
                    Enter a new password for
                    your LifeLynk AI account.
                  </p>
                </div>

                <button
                  type="button"
                  className="settings-password__close"
                  onClick={
                    closePasswordForm
                  }
                  disabled={
                    passwordLoading
                  }
                  aria-label="Close password form"
                >
                  ×
                </button>
              </div>

              <div className="settings-password__fields">
                <label>
                  <span>
                    New Password
                  </span>

                  <input
                    type="password"
                    value={newPassword}
                    onChange={(event) =>
                      setNewPassword(
                        event.target.value,
                      )
                    }
                    placeholder="Enter new password"
                    autoComplete="new-password"
                    disabled={
                      passwordLoading
                    }
                  />
                </label>

                <label>
                  <span>
                    Confirm New Password
                  </span>

                  <input
                    type="password"
                    value={
                      confirmPassword
                    }
                    onChange={(event) =>
                      setConfirmPassword(
                        event.target.value,
                      )
                    }
                    placeholder="Confirm new password"
                    autoComplete="new-password"
                    disabled={
                      passwordLoading
                    }
                  />
                </label>
              </div>

              {passwordError && (
                <div className="settings-password__error">
                  {passwordError}
                </div>
              )}

              {passwordMessage && (
                <div className="settings-password__success">
                  {passwordMessage}
                </div>
              )}

              <div className="settings-password__actions">
                <button
                  type="button"
                  className="settings-action"
                  onClick={
                    closePasswordForm
                  }
                  disabled={
                    passwordLoading
                  }
                >
                  Cancel
                </button>

                <button
                  type="button"
                  className="settings-action settings-action--primary"
                  onClick={
                    handlePasswordUpdate
                  }
                  disabled={
                    passwordLoading
                  }
                >
                  {passwordLoading
                    ? "Updating..."
                    : "Update Password"}
                </button>
              </div>
            </div>
          )}
        </section>

        {/* About */}

        <section className="settings-card">
          <div className="settings-card__header">
            <div className="settings-card__icon">
              ℹ
            </div>

            <div>
              <h3>About</h3>

              <p>
                Information about the
                LifeLynk AI platform.
              </p>
            </div>
          </div>

          <div className="settings-list">
            <div className="settings-row">
              <div className="settings-row__icon">
                ♥
              </div>

              <div className="settings-row__content">
                <strong>
                  About LifeLynk AI
                </strong>

                <span>
                  Pakistan&apos;s digital
                  blood infrastructure for
                  availability and emergency
                  response.
                </span>
              </div>

              <button
                type="button"
                className="settings-action"
                onClick={() =>
                  setShowAbout(
                    (current) =>
                      !current,
                  )
                }
              >
                {showAbout
                  ? "Close"
                  : "View"}

                <span>
                  {showAbout
                    ? "↑"
                    : "→"}
                </span>
              </button>
            </div>

            {showAbout && (
              <div className="settings-about">
                <div className="settings-about__logo">
                  <Image
                    src="/images/app_icon.png"
                    alt="LifeLynk AI"
                    width={64}
                    height={64}
                  />
                </div>

                <div>
                  <h4>
                    LifeLynk AI
                  </h4>

                  <p>
                    LifeLynk AI connects
                    hospitals, blood banks,
                    donors, patients, and
                    healthcare authorities
                    through a unified digital
                    healthcare network.
                  </p>
                </div>
              </div>
            )}

            <div className="settings-row">
              <div className="settings-row__icon">
                #
              </div>

              <div className="settings-row__content">
                <strong>
                  App Version
                </strong>

                <span>
                  Current LifeLynk AI web
                  dashboard version.
                </span>
              </div>

              <span className="settings-version">
                1.0.0
              </span>
            </div>
          </div>
        </section>
      </div>
    </section>
  );
}