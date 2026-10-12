import { cn } from "cn";
import type { ReactNode } from "react";

// A small uppercase mono label, the app's way of naming a section.
export const Label = ({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) => (
  <p
    className={cn(
      "text-gray-900 font-mono text-[11px] font-medium tracking-[0.08em] uppercase",
      className
    )}
  >
    {children}
  </p>
);

// The claim in ink, the explanation in gray, set as one sentence.
export const Heading = ({
  children,
  label,
  title,
}: {
  children: ReactNode;
  label: string;
  title: string;
}) => (
  <div className="max-w-[40rem]">
    <Label>{label}</Label>
    <h2 className="text-gray-900 mt-4 font-serif text-[28px] leading-[1.25] font-medium tracking-[-0.03em] text-pretty">
      <span className="text-gray-1000">{title}</span> {children}
    </h2>
  </div>
);

export const Section = ({
  children,
  className,
  id,
}: {
  children: ReactNode;
  className?: string;
  id?: string;
}) => (
  <section
    id={id}
    className={cn(
      "border-gray-400 scroll-mt-4 border-b px-6 py-16 sm:px-10 sm:py-24",
      className
    )}
  >
    {children}
  </section>
);
