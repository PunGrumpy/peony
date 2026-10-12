import type { VariantProps } from "class-variance-authority";
import { cn } from "cn";

import { button } from "./button";
import { AppleIcon, GitHubIcon } from "./icons";
import { site } from "@/lib/site";

type Size = Pick<VariantProps<typeof button>, "size">;

// An icon carries its own air, so the side that holds it gets less padding.
export const DownloadButton = ({ size }: Size) => (
  <a
    href={site.download}
    className={cn(button({ intent: "primary", size }), "pl-3")}
  >
    <AppleIcon className="-mt-0.5 size-4" />
    Download for Mac
  </a>
);

export const GitHubButton = ({ size }: Size) => (
  <a
    href={site.repo}
    className={cn(button({ intent: "secondary", size }), "pl-2.5")}
  >
    <GitHubIcon className="size-4" />
    GitHub
  </a>
);
