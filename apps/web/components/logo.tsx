import { cn } from "cn";

// Both rings come from PeonyUI/PeonyMark.swift, on a 32pt square.
const OUTER =
  "M15.38 10.4Q16 10.96 16.62 10.4C18.62 9.15 22.24 6.86 22.24 3.74C22.12 -1.35 9.88 -1.35 9.76 3.74C9.76 6.86 13.38 9.15 15.38 10.4ZM21.13 13.68Q20.79 14.44 21.52 14.86C23.32 16.38 26.62 19.11 29.58 18.15C34.39 16.45 30.61 4.82 25.73 6.28C22.76 7.24 21.7 11.39 21.13 13.68ZM19.8 20.16Q18.96 20.08 18.79 20.9C17.9 23.08 16.32 27.06 18.16 29.58C21.25 33.63 31.15 26.44 28.25 22.25C26.42 19.72 22.15 20 19.8 20.16ZM13.21 20.9Q13.04 20.08 12.2 20.16C9.85 20 5.58 19.72 3.75 22.25C0.85 26.44 10.75 33.63 13.84 29.58C15.68 27.06 14.1 23.08 13.21 20.9ZM10.48 14.86Q11.21 14.44 10.87 13.68C10.3 11.39 9.24 7.24 6.27 6.28C1.39 4.82 -2.39 16.45 2.42 18.15C5.38 19.11 8.68 16.38 10.48 14.86Z";
const INNER =
  "M16.51 14.99Q16.56 15.23 16.81 15.2C17.57 15.16 18.85 15.2 19.56 14.23C20.75 12.53 17.83 10.41 16.58 12.07C15.88 13.04 16.32 14.25 16.51 14.99ZM17.12 16.17Q16.91 16.29 17.01 16.52C17.28 17.23 17.64 18.47 18.78 18.84C20.77 19.45 21.88 16.02 19.92 15.34C18.78 14.97 17.76 15.76 17.12 16.17ZM16.18 17.12Q16 16.95 15.82 17.12C15.23 17.6 14.16 18.32 14.16 19.52C14.2 21.6 17.8 21.6 17.84 19.52C17.84 18.32 16.77 17.6 16.18 17.12ZM14.99 16.52Q15.09 16.29 14.88 16.17C14.24 15.76 13.22 14.97 12.08 15.34C10.12 16.02 11.23 19.45 13.22 18.84C14.36 18.47 14.72 17.23 14.99 16.52ZM15.19 15.2Q15.44 15.23 15.49 14.99C15.68 14.25 16.12 13.04 15.42 12.07C14.17 10.41 11.25 12.53 12.44 14.23C13.15 15.2 14.43 15.16 15.19 15.2Z";

// The rings strengthen from the centre out, as the menu bar glyph does while a tunnel comes up.
export const Mark = ({
  className,
  filled = 2,
}: {
  className?: string;
  filled?: 0 | 1 | 2;
}) => (
  <svg
    viewBox="0 0 32 32"
    fill="currentColor"
    aria-hidden="true"
    className={className}
  >
    <path d={INNER} opacity={filled > 0 ? 1 : 0.35} />
    <path d={OUTER} opacity={filled > 1 ? 1 : 0.35} />
  </svg>
);

export const Logo = ({ className }: { className?: string }) => (
  <span className={cn("inline-flex items-center gap-2", className)}>
    {/* The flower's weight sits at its centre, 2.4px below the middle of the capital P. One pixel up splits the difference with the lowercase. */}
    <Mark className="text-rose-700 size-6 -translate-y-px" />
    <span className="font-serif text-[22px] leading-none font-medium tracking-[-0.035em]">
      Peony
    </span>
  </span>
);
