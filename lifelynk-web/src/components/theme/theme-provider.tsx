"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";

export type Appearance =
  | "light"
  | "dark"
  | "system";

interface ThemeContextValue {
  appearance: Appearance;
  setAppearance: (
    appearance: Appearance,
  ) => void;
}

const ThemeContext =
  createContext<
    ThemeContextValue | undefined
  >(undefined);

const STORAGE_KEY =
  "lifelynk-appearance";

function getSystemTheme():
  | "light"
  | "dark" {
  if (
    typeof window !== "undefined" &&
    window.matchMedia(
      "(prefers-color-scheme: dark)",
    ).matches
  ) {
    return "dark";
  }

  return "light";
}

function getStoredAppearance():
  | Appearance
  | null {
  if (
    typeof window === "undefined"
  ) {
    return null;
  }

  const stored =
    window.localStorage.getItem(
      STORAGE_KEY,
    );

  if (
    stored === "light" ||
    stored === "dark" ||
    stored === "system"
  ) {
    return stored;
  }

  return null;
}

function resolveTheme(
  appearance: Appearance,
): "light" | "dark" {
  if (appearance === "system") {
    return getSystemTheme();
  }

  return appearance;
}

function applyTheme(
  appearance: Appearance,
) {
  if (
    typeof document === "undefined"
  ) {
    return;
  }

  const resolvedTheme =
    resolveTheme(appearance);

  const root =
    document.documentElement;

  root.dataset.theme =
    resolvedTheme;

  root.classList.toggle(
    "dark",
    resolvedTheme === "dark",
  );

  root.style.colorScheme =
    resolvedTheme;
}

export function ThemeProvider({
  children,
  initialAppearance = "light",
}: {
  children: ReactNode;
  initialAppearance?: Appearance;
}) {
  const [
    appearance,
    setAppearanceState,
  ] = useState<Appearance>(
    initialAppearance,
  );

  /*
   * Restore locally remembered theme.
   */
  useEffect(() => {
    const stored =
      getStoredAppearance();

    if (stored) {
      setAppearanceState(stored);
      applyTheme(stored);
      return;
    }

    applyTheme(initialAppearance);
  }, [initialAppearance]);

  /*
   * Apply whenever appearance changes.
   */
  useEffect(() => {
    applyTheme(appearance);
  }, [appearance]);

  /*
   * React to operating-system theme
   * changes when "system" is selected.
   */
  useEffect(() => {
    if (appearance !== "system") {
      return;
    }

    const mediaQuery =
      window.matchMedia(
        "(prefers-color-scheme: dark)",
      );

    const handleChange = () => {
      applyTheme("system");
    };

    mediaQuery.addEventListener(
      "change",
      handleChange,
    );

    return () => {
      mediaQuery.removeEventListener(
        "change",
        handleChange,
      );
    };
  }, [appearance]);

  function setAppearance(
    value: Appearance,
  ) {
    setAppearanceState(value);

    if (
      typeof window !== "undefined"
    ) {
      window.localStorage.setItem(
        STORAGE_KEY,
        value,
      );
    }

    applyTheme(value);
  }

  return (
    <ThemeContext.Provider
      value={{
        appearance,
        setAppearance,
      }}
    >
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const context =
    useContext(ThemeContext);

  if (!context) {
    throw new Error(
      "useTheme must be used inside ThemeProvider",
    );
  }

  return context;
}