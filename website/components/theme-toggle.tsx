"use client";

import { Moon, Sun, Monitor } from "lucide-react";
import { useTheme } from "next-themes";
import { useEffect, useState } from "react";
import { cn } from "@/lib/utils";

export function ThemeToggle({ className }: { className?: string }) {
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  useEffect(() => setMounted(true), []);

  if (!mounted) {
    return (
      <div
        className={cn("h-9 w-[7.5rem] rounded-full bg-[var(--color-bg-muted)]", className)}
        aria-hidden
      />
    );
  }

  const options = [
    { value: "light", icon: Sun, label: "Light" },
    { value: "system", icon: Monitor, label: "System" },
    { value: "dark", icon: Moon, label: "Dark" },
  ] as const;

  return (
    <div
      role="radiogroup"
      aria-label="Color theme"
      className={cn(
        "inline-flex items-center gap-0.5 rounded-full border border-[var(--color-border)] bg-[var(--color-bg-subtle)] p-0.5",
        className,
      )}
    >
      {options.map(({ value, icon: Icon, label }) => {
        const active = theme === value;
        return (
          <button
            key={value}
            role="radio"
            aria-checked={active}
            aria-label={label}
            onClick={() => setTheme(value)}
            className={cn(
              "inline-flex h-8 w-8 items-center justify-center rounded-full transition-colors",
              active
                ? "bg-[var(--color-bg)] text-[var(--color-fg)] shadow-sm"
                : "text-[var(--color-fg-subtle)] hover:text-[var(--color-fg)]",
            )}
          >
            <Icon className="h-4 w-4" />
          </button>
        );
      })}
    </div>
  );
}
