import Link from "next/link";

import { DownloadButton, GitHubButton } from "./buttons";
import { Logo } from "./logo";

const links = [
  { href: "/#states", label: "States" },
  { href: "/#security", label: "Security" },
  { href: "/#install", label: "Install" },
  { href: "/changelog", label: "Changelog" },
];

export const SiteHeader = () => (
  <header className="border-gray-400 border-b">
    <div className="mx-auto grid h-16 max-w-[1280px] grid-cols-[1fr_auto_1fr] items-center px-6">
      <Link href="/" aria-label="Peony home" className="press justify-self-start">
        <Logo />
      </Link>
      <nav aria-label="Main" className="hidden items-center md:flex">
        {links.map((link) => (
          <Link
            key={link.href}
            href={link.href}
            className="text-gray-900 hover:text-gray-1000 px-3 py-1.5 text-[14px]"
          >
            {link.label}
          </Link>
        ))}
      </nav>
      <div className="col-start-3 flex items-center gap-2 justify-self-end">
        <span className="hidden sm:block">
          <GitHubButton size="small" />
        </span>
        <DownloadButton size="small" />
      </div>
    </div>
  </header>
);
