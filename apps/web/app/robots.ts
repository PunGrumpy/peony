import type { MetadataRoute } from "next";

import { site } from "@/components/site";

const robots = (): MetadataRoute.Robots => ({
  rules: { allow: "/", userAgent: "*" },
  sitemap: `${site.url}/sitemap.xml`,
});

export default robots;
