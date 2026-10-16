import Link from "next/link";
import type { CSSProperties } from "react";

import { Art } from "@/components/art";
import { BrewCommand } from "@/components/brew-command";
import { DownloadButton, GitHubButton } from "@/components/buttons";
import { Demo } from "@/components/demo";
import { Mark } from "@/components/logo";
import { Panel } from "@/components/panel";
import { Heading, Label, Section } from "@/components/section";
import { clients, netbird, site, vpns } from "@/lib/site";
import { SitePage } from "@/components/site-page";
import { States } from "@/components/states";
import { Steps } from "@/components/steps";
import { VpnLogo } from "@/components/vpn-logo";

const riseDelay = (index: number): CSSProperties => ({
  animationDelay: `${index * 60}ms`,
});

const helper = [
  {
    body: "The helper takes one JSON request on stdin. Secrets never appear in arguments, where other processes could read them.",
    title: "One request, on stdin",
  },
  {
    body: "Line breaks, option-like values, WireGuard’s PostUp and PreDown hooks and OpenVPN’s scripts and plugins are rejected before they reach a config file or a command line.",
    title: "Every field is validated",
  },
  {
    body: "It only executes clients from Homebrew’s bin and sbin directories, never a path it was handed.",
    title: "Homebrew clients only",
  },
  {
    body: "Generated configs go to a root-only directory. FortiGate’s and OpenVPN’s are deleted as soon as the client has read them.",
    title: "Configs don’t linger",
  },
];

