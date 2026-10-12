import type { Metadata, Viewport } from "next";

import { fonts } from "@/lib/fonts";
import { url } from "@/lib/url";

import "./globals.css";

export const metadata: Metadata = {
  applicationName: "Peony",
  description:
    "A menu bar app that switches between your VPNs and keeps only one on, so their routes and DNS never fight. Then it checks the hosts you care about.",
  metadataBase: new URL(url),
  title: {
    default: "Peony — One VPN at a time, from the menu bar",
    template: "%s · Peony",
  },
};

export const viewport: Viewport = {
  themeColor: [
    { color: "#fcfbfb", media: "(prefers-color-scheme: light)" },
    { color: "#171415", media: "(prefers-color-scheme: dark)" },
  ],
};

const RootLayout = ({ children }: LayoutProps<"/">) => (
  <html lang="en" className={fonts}>
    <body className="min-h-dvh p-[5px]">{children}</body>
  </html>
);

export default RootLayout;
