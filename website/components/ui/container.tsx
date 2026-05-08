import { cn } from "@/lib/utils";
import type { HTMLAttributes } from "react";

export function Container({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "mx-auto w-full max-w-7xl px-6 sm:px-8 lg:px-10",
        className,
      )}
      {...props}
    />
  );
}

export function Section({ className, ...props }: HTMLAttributes<HTMLElement>) {
  return (
    <section
      className={cn("relative py-20 sm:py-28 lg:py-32", className)}
      {...props}
    />
  );
}
