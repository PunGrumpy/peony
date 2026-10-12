import type { ReactNode } from "react";

import { Prose } from "./prose";
import { Label } from "./section";
import { Article, SitePage, Title } from "./site-page";

export const LegalPage = ({
  title,
  updated,
  children,
}: {
  title: string;
  updated: string;
  children: ReactNode;
}) => (
  <SitePage>
    <Article>
      <Label>Last updated {updated}</Label>
      <Title>{title}</Title>
      <Prose className="mt-10 gap-10">{children}</Prose>
    </Article>
  </SitePage>
);

export const LegalSection = ({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) => (
  <section className="flex flex-col gap-3">
    <h2 className="text-gray-1000 text-[17px] font-medium tracking-[-0.02em]">
      {title}
    </h2>
    {children}
  </section>
);