const Page = () => (
  <SitePage>
    <section className="border-gray-400 grid border-b lg:grid-cols-2">
      <div className="flex min-w-0 flex-col">
        <div className="flex-1 px-6 py-12 sm:px-10">
          <Link
            href="/changelog"
            className="rise text-gray-900 hover:text-gray-1000 inline-flex items-center gap-2 text-[12px]"
          >
            <span className="bg-rose-200 text-rose-900 rounded-md px-2 py-[3px] font-medium tabular-nums">
              v{site.version}
            </span>
            Nine kinds of VPN, one switch
          </Link>
          <h1
            className="rise text-gray-900 mt-6 max-w-[30rem] font-serif text-[clamp(2rem,4.6vw,2.625rem)] leading-[1.14] font-medium tracking-[-0.035em] text-pretty"
            style={riseDelay(1)}
          >
            <span className="text-gray-1000">One VPN at a time.</span> Switch
            between them from the menu bar, and know the hosts you need are
            reachable.
          </h1>
          <div
            className="rise mt-8 flex flex-wrap gap-2.5"
            style={riseDelay(2)}
          >
            <DownloadButton />
            <GitHubButton />
          </div>
        </div>

        <div
          className="rise border-gray-400 border-t px-6 py-8 sm:px-10"
          style={riseDelay(3)}
        >
          <p className="text-gray-900 max-w-[32rem] text-[16px] leading-[1.5]">
            <span className="text-gray-1000 font-medium">
              Or install it with Homebrew.
            </span>{" "}
            For macOS 14 or later. Peony isn’t notarized yet, so the first time,
            open System Settings › Privacy & Security and click Open Anyway.
          </p>
          <BrewCommand className="mt-5" />
        </div>
      </div>

      <div className="border-gray-400 relative isolate flex min-h-[600px] min-w-0 flex-col overflow-hidden max-lg:border-t">
        <Art name="bloom" eager sizes="(min-width: 1024px) 640px, 100vw" />
        <Demo />
      </div>
    </section>

    <section
      aria-label="Works with"
      className="border-gray-400 border-b px-6 py-8 sm:px-10"
    >
      <ul className="text-gray-900 grid grid-cols-2 gap-x-4 gap-y-2 text-[14px] font-medium tracking-[-0.01em] whitespace-nowrap sm:grid-cols-3 xl:grid-cols-9 xl:gap-x-0">
        {vpns.map((vpn) => (
          <li
            key={vpn.id}
            className="flex h-11 items-center justify-center gap-1.5 max-sm:last:col-span-2"
          >
            <VpnLogo
              id={vpn.id}
              className={"wide" in vpn ? "h-4 w-11" : "size-[18px]"}
            />
            {vpn.name}
          </li>
        ))}
      </ul>
    </section>

    <Section id="states">
      <Heading label="The panel" title="Connected should mean reachable.">
        Peony keeps one tunnel on so routes and DNS never fight, then checks the
        hosts you care about. Here is every state it can be in.
      </Heading>
      <div className="mt-12">
        <States
          panels={{
            connecting: <Panel name="connecting" />,
            failed: <Panel name="failed" />,
            live: <Panel name="live" />,
            off: <Panel name="off" />,
          }}
        />
      </div>
    </Section>

    <Section id="security" className="pb-0 sm:pb-0">
      <Heading
        label="What runs as root"
        title="A small helper, kept on a short lead."
      >
        Setting routes and DNS needs root. Peony installs one helper and a
        sudoers rule for it, and the helper trusts nothing it is sent.
      </Heading>
      <ol className="border-gray-400 -mx-6 mt-12 grid border-t sm:-mx-10 sm:grid-cols-2 lg:grid-cols-4">
        {helper.map((item, index) => (
          <li
            key={item.title}
            className="border-gray-400 px-6 py-8 max-sm:not-last:border-b sm:px-10 sm:max-lg:odd:border-r sm:max-lg:nth-[-n+2]:border-b lg:px-8 lg:not-last:border-r lg:first:pl-10"
          >
            <Label className="tabular-nums">0{index + 1}</Label>
            <h3 className="mt-4 text-[16px] font-medium tracking-[-0.02em]">
              {item.title}
            </h3>
            <p className="text-gray-900 mt-1.5 text-[14px] leading-[1.5]">
              {item.body}
            </p>
          </li>
        ))}
      </ol>
      <p className="border-gray-400 text-gray-900 -mx-6 border-t px-6 py-5 text-[14px] sm:-mx-10 sm:px-10">
        Passwords and WireGuard and OpenVPN configs live in your Keychain.
        Remove everything with{" "}
        <code className="text-gray-1000 font-mono text-[13px] whitespace-nowrap">
          brew uninstall --zap peony
        </code>
        .
      </p>
    </Section>

    <Section id="install">
      <Heading label="Install" title="Three steps to the first tunnel.">
        Peony drives the open-source clients, so install the ones your VPNs
        need. Settings shows which are missing.
      </Heading>
      <Steps />

      <table className="border-gray-400 mt-14 w-full border-t text-left text-[14px]">
        <caption className="sr-only">Clients for each kind of VPN</caption>
        <thead>
          <tr className="border-gray-400 border-b">
            <th scope="col" className="py-3 pr-6 font-normal">
              <Label>VPN</Label>
            </th>
            <th scope="col" className="py-3 font-normal">
              <Label>Client</Label>
            </th>
          </tr>
        </thead>
        <tbody className="divide-gray-400 divide-y">
          {clients.map((client) => (
            <tr key={client.command}>
              <th scope="row" className="py-3.5 pr-6 align-top font-medium">
                {client.vpn}
              </th>
              <td className="text-gray-900 py-3.5 font-mono text-[13px]">
                {client.command}
              </td>
            </tr>
          ))}
          <tr>
            <th scope="row" className="py-3.5 pr-6 align-top font-medium">
              NetBird
            </th>
            <td className="py-3.5">
              <a
                href={netbird}
                className="text-gray-900 hover:text-gray-1000 underline underline-offset-4"
              >
                NetBird’s installer
              </a>
            </td>
          </tr>
        </tbody>
      </table>
    </Section>

    <section className="border-gray-400 flex flex-col items-center border-b px-6 py-24 text-center sm:py-32">
      <Mark className="text-rose-700 size-12" />
      <h2 className="mt-6 font-serif text-[clamp(2.25rem,5vw,3.25rem)] leading-[1.08] font-medium tracking-[-0.035em]">
        One on.
        <br />
        <span className="text-gray-900">The rest stay off.</span>
      </h2>
      <div className="mt-9 flex max-w-full flex-col items-center gap-3">
        <DownloadButton />
        <BrewCommand />
      </div>
    </section>
    <div
      aria-hidden="true"
      className="border-gray-400 relative isolate h-[220px] overflow-hidden border-b sm:h-[340px]"
    >
      <Art name="field" sizes="(min-width: 1280px) 1230px, 100vw" />
    </div>
  </SitePage>
);

export default Page;
