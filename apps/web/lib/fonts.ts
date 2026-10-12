import { cn } from "cn";
import {
  Geist as createSans,
  Geist_Mono as createMono,
  Newsreader as createSerif,
} from "next/font/google";

const sans = createSans({
  display: "swap",
  subsets: ["latin"],
  variable: "--font-geist",
  weight: "variable",
});

const mono = createMono({
  display: "swap",
  subsets: ["latin"],
  variable: "--font-geist-mono",
  weight: "variable",
});

// Headlines only, so the italic is left out.
const serif = createSerif({
  display: "swap",
  style: "normal",
  subsets: ["latin"],
  variable: "--font-newsreader",
  weight: "variable",
});

export const fonts = cn(
  "touch-manipulation font-sans antialiased [font-synthesis-weight:none]",
  sans.variable,
  mono.variable,
  serif.variable
);
