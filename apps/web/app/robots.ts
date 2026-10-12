import type { MetadataRoute } from "next";

import { url } from "@/lib/url";

const robots = (): MetadataRoute.Robots => ({
  rules: {
    allow: ["/"],
    other: {
      "Content-Signal": "search=yes, ai-input=yes, ai-train=no",
    },
    userAgent: "*",
  },
  sitemap: `${url}/sitemap.xml`,
});

export default robots;
