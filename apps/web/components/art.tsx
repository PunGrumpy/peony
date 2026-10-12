import { cn } from "cn";
import Image from "next/image";

import bloom from "@/assets/art/bloom.jpg";
import connect from "@/assets/art/connect.jpg";
import field from "@/assets/art/field.jpg";
import open from "@/assets/art/open.jpg";
import route from "@/assets/art/route.jpg";

// Peonies out of focus, drawn by assets/art/generate.html. They carry no meaning, so they have no alt text.
const art = { bloom, connect, field, open, route };

// Fills its parent, which needs `relative` and `overflow-hidden`.
export const Art = ({
  className,
  eager = false,
  name,
  sizes,
}: {
  className?: string;
  eager?: boolean;
  name: keyof typeof art;
  sizes: string;
}) => (
  <Image
    src={art[name]}
    alt=""
    fill
    sizes={sizes}
    placeholder="blur"
    loading={eager ? "eager" : "lazy"}
    fetchPriority={eager ? "high" : undefined}
    className={cn("-z-10 object-cover", className)}
  />
);
