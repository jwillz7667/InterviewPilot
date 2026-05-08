import Link from "next/link";
import { cn } from "@/lib/utils";

export function Logo({ className, href = "/" }: { className?: string; href?: string }) {
  return (
    <Link
      href={href}
      className={cn(
        "flex items-center gap-2.5 text-[var(--color-fg)] no-underline transition-opacity hover:opacity-80",
        className,
      )}
      aria-label="Interview Ace home"
    >
      <span
        aria-hidden
        className="inline-flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-[var(--color-brand-500)] to-[var(--color-brand-700)] text-white shadow-[var(--shadow-sharp)]"
      >
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
          <path
            d="M3 13L8 3L13 13H10.5L8 8L5.5 13H3Z"
            fill="currentColor"
          />
          <path
            d="M6.2 11H9.8"
            stroke="currentColor"
            strokeWidth="1.4"
            strokeLinecap="round"
          />
        </svg>
      </span>
      <span className="font-display text-base font-bold tracking-tight">
        Interview <span className="text-[var(--color-brand-600)]">Ace</span>
      </span>
    </Link>
  );
}
