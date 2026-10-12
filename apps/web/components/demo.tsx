"use client";

import { cn } from "cn";
import type { ReactNode } from "react";
import { useEffect, useState } from "react";

import {
  CheckIcon,
  FortiIcon,
  GearIcon,
  NetBirdIcon,
  OpenConnectIcon,
  PlusIcon,
  WireGuardIcon,
} from "./icons";
import { Mark } from "./logo";

interface Route {
  address: string;
  // Latency in milliseconds, or null when the host can't be reached.
  destinations: { host: string; ms: number | null }[];
  endpoint: string;
  icon: ReactNode;
  id: string;
  name: string;
}

const routes: Route[] = [
  {
    address: "10.122.0.8",
    destinations: [
      { host: "gitlab.acme.co", ms: 23 },
      { host: "10.11.219.9", ms: 31 },
      { host: "grafana.acme.co", ms: null },
    ],
    endpoint: "vpn.acme.co",
    icon: <FortiIcon className="size-3.5" />,
    id: "work",
    name: "Work",
  },
  {
    address: "100.92.14.3",
    destinations: [
      { host: "ci.lab.acme.co", ms: 12 },
      { host: "registry.lab.acme.co", ms: 18 },
    ],
    endpoint: "netbird.acme.co",
    icon: <NetBirdIcon className="size-3.5" />,
    id: "lab",
    name: "Lab",
  },
  {
    address: "172.20.4.17",
    destinations: [
      { host: "jira.client.com", ms: 84 },
      { host: "wiki.client.com", ms: 91 },
    ],
    endpoint: "connect.client.com",
    icon: <OpenConnectIcon className="size-3.5" />,
    id: "client",
    name: "Client",
  },
  {
    address: "10.8.0.2",
    destinations: [
      { host: "nas.home", ms: 6 },
      { host: "pi.home", ms: 9 },
    ],
    endpoint: "peony0",
    icon: <WireGuardIcon className="size-3.5" />,
    id: "home",
    name: "Home",
  },
];

type Phase = "off" | "connecting" | "on" | "disconnecting";

interface Tunnel {
  active: string | null;
  // The route to bring up once the active one is down.
  next: string | null;
  phase: Phase;
  // True until the first switch: the demo opens connected, as if it had been for a while.
  resumed: boolean;
}

const CONNECT_MS = 1600;
const DISCONNECT_MS = 650;
// The first host answers after this long, the rest a beat apart.
const CHECK_MS = 500;
const CHECK_STAGGER_MS = 350;
const RESUMED_MS = 754_000;

const clock = (ms: number) => {
  const seconds = Math.floor(ms / 1000);
  const pad = (value: number) => String(value).padStart(2, "0");
  return `${pad(Math.floor(seconds / 60))}:${pad(seconds % 60)}`;
};

const useTunnel = () => {
  const [tunnel, setTunnel] = useState<Tunnel>({
    active: "work",
    next: null,
    phase: "on",
    resumed: true,
  });
  const { active, phase } = tunnel;
  const busy = phase === "connecting" || phase === "disconnecting";

  useEffect(() => {
    if (phase === "connecting") {
      const timer = setTimeout(
        () => setTunnel((current) => ({ ...current, phase: "on" })),
        CONNECT_MS
      );
      return () => clearTimeout(timer);
    }
    if (phase === "disconnecting") {
      const timer = setTimeout(() => {
        setTunnel(({ next }) =>
          next
            ? { active: next, next: null, phase: "connecting", resumed: false }
            : { active: null, next: null, phase: "off", resumed: false }
        );
      }, DISCONNECT_MS);
      return () => clearTimeout(timer);
    }
  }, [phase]);

  // Peony turns any other VPN off first, so a switch goes down before it comes up.
  const connect = (id: string) => {
    if (busy || (id === active && phase === "on")) {
      return;
    }
    setTunnel(
      phase === "on"
        ? { active, next: id, phase: "disconnecting", resumed: false }
        : { active: id, next: null, phase: "connecting", resumed: false }
    );
  };

  const disconnect = () =>
    setTunnel(
      phase === "on"
        ? { active, next: null, phase: "disconnecting", resumed: false }
        : { active: null, next: null, phase: "off", resumed: false }
    );

  return { ...tunnel, busy, connect, disconnect };
};

