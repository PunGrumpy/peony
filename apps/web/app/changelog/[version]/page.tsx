import { cn } from "cn";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { button } from "@/components/button";
import { GitHubIcon } from "@/components/icons";
import { renderInline } from "@/components/inline-markdown";
import { Prose } from "@/components/prose";
import { Article, SitePage, Title } from "@/components/site-page";
import { getReleases, oneLine } from "@/lib/changelog";

export const dynamicParams = false;

export const generateStaticParams = async () => {
  const releases = await getReleases();
  return releases.map((release) => ({ version: release.slug }));
};

export const generateMetadata = async ({
  params,
}: PageProps<"/changelog/[version]">): Promise<Metadata> => {
  const [{ version }, releases] = await Promise.all([params, getReleases()]);
  const release = releases.find((item) => item.slug === version);
  return release
    ? {
        description: oneLine(release),
        title: { absolute: `Peony ${release.version}` },
      }
    : {};
};

const fullDate = new Intl.DateTimeFormat("en-US", {
  day: "numeric",
  month: "long",
  timeZone: "UTC",
  year: "numeric",
});

const Page = async ({ params }: PageProps<"/changelog/[version]">) => {
  const [{ version }, releases] = await Promise.all([params, getReleases()]);
  const index = releases.findIndex((item) => item.slug === version);
  const release = releases[index];
  if (!release) {
    notFound();
  }
  const newer = releases[index - 1];
  const older = releases[index + 1];

  return (
    <SitePage>
      <Article>
        <div className="text-gray-900 flex items-center gap-3 text-[13px]">
          <Link href="/changelog" className="hover:text-gray-1000">
            ‹ Changelog
          </Link>
          {release.date && (
            <time dateTime={release.date} className="tabular-nums">
              {fullDate.format(new Date(release.date))}
            </time>
          )}
          <span className="bg-gray-200 rounded-md px-2 py-0.5 text-[12px]">
            {release.tag}
          </span>
        </div>
        <Title>Peony {release.version}</Title>
        <Prose className="mt-8 gap-8">
          {release.summary.map((paragraph) => (
            <p key={paragraph}>{renderInline(paragraph)}</p>
          ))}
          {release.sections.map((section) => (
            <section key={section.title} className="flex flex-col gap-3">
              <h2 className="text-gray-1000 text-[17px] font-medium tracking-[-0.02em]">
                {section.title}
              </h2>
              <ul>
                {section.items.map((item) => (
                  <li key={item}>{renderInline(item)}</li>
                ))}
              </ul>
            </section>
          ))}
        </Prose>
        <div className="mt-10">
          <a
            href={release.url}
            className={cn(button({ intent: "secondary" }), "pl-2.5")}
          >
            <GitHubIcon className="size-4" />
            Download {release.version} from GitHub
          </a>
        </div>
        {(older || newer) && (
          <nav
            aria-label="Other releases"
            className="border-gray-400 mt-16 grid grid-cols-2 gap-4 border-t pt-6 text-[14px]"
          >
            {older ? (
              <Link
                href={`/changelog/${older.slug}`}
                className="flex flex-col gap-0.5"
              >
                <span className="text-gray-900 text-[12px]">Older</span>
                <span className="font-medium">v{older.version}</span>
              </Link>
            ) : (
              <span />
            )}
            {newer && (
              <Link
                href={`/changelog/${newer.slug}`}
                className="flex flex-col items-end gap-0.5 text-right"
              >
                <span className="text-gray-900 text-[12px]">Newer</span>
                <span className="font-medium">v{newer.version}</span>
              </Link>
            )}
          </nav>
        )}
      </Article>
    </SitePage>
  );
};

export default Page;
