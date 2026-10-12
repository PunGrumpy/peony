import type { MetadataRoute } from "next";

import { url } from "@/lib/url";

const robots = (): MetadataRoute.Robots => ({
  rules: { allow: "/", userAgent: "*" },
  sitemap: `${url}/sitemap.xml`,
});

export default robots;
