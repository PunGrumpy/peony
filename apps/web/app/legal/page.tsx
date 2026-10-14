import type { Metadata } from "next";

import { LegalPage, LegalSection } from "@/components/legal";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  description:
    "Licenses for Peony and the fonts and logos it uses, and the trademarks it names.",
  title: "Licenses and Trademarks",
};

const Page = () => (
  <LegalPage title="Licenses and Trademarks" updated="October 14, 2026">
    <LegalSection title="Peony">
      <p>
        Copyright © 2026 {site.author.name}. The app, its helper, and this
        website are released under the <a href={site.license}>MIT License</a>.
        The app contains no third-party code. The VPN clients it drives are
        installed separately and keep their own licenses.
      </p>
    </LegalSection>

    <LegalSection title="Artwork">
      <p>
        The peony images on this site are original. A script in the repository
        draws them, and they are released under the MIT License with the rest of
        the site.
      </p>
    </LegalSection>

    <LegalSection title="VPN logos">
      <p>
        The Fortinet, Cisco, Palo Alto Networks, F5, OpenVPN, WireGuard, and Tailscale
        logos come from <a href="https://simpleicons.org">Simple Icons</a>,
        released under CC0 1.0. The NetBird logo comes from{" "}
        <a href="https://selfh.st/icons/">selfh.st/icons</a> and the Ivanti logo
        from{" "}
        <a href="https://github.com/homarr-labs/dashboard-icons">
          Dashboard Icons
        </a>
        . They appear only to show which VPNs Peony works with.
      </p>
    </LegalSection>

    <LegalSection title="Trademarks">
      <p>
        The names and logos of VPN products belong to their owners. WireGuard is
        a registered trademark of Jason A. Donenfeld, and OpenVPN of OpenVPN
        Inc. Apple, Mac, and macOS are trademarks of Apple Inc. Naming them here
        doesn&apos;t mean their owners endorse Peony.
      </p>
    </LegalSection>

    <LegalSection title="Fonts and open source">
      <p>
        This site uses{" "}
        <a href="https://fonts.google.com/specimen/Newsreader">Newsreader</a>,{" "}
        <a href="https://fonts.google.com/specimen/Geist">Geist</a>, and{" "}
        <a href="https://fonts.google.com/specimen/Geist+Mono">Geist Mono</a>{" "}
        under the SIL Open Font License 1.1. It is built with Next.js, React,
        Tailwind CSS, cn, and class-variance-authority, all under the MIT
        License.
      </p>
    </LegalSection>
  </LegalPage>
);

export default Page;
