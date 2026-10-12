"use client";

import { cn } from "cn";
import type { KeyboardEvent, ReactNode } from "react";
import { useState } from "react";

import { Mark } from "./logo";
import type { PanelName } from "./panel";

const states: {
  body: string;
  filled: 0 | 1 | 2;
  name: PanelName;
  title: string;
}[] = [
  {
    body: "Every route waits in one list. Click one, or press ⌘1 to ⌘9.",
    filled: 0,
    name: "off",
    title: "Off",
  },
  {
    body: "Peony turns any other VPN off first, then shows each step as the tunnel comes up. The flower blooms while it works.",
    filled: 1,
    name: "connecting",
    title: "Connecting",
  },
  {
    body: "The menu bar shows the VPN’s name. Below the routes, the hosts you listed answer with their latency, or don’t.",
    filled: 2,
    name: "live",
    title: "Live",
  },
  {
    body: "When a tunnel won’t come up, Peony reads the client’s log and says why, in a sentence, with the log one click away.",
    filled: 0,
    name: "failed",
    title: "Failed",
  },
];

const tabId = (name: PanelName) => `state-tab-${name}`;

// The panels are rendered on the server and passed in, so this file ships no images.
export const States = ({
  panels,
}: {
  panels: Record<PanelName, ReactNode>;
}) => {
  const [active, setActive] = useState<PanelName>("live");

  // One is always open, so these are tabs: arrows move between them and the choice follows focus.
  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const index = states.findIndex((state) => state.name === active);
    const target = {
      ArrowDown: states[(index + 1) % states.length],
      ArrowUp: states[(index - 1 + states.length) % states.length],
      End: states.at(-1),
      Home: states[0],
    }[event.key];
    if (!target) {
      return;
    }
    event.preventDefault();
    setActive(target.name);
    document.getElementById(tabId(target.name))?.focus();
  };

  return (
    <div className="grid lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
      <div
        role="tablist"
        aria-label="Panel states"
        aria-orientation="vertical"
        onKeyDown={onKeyDown}
        className="divide-gray-400 border-gray-400 flex flex-col divide-y self-start border-y"
      >
        {states.map((state) => {
          const open = state.name === active;
          return (
            <button
              key={state.name}
              type="button"
              role="tab"
              id={tabId(state.name)}
              aria-selected={open}
              aria-controls="state-panel"
              aria-labelledby={`${tabId(state.name)}-title`}
              aria-describedby={`${tabId(state.name)}-body`}
              tabIndex={open ? 0 : -1}
              onClick={() => setActive(state.name)}
              className={cn(
                "text-left",
                open ? "text-gray-1000" : "text-gray-900 hover:text-gray-1000"
              )}
            >
              <span
                id={`${tabId(state.name)}-title`}
                className="flex h-12 items-center gap-3 text-[16px] font-medium tracking-[-0.02em]"
              >
                <Mark
                  filled={state.filled}
                  className={cn("size-[18px]", {
                    "text-rose-700": state.name === "live" && open,
                  })}
                />
                {state.title}
              </span>
              <span
                className={cn(
                  "grid transition-[grid-template-rows,opacity] duration-200 ease-out motion-reduce:transition-none",
                  open ? "grid-rows-[1fr]" : "grid-rows-[0fr] opacity-0"
                )}
              >
                <span
                  id={`${tabId(state.name)}-body`}
                  className="text-gray-900 min-h-0 overflow-hidden text-[14px] leading-[1.5]"
                >
                  <span className="block max-w-[26rem] pb-4 pl-[30px]">
                    {state.body}
                  </span>
                </span>
              </span>
            </button>
          );
        })}
      </div>

      <div
        role="tabpanel"
        id="state-panel"
        aria-labelledby={tabId(active)}
        className="bg-gray-100 mt-10 grid h-[560px] justify-items-center overflow-hidden rounded-[20px] px-6 pt-10 lg:mt-0 lg:ml-12"
      >
        {states.map((state) => (
          <div
            key={state.name}
            aria-hidden={state.name !== active}
            className={cn(
              "col-start-1 row-start-1 max-w-full origin-top transition-[opacity,filter,transform] duration-200 ease-out motion-reduce:transition-opacity",
              state.name === active
                ? "delay-75"
                : "pointer-events-none scale-[0.98] opacity-0 blur-[2px] motion-reduce:scale-100 motion-reduce:blur-none"
            )}
          >
            {panels[state.name]}
          </div>
        ))}
      </div>
    </div>
  );
};
