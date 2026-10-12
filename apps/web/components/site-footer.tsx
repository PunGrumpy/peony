import Link from "next/link";
import type { ReactNode } from "react";

import { Logo } from "./logo";
import { site } from "./site";

const FooterLink = ({
  href,
  children,
}: {
  href: string;
  children: ReactNode;
}) => (
  <Link href={href} className="text-gray-900 hover:text-gray-1000">
    {children}
  </Link>
);

const FooterColumn = ({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) => (
  <div className="flex flex-col gap-2">
    <p className="font-medium">{title}</p>
    {children}
  </div>
);

export const SiteFooter = () => (
  <footer className="px-6 pt-10 pb-12 sm:px-10">
    <div className="flex flex-col gap-8 md:flex-row md:justify-between">
      <div>
        <Logo />
        <p className="text-gray-900 mt-3 text-[13px]">
          Grown by{" "}
          <a
            href={site.author.url}
            className="text-gray-1000 font-medium hover:underline"
          >
            {site.author.name}
          </a>
          .
        </p>
      </div>
      <nav
        aria-label="Footer"
        className="grid grid-cols-2 gap-x-16 gap-y-8 text-[14px] sm:grid-cols-3"
      >
        <FooterColumn title="Product">
          <FooterLink href="/#states">States</FooterLink>
          <FooterLink href="/changelog">Changelog</FooterLink>
          <FooterLink href={site.download}>Download</FooterLink>
        </FooterColumn>
        <FooterColumn title="Source">
          <FooterLink href={site.repo}>GitHub</FooterLink>
          <FooterLink href={site.releases}>Releases</FooterLink>
        </FooterColumn>
        <FooterColumn title="Legal">
          <FooterLink href="/privacy">Privacy</FooterLink>
          <FooterLink href="/terms">Terms</FooterLink>
          <FooterLink href="/legal">Licenses</FooterLink>
        </FooterColumn>
      </nav>
    </div>
    <p className="text-gray-900 mt-10 text-[12px]">
      VPN names and logos are trademarks of their owners.
    </p>
  </footer>
);
