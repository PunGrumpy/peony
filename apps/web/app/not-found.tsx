import type { Metadata } from "next";
import Link from "next/link";

import { button } from "@/components/button";
import { Label } from "@/components/section";
import { Article, SitePage, Title } from "@/components/site-page";

export const metadata: Metadata = {
  title: "Page not found",
};

const NotFound = () => (
  <SitePage>
    <Article>
      <Label>404</Label>
      <Title>No route to this page.</Title>
      <p className="text-gray-900 mt-4 max-w-[34rem] text-[16px] leading-[1.5]">
        The address may have changed, or it never existed.
      </p>
      <Link href="/" className={`${button({ intent: "secondary" })} mt-8`}>
        Back to Peony
      </Link>
    </Article>
  </SitePage>
);

export default NotFound;
