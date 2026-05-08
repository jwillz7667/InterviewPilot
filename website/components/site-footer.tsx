import Link from "next/link";
import { Logo } from "@/components/ui/logo";
import { siteConfig } from "@/lib/site";

const sections: { title: string; links: { href: string; label: string }[] }[] = [
  {
    title: "Product",
    links: [
      { href: "/#features", label: "Features" },
      { href: "/#how-it-works", label: "How it works" },
      { href: "/pricing", label: "Pricing" },
      { href: siteConfig.appStore, label: "Download for iOS" },
    ],
  },
  {
    title: "Resources",
    links: [
      { href: "/blog", label: "Blog" },
      { href: "/blog/system-design-interview-2026", label: "System design guide" },
      { href: "/blog/star-method-reimagined", label: "STAR method" },
      { href: "/blog/staff-engineer-interview-questions", label: "Staff engineer prep" },
    ],
  },
  {
    title: "Company",
    links: [
      { href: "/privacy", label: "Privacy" },
      { href: "/terms", label: "Terms" },
      { href: `mailto:${siteConfig.email}`, label: "Contact" },
      { href: "/blog/is-ai-interview-help-cheating", label: "Our ethics stance" },
    ],
  },
];

export function SiteFooter() {
  return (
    <footer className="border-t border-[var(--color-border)] bg-[var(--color-bg-subtle)]">
      <div className="mx-auto w-full max-w-7xl px-6 py-16 sm:px-8 lg:px-10">
        <div className="grid gap-12 lg:grid-cols-[1.5fr_3fr]">
          <div className="max-w-sm">
            <Logo />
            <p className="mt-4 text-sm leading-relaxed text-[var(--color-fg-muted)]">
              {siteConfig.description}
            </p>
            <div className="mt-6 flex items-center gap-4 text-sm text-[var(--color-fg-subtle)]">
              <a
                href={siteConfig.social.twitter}
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-[var(--color-fg)]"
              >
                Twitter
              </a>
              <span aria-hidden>·</span>
              <a
                href={siteConfig.social.linkedin}
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-[var(--color-fg)]"
              >
                LinkedIn
              </a>
              <span aria-hidden>·</span>
              <a
                href={siteConfig.social.github}
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-[var(--color-fg)]"
              >
                GitHub
              </a>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-8 sm:grid-cols-3">
            {sections.map((section) => (
              <div key={section.title}>
                <h3 className="text-sm font-semibold text-[var(--color-fg)]">
                  {section.title}
                </h3>
                <ul className="mt-4 space-y-3 text-sm">
                  {section.links.map((link) => (
                    <li key={link.href}>
                      <Link
                        href={link.href}
                        className="text-[var(--color-fg-muted)] hover:text-[var(--color-fg)]"
                      >
                        {link.label}
                      </Link>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </div>
        <div className="mt-12 flex flex-col items-start justify-between gap-4 border-t border-[var(--color-border)] pt-8 text-xs text-[var(--color-fg-subtle)] sm:flex-row sm:items-center">
          <p>
            &copy; {new Date().getFullYear()} {siteConfig.legalEntity}. All rights reserved.
          </p>
          <p className="flex items-center gap-3">
            <span>{siteConfig.legalAddress}</span>
            <span aria-hidden>·</span>
            <a
              href={`mailto:${siteConfig.email}`}
              className="hover:text-[var(--color-fg)]"
            >
              {siteConfig.email}
            </a>
          </p>
        </div>
      </div>
    </footer>
  );
}
