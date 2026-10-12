import type { MetadataRoute } from "next";

import { site } from "@/lib/site";

const manifest = (): MetadataRoute.Manifest => ({
  background_color: "#fcfbfb",
  description: site.description,
  display: "standalone",
  icons: [
    {
      sizes: "256x256",
      src: "/icon.png",
      type: "image/png",
    },
    {
      sizes: "180x180",
      src: "/apple-icon.png",
      type: "image/png",
    },
  ],
  lang: "en",
  name: `${site.name} — ${site.tagline}`,
  short_name: site.name,
  start_url: "/",
  theme_color: "#fcfbfb",
});

export default manifest;
