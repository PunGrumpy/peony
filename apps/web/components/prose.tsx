import { cn } from "cn";
import type { ReactNode } from "react";

export const Prose = ({
  className,
  children,
}: {
  className?: string;
  children: ReactNode;
}) => (
  <div
    className={cn(
      "text-gray-900 [&_a]:text-gray-1000 [&_a]:decoration-gray-500 [&_a:hover]:decoration-gray-1000 [&_code]:bg-gray-200 [&_code]:text-gray-1000 [&_strong]:text-gray-1000 flex flex-col text-[15px] leading-relaxed [&_a]:underline [&_a]:underline-offset-2 [&_code]:rounded-[5px] [&_code]:px-1 [&_code]:py-0.5 [&_code]:font-mono [&_code]:text-[13px] [&_li]:pl-1 [&_strong]:font-medium [&_ul]:flex [&_ul]:list-disc [&_ul]:flex-col [&_ul]:gap-2 [&_ul]:pl-5",
      className
    )}
  >
    {children}
  </div>
);
