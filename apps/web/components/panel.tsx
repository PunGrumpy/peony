import { cn } from "cn";
import type { StaticImageData } from "next/image";
import Image from "next/image";

import connectingDark from "../../macos/Design/snapshots/panel-connecting-dark.png";
import connectingLight from "../../macos/Design/snapshots/panel-connecting-light.png";
import failedDark from "../../macos/Design/snapshots/panel-failed-certificate-dark.png";
import failedLight from "../../macos/Design/snapshots/panel-failed-certificate-light.png";
import liveDark from "../../macos/Design/snapshots/panel-live-dark.png";
import liveLight from "../../macos/Design/snapshots/panel-live-light.png";
import offDark from "../../macos/Design/snapshots/panel-off-dark.png";
import offLight from "../../macos/Design/snapshots/panel-off-light.png";

export type PanelName = "off" | "connecting" | "live" | "failed";

// Rendered by `bun run snapshots`, so the site shows the panel the app actually draws.
const snapshots: Record<
  PanelName,
  { alt: string; dark: StaticImageData; light: StaticImageData }
> = {
  connecting: {
    alt: "Peony's panel while connecting to Work, with the steps so far",
    dark: connectingDark,
    light: connectingLight,
  },
  failed: {
    alt: "Peony's panel after a connection failed, naming the certificate problem",
    dark: failedDark,
    light: failedLight,
  },
  live: {
    alt: "Peony's panel, connected to Work, with reachable hosts and their latency",
    dark: liveDark,
    light: liveLight,
  },
  off: {
    alt: "Peony's panel with four routes and nothing connected",
    dark: offDark,
    light: offLight,
  },
};

// The snapshots are 2x. Both themes stay lazy so only the one in use is fetched.
export const Panel = ({
  className,
  name,
}: {
  className?: string;
  name: PanelName;
}) => {
  const { alt, dark, light } = snapshots[name];
  const shared = {
    className:
      "outline-gray-alpha-400 h-auto w-full rounded-[14px] outline-1 -outline-offset-1",
    sizes: "320px",
  };
  return (
    <div
      className={cn(
        "w-[320px] max-w-full rounded-[14px] shadow-[0_1px_2px_rgb(0_0_0/0.1),0_24px_48px_-12px_rgb(0_0_0/0.35)]",
        className
      )}
    >
      <Image
        {...shared}
        src={light}
        alt={alt}
        className={cn(shared.className, "dark:hidden")}
      />
      <Image
        {...shared}
        src={dark}
        alt={alt}
        className={cn(shared.className, "hidden dark:block")}
      />
    </div>
  );
};
