import { cva } from "class-variance-authority";

// Hover swaps the colour with no transition; only the press is animated.
export const button = cva(
  "press inline-flex shrink-0 items-center gap-2 rounded-xl font-medium whitespace-nowrap select-none",
  {
    defaultVariants: { intent: "primary", size: "medium" },
    variants: {
      intent: {
        primary: "bg-gray-1000 text-background-200 hover:bg-gray-900",
        secondary:
          "bg-background-100 hover:bg-gray-100 active:bg-gray-200 shadow-[inset_0_0_0_1px_var(--color-gray-400)]",
      },
      size: {
        medium: "h-9 px-3.5 text-[14px]",
        small: "h-8 px-3 text-[14px]",
      },
    },
  }
);
