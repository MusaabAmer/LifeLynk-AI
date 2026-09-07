"use client";

import Image from "next/image";
import { useEffect } from "react";
import { useRouter } from "next/navigation";

import { createClient } from "@/lib/supabase/client";

export default function HomePage() {
  const router = useRouter();

  useEffect(() => {
    let mounted = true;

    async function initializeApp() {
      const supabase = createClient();

      const sessionPromise = supabase.auth.getUser();

      // Keep the splash visible briefly.
      await new Promise((resolve) => setTimeout(resolve, 3000));

      const {
        data: { user },
      } = await sessionPromise;

      if (!mounted) return;

      if (user) {
        router.replace("/dashboard");
      } else {
        router.replace("/login");
      }
    }

    initializeApp();

    return () => {
      mounted = false;
    };
  }, [router]);

  return (
    <main className="lifelynk-splash">
      <div className="lifelynk-splash__glow lifelynk-splash__glow--one" />
      <div className="lifelynk-splash__glow lifelynk-splash__glow--two" />

      <div className="lifelynk-splash__content">
        <div className="lifelynk-splash__logo-container">
          <Image
            src="/images/app_icon.png"
            alt="LifeLynk AI"
            width={128}
            height={128}
            className="lifelynk-splash__logo"
          />
        </div>

        <h1 className="lifelynk-splash__title">
          LifeLynk AI
        </h1>

        <p className="lifelynk-splash__subtitle">
          Healthcare Network
        </p>

        <div
          className="lifelynk-splash__loader"
          aria-label="Loading"
        >
          <span />
          <span />
          <span />
        </div>

        <p className="lifelynk-splash__status">
          Connecting you to better healthcare
        </p>
      </div>
    </main>
  );
}