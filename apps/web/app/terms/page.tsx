import type { Metadata } from "next";

import { LegalPage, LegalSection } from "@/components/legal";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  description:
    "The terms for using the Peony app and this website, alongside the MIT License that covers the code.",
  title: "Terms of Service",
};

const Page = () => (
  <LegalPage title="Terms of Service" updated="October 12, 2026">
    <p>
      These terms cover the Peony app and this website. The source code is
      released under the <a href={site.license}>MIT License</a>, which governs
      copying, changing, and sharing it.
    </p>

    <LegalSection title="Using Peony">
      <p>
        Peony is free. You can use it on as many Macs as you like, for personal
        or commercial work.
      </p>
    </LegalSection>

    <LegalSection title="No warranty">
      <p>
        Peony is provided as is, without warranty of any kind, as the MIT
        License says. It can have bugs. A tunnel might drop, or a route or DNS
        setting might not be restored, and traffic you expected to go through a
        VPN might not. Don&apos;t rely on Peony alone where that would matter.
      </p>
    </LegalSection>

    <LegalSection title="Your Mac, your network">
      <p>
        The first connection asks for an admin password to install a root helper
        and a sudoers rule that lets your account run it without a password.
        Only install it on a Mac you&apos;re allowed to administer.
      </p>
      <p>
        Only connect to VPNs you&apos;re allowed to use, with credentials that
        are yours. If Peony offers to trust a server&apos;s certificate, check
        with your admin before you accept.
      </p>
    </LegalSection>

    <LegalSection title="Other software and services">
      <p>
        Peony drives openfortivpn, openconnect, wireguard-tools, NetBird, and
        Tailscale, which you install yourself and which have their own licenses.
        Your use of each VPN stays under its operator&apos;s terms.
      </p>
      <p>
        Peony isn&apos;t made, endorsed, or supported by Fortinet, Cisco, Palo
        Alto Networks, Ivanti, F5, WireGuard, NetBird, Tailscale, or the
        authors of those clients.
      </p>
    </LegalSection>

    <LegalSection title="Liability">
      <p>
        As far as the law allows, the author isn&apos;t liable for damage, lost
        data, or costs that come from using Peony, including lost work from a
        tunnel that dropped or traffic that left outside a VPN.
      </p>
    </LegalSection>

    <LegalSection title="Changes and questions">
      <p>
        If these terms change, this page shows a new date, and the change is in
        the site&apos;s history on <a href={site.repo}>GitHub</a>. Ask questions
        in <a href={`${site.repo}/issues`}>GitHub issues</a>.
      </p>
    </LegalSection>
  </LegalPage>
);

export default Page;
