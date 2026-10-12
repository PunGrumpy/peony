import type { ReactNode } from "react";

import { SiteFooter } from "./site-footer";
import { SiteHeader } from "./site-header";

// The header, the two rails every page runs between, and the footer.
// The rails run to the bottom of the window, so a short page keeps its frame and its footer stays down.
export const SitePage = ({ children }: { children: ReactNode }) => (
  <>
    <SiteHeader />
    <div className="mx-auto flex w-full max-w-[1280px] flex-1 flex-col sm:px-6">
      <div className="border-gray-400 flex flex-1 flex-col sm:border-x">
        <main className="flex flex-1 flex-col">{children}</main>
        <SiteFooter />
      </div>
    </div>
  </>
);

// A narrow column for pages that are mostly reading. It takes the height a short page leaves over.
export const Article = ({ children }: { children: ReactNode }) => (
  <article className="border-gray-400 flex-1 border-b px-6 py-16 sm:px-10 sm:py-24">
    <div className="max-w-[680px]">{children}</div>
  </article>
);

export const Title = ({ children }: { children: ReactNode }) => (
  <h1 className="mt-3 font-serif text-[clamp(2.25rem,5vw,3.25rem)] leading-[1.08] font-medium tracking-[-0.035em]">
    {children}
  </h1>
);
