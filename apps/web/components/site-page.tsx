import type { ReactNode } from "react";

import { SiteFooter } from "./site-footer";
import { SiteHeader } from "./site-header";

// The header, the two rails every page runs between, and the footer.
export const SitePage = ({ children }: { children: ReactNode }) => (
  <>
    <SiteHeader />
    <div className="mx-auto max-w-[1280px] sm:px-6">
      <div className="border-gray-400 sm:border-x">
        <main>{children}</main>
        <SiteFooter />
      </div>
    </div>
  </>
);

// A narrow column for pages that are mostly reading.
export const Article = ({ children }: { children: ReactNode }) => (
  <article className="border-gray-400 border-b px-6 py-16 sm:px-10 sm:py-24">
    <div className="max-w-[680px]">{children}</div>
  </article>
);

export const Title = ({ children }: { children: ReactNode }) => (
  <h1 className="mt-3 font-serif text-[clamp(2.25rem,5vw,3.25rem)] leading-[1.08] font-medium tracking-[-0.035em]">
    {children}
  </h1>
);
