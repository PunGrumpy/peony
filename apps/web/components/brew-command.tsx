"use client";

import { cn } from "cn";
import { useEffect, useRef, useState } from "react";

import { CheckIcon, CopyIcon } from "./icons";
import { site } from "@/lib/site";

export const BrewCommand = ({ className }: { className?: string }) => {
  const [copied, setCopied] = useState(false);
  const command = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    if (!copied) {
      return;
    }
    const timer = setTimeout(() => setCopied(false), 1600);
    return () => clearTimeout(timer);
  }, [copied]);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(site.brew);
      setCopied(true);
    } catch {
      if (command.current) {
        window.getSelection()?.selectAllChildren(command.current);
      }
    }
  };

  return (
    <div className={cn("flex max-w-full", className)}>
      <button
        type="button"
        onClick={copy}
        aria-label="Copy the Homebrew install command"
        className="press bg-background-100 hover:bg-gray-100 flex h-9 max-w-full items-center gap-3 rounded-xl pr-1 pl-3.5 font-mono text-[13px] shadow-[inset_0_0_0_1px_var(--color-gray-400)]"
      >
        <span className="flex min-w-0 [scrollbar-width:none] items-center gap-2 overflow-x-auto max-sm:[mask-image:linear-gradient(to_right,black_85%,transparent)]">
          <span aria-hidden="true" className="text-gray-700 select-none">
            $
          </span>
          <span ref={command} className="whitespace-nowrap">
            {site.brew}
          </span>
        </span>
        <span className="bg-gray-200 text-gray-900 grid size-7 shrink-0 place-items-center rounded-lg">
          {copied ? (
            <CheckIcon key="check" className="blur-in text-rose-900 size-3.5" />
          ) : (
            <CopyIcon key="copy" className="blur-in size-3.5" />
          )}
        </span>
      </button>
      <span aria-live="polite" className="sr-only">
        {copied ? "Copied the install command" : ""}
      </span>
    </div>
  );
};
