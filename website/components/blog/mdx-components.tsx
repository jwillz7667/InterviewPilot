import type { MDXComponents } from "mdx/types";
import Link from "next/link";
import Image from "next/image";
import { cn } from "@/lib/utils";

export function getMdxComponents(): MDXComponents {
  return {
    h1: ({ className, ...props }) => (
      <h1
        className={cn(
          "mt-12 scroll-mt-24 text-balance font-display text-4xl font-bold tracking-tight first:mt-0",
          className,
        )}
        {...props}
      />
    ),
    h2: ({ className, ...props }) => (
      <h2
        className={cn(
          "mt-12 scroll-mt-24 text-balance font-display text-3xl font-bold tracking-tight",
          className,
        )}
        {...props}
      />
    ),
    h3: ({ className, ...props }) => (
      <h3
        className={cn(
          "mt-10 scroll-mt-24 text-balance font-display text-2xl font-semibold tracking-tight",
          className,
        )}
        {...props}
      />
    ),
    h4: ({ className, ...props }) => (
      <h4
        className={cn(
          "mt-8 scroll-mt-24 font-display text-xl font-semibold tracking-tight",
          className,
        )}
        {...props}
      />
    ),
    p: ({ className, ...props }) => (
      <p
        className={cn(
          "mt-5 text-pretty text-[17px] leading-[1.75] text-[var(--color-fg)]",
          className,
        )}
        {...props}
      />
    ),
    a: ({ href = "", className, ...props }) => {
      const isExternal = href.startsWith("http");
      const baseClasses = cn(
        "font-medium text-[var(--color-brand-600)] underline underline-offset-[3px] decoration-[var(--color-brand-300)] hover:decoration-[var(--color-brand-600)] dark:text-[var(--color-brand-300)] dark:decoration-[var(--color-brand-700)]",
        className,
      );
      if (isExternal) {
        return (
          <a href={href} className={baseClasses} target="_blank" rel="noopener noreferrer" {...props} />
        );
      }
      return <Link href={href} className={baseClasses} {...(props as Record<string, unknown>)} />;
    },
    ul: ({ className, ...props }) => (
      <ul className={cn("mt-5 ml-6 list-disc space-y-2 text-[17px] leading-[1.75] marker:text-[var(--color-fg-subtle)]", className)} {...props} />
    ),
    ol: ({ className, ...props }) => (
      <ol className={cn("mt-5 ml-6 list-decimal space-y-2 text-[17px] leading-[1.75] marker:text-[var(--color-fg-muted)]", className)} {...props} />
    ),
    li: ({ className, ...props }) => (
      <li className={cn("text-pretty text-[var(--color-fg)]", className)} {...props} />
    ),
    blockquote: ({ className, ...props }) => (
      <blockquote
        className={cn(
          "mt-6 border-l-4 border-[var(--color-brand-500)] bg-[var(--color-bg-subtle)] py-4 pl-6 pr-4 italic text-[var(--color-fg-muted)]",
          className,
        )}
        {...props}
      />
    ),
    code: ({ className, ...props }) => (
      <code
        className={cn(
          "rounded-md bg-[var(--color-bg-muted)] px-1.5 py-0.5 font-mono text-[0.875em] text-[var(--color-fg)] before:content-none after:content-none",
          className,
        )}
        {...props}
      />
    ),
    pre: ({ className, ...props }) => (
      <pre
        className={cn(
          "mt-6 overflow-x-auto rounded-2xl border border-[var(--color-border)] bg-[var(--color-bg-muted)] p-5 text-[14px] leading-relaxed scrollbar-thin",
          className,
        )}
        {...props}
      />
    ),
    table: ({ className, ...props }) => (
      <div className="mt-6 overflow-x-auto rounded-xl border border-[var(--color-border)]">
        <table className={cn("w-full border-collapse text-[15px]", className)} {...props} />
      </div>
    ),
    th: ({ className, ...props }) => (
      <th
        className={cn(
          "border-b border-[var(--color-border)] bg-[var(--color-bg-subtle)] px-4 py-3 text-left font-semibold text-[var(--color-fg)]",
          className,
        )}
        {...props}
      />
    ),
    td: ({ className, ...props }) => (
      <td
        className={cn(
          "border-b border-[var(--color-border)] px-4 py-3 text-[var(--color-fg-muted)] last:border-b-0",
          className,
        )}
        {...props}
      />
    ),
    hr: ({ className, ...props }) => (
      <hr className={cn("my-12 border-[var(--color-border)]", className)} {...props} />
    ),
    img: ({ alt, className, src, ...rest }) => (
      <Image
        src={typeof src === "string" ? src : ""}
        alt={alt ?? ""}
        width={1200}
        height={675}
        className={cn("mt-6 rounded-2xl border border-[var(--color-border)]", className)}
        {...(rest as Record<string, unknown>)}
      />
    ),
    Callout: ({ children, type = "info" }: { children: React.ReactNode; type?: "info" | "warn" | "success" }) => (
      <aside
        className={cn(
          "mt-6 rounded-2xl border-l-4 p-5 text-[15px] leading-relaxed",
          type === "info" && "border-[var(--color-brand-500)] bg-[var(--color-brand-50)] text-[var(--color-fg)] dark:bg-[var(--color-brand-900)]/30",
          type === "warn" && "border-[var(--color-warning)] bg-[oklch(97%_0.05_85)] text-[var(--color-fg)] dark:bg-[oklch(25%_0.05_85)]",
          type === "success" && "border-[var(--color-success)] bg-[oklch(97%_0.04_145)] text-[var(--color-fg)] dark:bg-[oklch(22%_0.06_145)]",
        )}
      >
        {children}
      </aside>
    ),
  };
}
