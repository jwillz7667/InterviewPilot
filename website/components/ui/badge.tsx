import { cn } from "@/lib/utils";
import type { HTMLAttributes } from "react";

export function Badge({
  className,
  variant = "default",
  ...props
}: HTMLAttributes<HTMLSpanElement> & { variant?: "default" | "brand" | "outline" | "success" }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-medium",
        variant === "default" && "bg-[var(--color-bg-muted)] text-[var(--color-fg-muted)]",
        variant === "brand" &&
          "bg-[var(--color-brand-100)] text-[var(--color-brand-700)] dark:bg-[var(--color-brand-900)] dark:text-[var(--color-brand-200)]",
        variant === "outline" &&
          "border border-[var(--color-border-strong)] bg-transparent text-[var(--color-fg-muted)]",
        variant === "success" &&
          "bg-[oklch(94%_0.06_145)] text-[oklch(35%_0.15_145)] dark:bg-[oklch(25%_0.1_145)] dark:text-[oklch(85%_0.12_145)]",
        className,
      )}
      {...props}
    />
  );
}
