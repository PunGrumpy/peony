import type { Metadata } from "next";
import Link from "next/link";

import { Label } from "@/components/section";
import { Article, SitePage, Title } from "@/components/site-page";
import { getReleases, oneLine } from "@/lib/changelog";
import type { Release } from "@/lib/changelog";

export const metadata: Metadata = {
  description:
    "Every Peony release, newest first, with what changed in each one.",
  title: "Changelog",
};

const monthDay = new Intl.DateTimeFormat("en-US", {
  day: "numeric",
  month: "long",
  timeZone: "UTC",
});

const byYear = (releases: Release[]) => {
  const groups: { year: string; releases: Release[] }[] = [];
  for (const release of releases) {
    const year = release.date
      ? String(new Date(release.date).getUTCFullYear())
      : "";
    const last = groups.at(-1);
    if (last?.year === year) {
      last.releases.push(release);
    } else {
      groups.push({ releases: [release], year });
    }
  }
  return groups;
};

const Page = async () => {
  const releases = await getReleases();

  return (
    <SitePage>
      <Article>
        <Label>Releases</Label>
        <Title>Changelog</Title>
        <p className="text-gray-900 mt-4 max-w-[34rem] text-[16px] leading-[1.5]">
          Every Peony release, newest first, with the same notes as its GitHub
          release.
        </p>
        <div className="border-gray-400 mt-12 border-t">
          {byYear(releases).map((group) => (
            <section
              key={group.year || "undated"}
              className="border-gray-400 grid border-b md:grid-cols-[96px_minmax(0,1fr)] md:gap-x-6"
            >
              <h2 className="text-gray-900 pt-4 text-[14px] tabular-nums max-md:pb-1">
                {group.year}
              </h2>
              <ol className="divide-gray-400 divide-y">
                {group.releases.map((release) => (
                  <li key={release.version}>
                    <Link
                      href={`/changelog/${release.slug}`}
                      className="group flex items-center gap-3 py-3.5"
                    >
                      <span className="shrink-0 text-[15px] font-medium tabular-nums">
                        v{release.version}
                      </span>
                      <span className="text-gray-900 group-hover:text-gray-1000 min-w-0 flex-1 truncate text-[14px] max-sm:hidden">
                        {oneLine(release)}
                      </span>
                      <span className="bg-gray-200 text-gray-900 ml-auto shrink-0 rounded-md px-2 py-0.5 text-[12px]">
                        {release.tag}
                      </span>
                      {release.date && (
                        <time
                          dateTime={release.date}
                          className="text-gray-900 w-28 shrink-0 text-right text-[13px] tabular-nums"
                        >
                          {monthDay.format(new Date(release.date))}
                        </time>
                      )}
                    </Link>
                  </li>
                ))}
              </ol>
            </section>
          ))}
        </div>
      </Article>
    </SitePage>
  );
};

export default Page;
