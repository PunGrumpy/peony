import { cn } from "cn";
import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono, Newsreader } from "next/font/google";

import { url } from "@/lib/url";

import "./globals.css";

const geist = Geist({ subsets: ["latin"], variable: "--font-geist" });

const geistMono = Geist_Mono({
  subsets: ["latin"],
  variable: "--font-geist-mono",
});

const newsreader = Newsreader({
  subsets: ["latin"],
  variable: "--font-newsreader",
});

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
  <html
    lang="en"
    className={cn(geist.variable, geistMono.variable, newsreader.variable)}
  >
    <body className="min-h-dvh p-[5px] font-sans">{children}</body>
  </html>
);

export default RootLayout;
