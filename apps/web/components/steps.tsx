import type { ReactNode } from "react";

import { Art } from "./art";
import { FortiIcon, PlusIcon } from "./icons";
import { Mark } from "./logo";

const surface =
  "bg-background-200 text-gray-1000 outline-gray-alpha-400 rounded-[12px] text-[12px] leading-[1.3] shadow-[0_1px_2px_rgb(0_0_0/0.1),0_16px_32px_-12px_rgb(0_0_0/0.4)] outline-1 -outline-offset-1";

const MonoLabel = ({ children }: { children: ReactNode }) => (
  <span className="text-gray-700 font-mono text-[9px] font-medium tracking-[0.08em] uppercase">
    {children}
  </span>
);

// The flower in the menu bar, and the panel it opens the first time.
const OpenVisual = () => (
  <div className="flex w-full flex-col items-end">
    <div className="flex h-6 w-full items-center justify-end gap-3 bg-black/30 px-3 text-[11px] font-medium text-white backdrop-blur-md">
      <span className="grid h-[18px] w-6 place-items-center rounded-[5px] bg-white/25">
        <Mark filled={0} className="size-3.5" />
      </span>
      <span className="tabular-nums">Mon 9:41</span>
    </div>
    <div className={`${surface} mt-1.5 mr-3 w-[212px] max-w-[calc(100%-1.5rem)] p-3`}>
      <span className="flex items-center gap-1.5">
        <Mark className="size-3.5" />
        <span className="font-serif text-[14px] leading-none font-medium tracking-[-0.035em]">
          Peony
        </span>
      </span>
      <p className="mt-2.5 font-serif text-[17px] leading-[1.2] font-medium tracking-[-0.035em]">
        Add your first VPN
      </p>
      <p className="text-gray-700 mt-1">
        Peony keeps one on at a time.
      </p>
      <span className="bg-gray-1000 text-background-200 mt-2.5 inline-block rounded-full px-2.5 py-1 text-[11px] font-medium">
        Add VPN
      </span>
    </div>
  </div>
);

const Field = ({ label, value }: { label: string; value: ReactNode }) => (
  <div className="border-gray-alpha-300 flex items-baseline justify-between gap-3 border-t py-1.5">
    <MonoLabel>{label}</MonoLabel>
    <span className="truncate font-mono text-[11px]">{value}</span>
  </div>
);

// What an admin hands over, typed into the Add VPN sheet.
const RouteVisual = () => (
  <div className={`${surface} w-[236px] max-w-[calc(100%-1.5rem)] p-3`}>
    <div className="mb-2.5 flex gap-1">
      {["FortiGate", "AnyConnect", "WireGuard"].map((kind, index) => (
        <span
          key={kind}
          className={
            index === 0
              ? "bg-gray-1000 text-background-200 rounded-full px-2 py-0.5 text-[10.5px] font-medium"
              : "bg-gray-200 text-gray-900 rounded-full px-2 py-0.5 text-[10.5px]"
          }
        >
          {kind}
        </span>
      ))}
    </div>
    <Field label="Name" value="Work" />
    <Field label="Server" value="vpn.acme.co" />
    <Field label="User" value="alex" />
    <Field label="Check" value="gitlab.acme.co" />
  </div>
);

// The route once it is up, with the hosts that answered.
const ConnectVisual = () => (
  <div className={`${surface} w-[236px] max-w-[calc(100%-1.5rem)] p-2`}>
    <div className="bg-background-100 flex items-center gap-2 rounded-[9px] px-2 py-1.5 shadow-[0_3px_10px_rgb(0_0_0/0.08),inset_0_0_0_1px_var(--color-gray-alpha-300)]">
      <span className="bg-rose-700 grid size-6 shrink-0 place-items-center rounded-[6px] text-white">
        <FortiIcon className="size-3" />
      </span>
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="font-medium">Work</span>
        <span className="text-gray-700 font-mono text-[10.5px]">
          vpn.acme.co
        </span>
      </span>
      <span className="text-rose-700 font-mono text-[9px] font-medium tracking-[0.08em]">
        LIVE
      </span>
    </div>
    <div className="text-gray-700 border-gray-alpha-400 mt-1 flex items-center gap-2 rounded-[9px] border border-dashed px-2 py-1">
      <span className="grid size-6 place-items-center">
        <PlusIcon className="size-2.5" />
      </span>
      Add VPN
    </div>
    <div className="px-1 pt-2.5 pb-1">
      <MonoLabel>Reachable</MonoLabel>
      {[
        ["gitlab.acme.co", "23 ms"],
        ["10.11.219.9", "31 ms"],
      ].map(([host, time]) => (
        <div
          key={host}
          className="flex justify-between pt-1 font-mono text-[10.5px] tabular-nums"
        >
          <span>{host}</span>
          <span className="flex items-center gap-1.5">
            <span className="bg-rose-700 size-1.5 rounded-full" />
            {time}
          </span>
        </div>
      ))}
    </div>
  </div>
);

const steps = [
  {
    art: "open",
    body: "Click the flower in the menu bar, then Add VPN.",
    title: "Open the panel.",
    top: true,
    visual: <OpenVisual />,
  },
  {
    art: "route",
    body: "Pick the kind, fill in what your admin gave you, and list a few hosts to check.",
    title: "Describe the route.",
    top: false,
    visual: <RouteVisual />,
  },
  {
    art: "connect",
    body: "Click it, or press ⌘1 to ⌘9. The first connection asks for an admin password once, to install the helper.",
    title: "Connect.",
    top: false,
    visual: <ConnectVisual />,
  },
] as const;

export const Steps = () => (
  <ol className="mt-12 grid gap-4 md:grid-cols-3">
    {steps.map((step) => (
      <li
        key={step.title}
        className="bg-background-100 flex flex-col overflow-hidden rounded-[20px] shadow-[inset_0_0_0_1px_var(--color-gray-400)]"
      >
        <div
          aria-hidden="true"
          className={`relative isolate flex h-[264px] justify-center overflow-hidden ${step.top ? "items-start" : "items-center"}`}
        >
          <Art name={step.art} sizes="(min-width: 768px) 33vw, 100vw" />
          {step.visual}
        </div>
        <p className="text-gray-900 border-gray-400 border-t p-6 text-[16px] leading-[1.5] tracking-[-0.01em]">
          <span className="text-gray-1000 font-medium">{step.title}</span>{" "}
          {step.body}
        </p>
      </li>
    ))}
  </ol>
);
