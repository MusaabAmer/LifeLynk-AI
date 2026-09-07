import type { NextConfig } from "next";

const SUPABASE_ORIGIN =
  "https://aybwxfhcqnpojhjybrmr.supabase.co";

const SUPABASE_WS_ORIGIN =
  "wss://aybwxfhcqnpojhjybrmr.supabase.co";

const OPENSTREETMAP_ORIGIN =
  "https://www.openstreetmap.org";

const nextConfig: NextConfig = {
  reactCompiler: true,

  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          {
            key: "X-Content-Type-Options",
            value: "nosniff",
          },

          {
            key: "X-Frame-Options",
            value: "DENY",
          },

          {
            key: "Referrer-Policy",
            value:
              "strict-origin-when-cross-origin",
          },

          {
            key: "Permissions-Policy",
            value:
              "camera=(), microphone=(), geolocation=(), payment=()",
          },

          {
            key: "Content-Security-Policy",
            value: [
              "default-src 'self'",

              "script-src 'self' 'unsafe-inline' 'unsafe-eval'",

              "style-src 'self' 'unsafe-inline'",

              /*
               * Images required by the application.
               *
               * OSM itself is loaded inside the iframe, so its
               * internal map assets are controlled by OSM's page.
               */
              "img-src 'self' data: blob:",

              "font-src 'self'",

              /*
               * Supabase REST + Realtime.
               */
              `connect-src 'self' ${SUPABASE_ORIGIN} ${SUPABASE_WS_ORIGIN}`,

              /*
               * OpenStreetMap is explicitly allowed to be
               * embedded by the Emergency SOS details modal.
               */
              `frame-src 'self' ${OPENSTREETMAP_ORIGIN}`,

              /*
               * Prevent this application from being embedded
               * by other websites.
               */
              "frame-ancestors 'none'",
            ].join("; "),
          },
        ],
      },
    ];
  },
};

export default nextConfig;

