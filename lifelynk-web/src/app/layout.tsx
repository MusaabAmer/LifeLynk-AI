import type { Metadata, Viewport } from "next";

import "./globals.css";

import { ThemeProvider } from "@/components/theme/theme-provider";

export const metadata: Metadata = {
  title: {
    default: "LifeLynk AI | Healthcare Network",
    template: "%s | LifeLynk AI",
  },

  description:
    "LifeLynk AI — Pakistan's digital healthcare network for real-time blood availability, emergency response, donors, hospitals, and blood banks.",

  applicationName: "LifeLynk AI",

  keywords: [
    "LifeLynk AI",
    "LifeLynk",
    "blood availability",
    "blood bank",
    "hospital",
    "emergency response",
    "blood donors",
    "healthcare",
    "Pakistan",
  ],

  manifest: "/manifest.webmanifest",

  icons: {
    icon: "/images/lifelynk-logo.png",
    apple: "/images/lifelynk-logo.png",
  },

  robots: {
    index: false,
    follow: false,
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#C62828",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      data-scroll-behavior="smooth"
      suppressHydrationWarning
    >
      <body>
        <ThemeProvider>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}