const Tag = ({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) => (
  <span
    className={cn(
      "blur-in font-mono text-[10px] font-medium tracking-[0.08em] uppercase",
      className
    )}
  >
    {children}
  </span>
);

const SectionLabel = ({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) => (
  <p
    className={cn(
      "text-gray-700 font-mono text-[10px] font-medium tracking-[0.08em] uppercase",
      className
    )}
  >
    {children}
  </p>
);

const LiveDot = () => (
  <span aria-hidden="true" className="bg-rose-700 size-[7px] rounded-full" />
);

const Pill = ({
  children,
  onClick,
}: {
  children: ReactNode;
  onClick: () => void;
}) => (
  <button
    type="button"
    onClick={onClick}
    className="press bg-gray-200 hover:bg-gray-300 shrink-0 rounded-full px-[11px] py-[5px] text-[11.5px] font-medium"
  >
    {children}
  </button>
);

// Holds its own state, so the second ticking re-renders this span and nothing else.
const Uptime = ({ from }: { from: number }) => {
  const [elapsed, setElapsed] = useState(from);

  useEffect(() => {
    const start = Date.now() - from;
    const timer = setInterval(() => setElapsed(Date.now() - start), 1000);
    return () => clearInterval(timer);
  }, [from]);

  return (
    <span role="timer" className="text-gray-700">
      {clock(elapsed)}
    </span>
  );
};

const MenuBar = ({ name, phase }: { name: string; phase: Phase }) => (
  <div className="relative z-2 flex h-7 items-center justify-end gap-4 bg-black/25 px-4 text-[13px] font-medium text-white backdrop-blur-md transparency-reduce:bg-black/60 transparency-reduce:backdrop-blur-none">
    <span className="flex items-center gap-1.5">
      <Mark
        filled={phase === "on" ? 2 : phase === "connecting" ? 1 : 0}
        className={cn("size-4", { bloom: phase === "connecting" })}
      />
      {phase === "on" && name}
      {phase === "connecting" && `${name}…`}
    </span>
    <span className="tabular-nums">Mon 9:41</span>
  </div>
);

const headlines: Record<Phase, (name: string) => string> = {
  connecting: (name) => `Connecting to ${name}`,
  disconnecting: () => "Disconnecting",
  off: () => "Not connected",
  on: (name) => `Connected to ${name}`,
};

const Hero = ({
  disconnect,
  phase,
  resumed,
  route,
}: {
  disconnect: () => void;
  phase: Phase;
  resumed: boolean;
  route?: Route;
}) => {
  const headline = headlines[phase](route?.name ?? "VPN");
  return (
    <div className="mb-3.5">
      {/* Only the headline is announced. The timer beside it changes every second. */}
      <div aria-live="polite">
        <p
          key={headline}
          className="blur-in font-serif text-[21px] leading-[1.2] font-medium tracking-[-0.035em]"
        >
          {headline}
        </p>
      </div>
      <div
        key={phase}
        className="blur-in mt-[5px] flex min-h-[26px] items-center gap-2.5"
      >
        {phase === "on" && route && (
          <>
            <span className="flex flex-1 items-center gap-1.5 font-mono text-[11.5px] tabular-nums">
              <LiveDot />
              {route.address}
              <span className="text-gray-700">·</span>
              <Uptime from={resumed ? RESUMED_MS : 0} />
            </span>
            <Pill onClick={disconnect}>Disconnect</Pill>
          </>
        )}
        {phase === "connecting" && (
          <>
            <span className="text-gray-700 flex-1">
              Signing in and setting up routes.
            </span>
            <Pill onClick={disconnect}>Cancel</Pill>
          </>
        )}
        {phase === "disconnecting" && (
          <span className="text-gray-700">Removing routes and DNS.</span>
        )}
        {phase === "off" && (
          <span className="text-gray-700">
            Pick a route. Only one runs at a time.
          </span>
        )}
      </div>
    </div>
  );
};

const RouteCard = ({
  locked,
  onConnect,
  phase,
  route,
  shortcut,
}: {
  // Nothing can be picked while a tunnel is coming up or going down.
  locked: boolean;
  onConnect: () => void;
  // This route's own state: "off" unless it is the active one.
  phase: Phase;
  route: Route;
  shortcut: number;
}) => {
  const raised = phase === "on" || phase === "connecting";
  return (
    <button
      type="button"
      onClick={onConnect}
      aria-disabled={locked || phase === "on"}
      aria-label={`${route.name}, ${phase}`}
      className={cn(
        "press flex items-center gap-2.5 rounded-[10px] px-2 py-1.5 text-left transition-[background-color,box-shadow,transform] duration-[180ms] ease-out",
        raised
          ? "bg-background-100 shadow-[0_3px_10px_rgb(0_0_0/0.08),inset_0_0_0_1px_var(--color-gray-alpha-300)]"
          : "bg-gray-200",
        { "hover:bg-gray-300": !raised && !locked },
        { "cursor-default active:scale-100": locked || raised }
      )}
    >
      <span
        className={cn(
          "grid size-[26px] shrink-0 place-items-center rounded-[7px] transition-colors duration-[180ms] ease-out",
          raised ? "bg-rose-700 text-white" : "bg-gray-alpha-300 text-gray-900"
        )}
      >
        {route.icon}
      </span>
      <span className="flex min-w-0 flex-1 flex-col gap-px">
        <span className="truncate font-medium">{route.name}</span>
        <span className="text-gray-700 truncate font-mono text-[11.5px]">
          {route.endpoint}
        </span>
      </span>
      {phase === "on" && <Tag className="text-rose-700">Live</Tag>}
      {phase === "connecting" && <Tag className="text-gray-700">Joining</Tag>}
      {phase === "disconnecting" && (
        <Tag className="text-gray-700">Leaving</Tag>
      )}
      {phase === "off" && (
        <span
          aria-hidden="true"
          className="text-gray-600 font-mono text-[11.5px]"
        >
          ⌘{shortcut}
        </span>
      )}
    </button>
  );
};

const AddCard = () => (
  <div
    aria-hidden="true"
    className="text-gray-700 border-gray-alpha-400 flex items-center gap-2.5 rounded-[10px] border border-dashed px-2 py-[5px]"
  >
    <span className="grid h-[22px] w-[26px] place-items-center">
      <PlusIcon className="size-3" />
    </span>
    <span className="flex-1">Add VPN</span>
    <span className="text-gray-600 font-mono text-[11.5px]">⌘N</span>
  </div>
);

// Mounted when a tunnel comes up. `settled` skips the checks for the tunnel the demo opens with.
const Destinations = ({
  route,
  settled,
}: {
  route: Route;
  settled: boolean;
}) => {
  const total = route.destinations.length;
  const [answered, setAnswered] = useState(settled ? total : 0);

  useEffect(() => {
    if (settled) {
      return;
    }
    const timers = Array.from({ length: total }, (_, index) =>
      setTimeout(
        () => setAnswered(index + 1),
        CHECK_MS + index * CHECK_STAGGER_MS
      )
    );
    return () => timers.forEach(clearTimeout);
  }, [settled, total]);

  return (
    <div className="blur-in">
      <SectionLabel className="mt-3.5 mb-0.5">Reachable</SectionLabel>
      <ul className="font-mono text-[11.5px] tabular-nums">
        {route.destinations.map((destination, index) => (
          <li
            key={destination.host}
            className="flex justify-between gap-3 py-[3px]"
          >
            <span className="truncate">{destination.host}</span>
            {index >= answered && (
              <span className="text-gray-700">checking…</span>
            )}
            {index < answered && destination.ms !== null && (
              <span className="blur-in flex items-center gap-1.5">
                <LiveDot />
                {destination.ms} ms
              </span>
            )}
            {index < answered && destination.ms === null && (
              <span className="blur-in text-amber-900">unreachable</span>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
};

const Footer = () => {
  const [opensAtLogin, setOpensAtLogin] = useState(true);
  return (
    <div className="text-gray-700 mt-3.5 flex items-center gap-3.5 text-[11.5px]">
      <button
        type="button"
        role="switch"
        aria-checked={opensAtLogin}
        onClick={() => setOpensAtLogin((value) => !value)}
        className="press hover:text-gray-1000 flex flex-1 items-center gap-1.5"
      >
        <span
          className={cn(
            "grid size-3 place-items-center rounded-full",
            opensAtLogin
              ? "bg-rose-700 text-white"
              : "shadow-[inset_0_0_0_1px_var(--color-gray-700)]"
          )}
        >
          {opensAtLogin && <CheckIcon className="size-2" />}
        </span>
        Open at login
      </button>
      <span aria-hidden="true">Log</span>
      <span aria-hidden="true">Quit</span>
    </div>
  );
};

export const Demo = () => {
  const { active, busy, connect, disconnect, phase, resumed } = useTunnel();
  const route = routes.find((item) => item.id === active);

  return (
    <>
      <MenuBar name={route?.name ?? "VPN"} phase={phase} />

      <div className="relative z-2 flex flex-1 flex-col items-center px-6 pt-2 pb-10 lg:items-end lg:pr-12">
        <div
          role="group"
          aria-label="Peony’s panel, live. Pick a route to connect."
          className="rise bg-background-200/90 text-gray-1000 outline-gray-alpha-400 w-[320px] max-w-full rounded-[14px] p-3.5 text-[13px] leading-[1.3] shadow-[0_1px_2px_rgb(0_0_0/0.1),0_24px_48px_-12px_rgb(0_0_0/0.35)] outline-1 -outline-offset-1 backdrop-blur-2xl backdrop-saturate-150 transparency-reduce:bg-background-200 transparency-reduce:backdrop-blur-none"
        >
          <div className="mb-3 flex items-center justify-between">
            <span className="flex items-center gap-[7px]">
              <Mark
                className={cn(
                  "size-[17px] transition-colors duration-200 ease-out",
                  { "text-rose-700": phase === "on" }
                )}
              />
              <span className="font-serif text-[17px] leading-none font-medium tracking-[-0.035em]">
                Peony
              </span>
            </span>
            <GearIcon className="text-gray-700 size-[15px]" />
          </div>

          <Hero
            disconnect={disconnect}
            phase={phase}
            resumed={resumed}
            route={route}
          />

          <SectionLabel className="mb-1.5">Routes</SectionLabel>
          <div className="flex flex-col gap-1">
            {routes.map((item, index) => (
              <RouteCard
                key={item.id}
                locked={busy}
                onConnect={() => connect(item.id)}
                phase={item.id === active ? phase : "off"}
                route={item}
                shortcut={index + 1}
              />
            ))}
            <AddCard />
          </div>

          {phase === "on" && route && (
            <Destinations key={route.id} route={route} settled={resumed} />
          )}

          <Footer />
        </div>

        <p className="relative mt-5 w-[320px] max-w-full text-center text-[13px] text-white/75">
          This one works. Pick a route to switch.
        </p>
      </div>
    </>
  );
};
