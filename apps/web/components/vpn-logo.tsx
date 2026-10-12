import { cn } from "cn";

// Drawn as a mask so every logo takes the text colour, in both themes.
export const VpnLogo = ({
  id,
  className,
}: {
  id: string;
  className?: string;
}) => (
  <span
    aria-hidden="true"
    className={cn(
      "shrink-0 bg-current [mask-size:contain] [mask-position:center] [mask-repeat:no-repeat]",
      className
    )}
    style={{
      WebkitMaskImage: `url(/vpns/${id}.svg)`,
      maskImage: `url(/vpns/${id}.svg)`,
    }}
  />
);
