import { readFileSync } from "node:fs";
import path from "node:path";

import { site } from "@/components/site";

export interface ChangelogSection {
  title: string;
  items: string[];
}

interface GitHubRelease {
  tag_name?: string;
  published_at?: string | null;
}

export interface Release {
  version: string;
  slug: string;
  summary: string[];
  sections: ChangelogSection[];
  tag: string;
  date?: string;
  url: string;
}

const VERSION_HEADING = /^## /mu;
const CONTINUATION = /^ {2,}\S/u;
const CHANGESET_HASH = /^[0-9a-f]{7,40}:\s+/u;
const MARKDOWN_MARKS = /\*\*|`|\[|\]\([^)]*\)/gu;
const SENTENCE_END = /[.!?](?:\s|$)/u;

const sectionTitles = new Map([
  ["Major Changes", "Breaking changes"],
  ["Minor Changes", "Features"],
  ["Patch Changes", "Fixes"],
]);

const tagOrder = ["Breaking changes", "Features", "Fixes"];

const repository = site.repo.replace("https://github.com/", "");

const parseRelease = (block: string): Release => {
  const [heading = "", ...lines] = block.split("\n");
  const version = heading.trim();
  const summary: string[] = [];
  const sections: ChangelogSection[] = [];
  let paragraph: string[] = [];
  let items: string[] | undefined;

  const endParagraph = () => {
    if (paragraph.length > 0) {
      summary.push(paragraph.join(" "));
      paragraph = [];
    }
  };

  for (const line of lines) {
    if (line.startsWith("### ")) {
      endParagraph();
      const title = line.slice(4).trim();
      items = [];
      sections.push({ items, title: sectionTitles.get(title) ?? title });
    } else if (line.startsWith("- ") && items) {
      items.push(line.slice(2).replace(CHANGESET_HASH, ""));
    } else if (CONTINUATION.test(line) && items && items.length > 0) {
      items[items.length - 1] += ` ${line.trim()}`;
    } else if (line.trim() === "") {
      endParagraph();
    } else if (!items) {
      paragraph.push(line.trim());
    }
  }
  endParagraph();

  const titles = new Set(sections.map((section) => section.title));
  return {
    sections,
    slug: version.replaceAll(".", "-"),
    summary,
    tag: tagOrder.find((title) => titles.has(title)) ?? "Release",
    url: `${site.repo}/releases/tag/v${version}`,
    version,
  };
};

const readChangelog = () =>
  readFileSync(path.join(process.cwd(), "../macos/CHANGELOG.md"), "utf-8");

// The changelog has no dates, so they come from the GitHub releases. Without them the pages still build.
const releaseDates = async () => {
  const dates = new Map<string, string>();
  try {
    const response = await fetch(
      `https://api.github.com/repos/${repository}/releases?per_page=100`,
      {
        cache: "force-cache",
        headers: { Accept: "application/vnd.github+json" },
      }
    );
    if (!response.ok) {
      return dates;
    }
    const releases: GitHubRelease[] = await response.json();
    for (const { tag_name: tagName, published_at: publishedAt } of releases) {
      if (tagName && publishedAt) {
        dates.set(tagName.replace(/^v/u, ""), publishedAt);
      }
    }
  } catch {
    return dates;
  }
  return dates;
};

export const getReleases = async (): Promise<Release[]> => {
  const dates = await releaseDates();
  return readChangelog()
    .split(VERSION_HEADING)
    .slice(1)
    .map((block) => {
      const release = parseRelease(block);
      return { ...release, date: dates.get(release.version) };
    });
};

export const oneLine = (release: Release) => {
  const text = (
    release.summary[0] ??
    release.sections[0]?.items[0] ??
    ""
  ).replaceAll(MARKDOWN_MARKS, "");
  const end = text.search(SENTENCE_END);
  return end === -1 ? text : text.slice(0, end + 1);
};
