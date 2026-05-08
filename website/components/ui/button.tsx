import { cva, type VariantProps } from "class-variance-authority";
import Link from "next/link";
import * as React from "react";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-full font-medium transition-all duration-200 ease-out focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--color-bg)] focus-visible:ring-[var(--color-brand-500)] disabled:pointer-events-none disabled:opacity-50 active:scale-[0.98]",
  {
    variants: {
      variant: {
        primary:
          "bg-[var(--color-fg)] text-[var(--color-bg)] hover:opacity-90 shadow-[var(--shadow-sharp)]",
        brand:
          "bg-gradient-to-br from-[var(--color-brand-500)] to-[var(--color-brand-700)] text-white shadow-[var(--shadow-glow)] hover:shadow-[var(--shadow-floating)] hover:brightness-110",
        secondary:
          "bg-[var(--color-bg-muted)] text-[var(--color-fg)] hover:bg-[var(--color-bg-subtle)] border border-[var(--color-border)]",
        outline:
          "bg-transparent text-[var(--color-fg)] border border-[var(--color-border-strong)] hover:bg-[var(--color-bg-subtle)]",
        ghost:
          "bg-transparent text-[var(--color-fg)] hover:bg-[var(--color-bg-subtle)]",
        link: "text-[var(--color-brand-600)] underline-offset-4 hover:underline rounded-none",
      },
      size: {
        sm: "h-9 px-4 text-sm",
        md: "h-11 px-6 text-[0.9375rem]",
        lg: "h-13 px-8 text-base",
        xl: "h-14 px-10 text-base",
        icon: "h-10 w-10",
      },
    },
    defaultVariants: { variant: "primary", size: "md" },
  },
);

type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> &
  VariantProps<typeof buttonVariants>;

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, ...props }, ref) => (
    <button ref={ref} className={cn(buttonVariants({ variant, size, className }))} {...props} />
  ),
);
Button.displayName = "Button";

type ButtonLinkProps = React.AnchorHTMLAttributes<HTMLAnchorElement> &
  VariantProps<typeof buttonVariants> & { href: string };

export const ButtonLink = React.forwardRef<HTMLAnchorElement, ButtonLinkProps>(
  ({ className, variant, size, href, ...props }, ref) => {
    const isExternal = href.startsWith("http");
    if (isExternal) {
      return (
        <a
          ref={ref}
          href={href}
          className={cn(buttonVariants({ variant, size, className }))}
          target="_blank"
          rel="noopener noreferrer"
          {...props}
        />
      );
    }
    return (
      <Link
        ref={ref}
        href={href}
        className={cn(buttonVariants({ variant, size, className }))}
        {...props}
      />
    );
  },
);
ButtonLink.displayName = "ButtonLink";

export { buttonVariants };
