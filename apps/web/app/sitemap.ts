import type { MetadataRoute } from "next";

import { url } from "@/lib/url";
import { getReleases } from "@/lib/changelog";

const sitemap = async (): Promise<MetadataRoute.Sitemap> => {
  const releases = await getReleases();
  const latest = releases.at(0)?.date;
  const pages = ["", "/changelog", "/privacy", "/terms", "/legal"].map(
    (path) => ({
      lastModified: path === "" || path === "/changelog" ? latest : undefined,
      url: `${url}${path}`,
    })
  );
  const versions = releases.map((release) => ({
    lastModified: release.date,
    url: `${url}/changelog/${release.slug}`,
  }));
  return [...pages, ...versions];
};

export default sitemap;
