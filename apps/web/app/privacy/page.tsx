import type { Metadata } from "next";

import { LegalPage, LegalSection } from "@/components/legal";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  alternates: { canonical: "/privacy" },
  description:
    "What Peony keeps on your Mac, the only connections it makes, and what this website collects.",
  title: "Privacy Policy",
};

const Page = () => (
  <LegalPage title="Privacy Policy" updated="October 12, 2026">
    <p>
      Peony is a menu bar app that runs on your Mac. It has no accounts and no
      servers, and it has no telemetry, analytics, crash reporting, or ads. This
      policy covers the app, how you download it, and this website.
    </p>

    <LegalSection title="What stays on your Mac">
      <p>Peony keeps these on your Mac and sends them nowhere:</p>
      <ul>
        <li>
          Your VPN settings, such as hosts, usernames, and the hosts to check,
          in <code>~/Library/Application Support/Peony/profiles.json</code>.
        </li>
        <li>
          Passwords and WireGuard configs, in your Keychain under{" "}
          <code>app.peony.Peony</code>.
        </li>
        <li>
          Your preferences, including the last VPN you used, in the{" "}
          <code>app.peony.Peony</code> preferences.
        </li>
        <li>
          The root helper at{" "}
          <code>/Library/PrivilegedHelperTools/app.peony.helper</code> and its
          sudoers rule at <code>/etc/sudoers.d/peony</code>.
        </li>
        <li>
          While a tunnel is up, the config the helper generates for it, in the
          root-only directory <code>/var/run/peony</code>. FortiGate&apos;s holds
          your password, so it is deleted as soon as openfortivpn has read it.
        </li>
      </ul>
      <p>
        The log window shows the last 500 lines the VPN client printed. Peony
        holds them in memory and they are gone when it quits. It also writes a
        few status lines to the macOS system log, such as that a tunnel process
        exited.
      </p>
    </LegalSection>

    <LegalSection title="What leaves your Mac">
      <p>Peony makes two kinds of connection, both to places you chose:</p>
      <ul>
        <li>
          <strong>Your VPN.</strong> The client you installed (openfortivpn,
          openconnect, WireGuard, or NetBird) connects to the server in your
          settings and signs in with your credentials. Your VPN&apos;s operator
          handles that traffic under its own policy.
        </li>
        <li>
          <strong>Reachability checks.</strong> While a tunnel is up, Peony
          opens a TCP connection to each host you listed, on port 443 unless you
          gave another, and times it. It sends no data over that connection.
        </li>
      </ul>
      <p>
        Nothing goes to the author or to any third party, because there is no
        server to send it to. Peony doesn&apos;t check for updates.
      </p>
    </LegalSection>

    <LegalSection title="Downloads">
      <p>
        You download Peony from GitHub Releases, or through Homebrew, which
        fetches the same file from GitHub. The{" "}
        <a href="https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement">
          GitHub Privacy Statement
        </a>{" "}
        covers those downloads.
      </p>
    </LegalSection>

    <LegalSection title="This website">
      <p>
        This site sets no cookies and runs no analytics or tracking scripts. Its
        fonts and images load from the site itself. It&apos;s hosted on Vercel,
        which keeps standard server logs, such as IP addresses and browser
        details, under the{" "}
        <a href="https://vercel.com/legal/privacy-policy">
          Vercel Privacy Policy
        </a>
        . The changelog reads release dates from GitHub when the site is built,
        not when you visit.
      </p>
    </LegalSection>

    <LegalSection title="Removing your data">
      <p>
        Everything Peony keeps is on your Mac.{" "}
        <code>brew uninstall --zap peony</code> removes the app, the helper, the
        sudoers rule, your settings, and your preferences. Keychain items stay
        until you delete them in Keychain Access.
      </p>
    </LegalSection>

    <LegalSection title="Changes and questions">
      <p>
        If this policy changes, this page shows a new date, and the change is in
        the site&apos;s history on <a href={site.repo}>GitHub</a>. Ask questions
        in <a href={`${site.repo}/issues`}>GitHub issues</a>.
      </p>
    </LegalSection>
  </LegalPage>
);

export default Page;
