import "./globals.css";
import type { Metadata, Viewport } from "next";

import { fonts } from "@/lib/fonts";
import { site } from "@/lib/site";
import { url } from "@/lib/url";

export const viewport: Viewport = {
  colorScheme: "light dark",
  initialScale: 1,
  themeColor: [
    { color: "#fcfbfb", media: "(prefers-color-scheme: light)" },
    { color: "#171415", media: "(prefers-color-scheme: dark)" },
  ],
  viewportFit: "cover",
  width: "device-width",
};

export const metadata: Metadata = {
  alternates: {
    canonical: "./",
  },
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: site.name,
  },
  applicationName: site.name,
  authors: [site.author],
  category: "technology",
  creator: site.author.name,
  description: site.description,
  formatDetection: { telephone: false },
  generator: "Next.js",
  keywords: [
    "Peony",
    "VPN switcher",
    "macOS menu bar app",
    "FortiGate",
    "openfortivpn",
    "AnyConnect",
    "GlobalProtect",
    "openconnect",
    "WireGuard",
    "NetBird",
  ],
  metadataBase: new URL(url),
  openGraph: {
    locale: "en_US",
    siteName: site.name,
    type: "website",
    url: "./",
  },
  publisher: site.author.name,
  robots: {
    follow: true,
    googleBot: {
      follow: true,
      index: true,
      "max-image-preview": "large",
      "max-snippet": -1,
      "max-video-preview": -1,
    },
    index: true,
  },
  title: {
    default: `${site.name} — ${site.tagline}`,
    template: `%s · ${site.name}`,
  },
  twitter: {
    card: "summary_large_image",
    creator: site.author.handle,
    site: site.author.handle,
  },
};


const RootLayout = ({ children }: LayoutProps<"/">) => (
  <html lang="en" className={fonts}>
    <body className="min-h-dvh p-[5px]">{children}</body>
  </html>
);

export default RootLayout;
