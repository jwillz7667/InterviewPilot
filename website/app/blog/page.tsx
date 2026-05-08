import type { Metadata } from "next";
import Link from "next/link";
import { Container } from "@/components/ui/container";
import { Badge } from "@/components/ui/badge";
import { getAllPosts } from "@/lib/blog";
import { formatDate } from "@/lib/utils";
import { siteConfig } from "@/lib/site";
import { JsonLd } from "@/components/json-ld";
import { breadcrumbSchema } from "@/lib/structured-data";
import { ArrowUpRight, Clock } from "lucide-react";

export const metadata: Metadata = {
  title: "Blog — Interview prep, AI, and engineering career playbooks",
  description:
    "Long-form guides on system design interviews, behavioral STAR answers, AI-assisted prep, and how to interview at the staff engineer level. Written by senior engineers and hiring managers.",
  alternates: {
    canonical: "/blog",
    types: { "application/rss+xml": [{ url: "/feed.xml", title: "Interview Ace Blog RSS" }] },
  },
  openGraph: {
    title: `Blog · ${siteConfig.name}`,
    description: "Interview prep playbooks from senior engineers.",
    url: `${siteConfig.url}/blog`,
  },
};

export default async function BlogIndexPage() {
  const posts = await getAllPosts();
  const [featured, ...rest] = posts;

  return (
    <>
      <JsonLd
        data={breadcrumbSchema([
          { name: "Home", href: "/" },
          { name: "Blog", href: "/blog" },
        ])}
      />
      <div className="border-b border-[var(--color-border)] bg-[var(--color-bg-subtle)] pt-16 pb-12">
        <Container>
          <div className="mx-auto max-w-3xl text-center">
            <Badge variant="brand">Blog</Badge>
            <h1 className="mt-4 text-balance text-5xl font-bold tracking-tight sm:text-6xl">
              The interview prep playbook.
            </h1>
            <p className="mt-5 text-lg text-[var(--color-fg-muted)]">
              Written by senior engineers and hiring managers who've sat on both sides of the table.
              No fluff, no generic STAR templates — only what actually moves the needle.
            </p>
          </div>
        </Container>
      </div>

      <Container className="py-16">
        {featured && (
          <article className="group relative overflow-hidden rounded-3xl border border-[var(--color-border)] bg-gradient-to-br from-[var(--color-brand-50)] via-[var(--color-bg)] to-[var(--color-bg)] p-8 transition-all hover:shadow-[var(--shadow-floating)] dark:from-[var(--color-brand-900)]/30 sm:p-12">
            <Link
              href={`/blog/${featured.slug}`}
              aria-label={featured.title}
              className="absolute inset-0 z-10"
            />
            <div className="grid gap-8 lg:grid-cols-[2fr_1fr] lg:items-end">
              <div>
                <div className="flex items-center gap-2 text-xs">
                  <Badge variant="brand">Featured</Badge>
                  <span className="text-[var(--color-fg-subtle)]">{featured.category}</span>
                </div>
                <h2 className="mt-4 text-balance font-display text-3xl font-bold tracking-tight sm:text-4xl">
                  {featured.title}
                </h2>
                <p className="mt-4 max-w-2xl text-balance text-[var(--color-fg-muted)]">
                  {featured.description}
                </p>
                <div className="mt-6 flex flex-wrap items-center gap-3 text-sm text-[var(--color-fg-subtle)]">
                  <span>{featured.author}</span>
                  <span aria-hidden>·</span>
                  <time dateTime={featured.publishedAt}>{formatDate(featured.publishedAt)}</time>
                  <span aria-hidden>·</span>
                  <span className="flex items-center gap-1">
                    <Clock className="h-3.5 w-3.5" />
                    {featured.readingTime}
                  </span>
                </div>
              </div>
              <div className="flex justify-end text-[var(--color-brand-600)] transition-transform duration-300 group-hover:-translate-y-1 dark:text-[var(--color-brand-300)]">
                <ArrowUpRight className="h-10 w-10" />
              </div>
            </div>
          </article>
        )}

        <div className="mt-12 grid grid-cols-1 gap-6 md:grid-cols-2">
          {rest.map((post) => (
            <article
              key={post.slug}
              className="group relative flex flex-col rounded-3xl border border-[var(--color-border)] bg-[var(--color-bg-subtle)] p-7 transition-all hover:border-[var(--color-border-strong)] hover:shadow-[var(--shadow-sharp)]"
            >
              <Link href={`/blog/${post.slug}`} className="absolute inset-0 z-10" aria-label={post.title} />
              <div className="flex items-center gap-2 text-xs text-[var(--color-fg-subtle)]">
                <span>{post.category}</span>
                <span aria-hidden>·</span>
                <span>{post.readingTime}</span>
              </div>
              <h3 className="mt-4 font-display text-xl font-bold tracking-tight">{post.title}</h3>
              <p className="mt-3 text-pretty text-[15px] leading-relaxed text-[var(--color-fg-muted)]">
                {post.description}
              </p>
              <div className="mt-6 flex items-center gap-3 border-t border-[var(--color-border)] pt-4 text-sm text-[var(--color-fg-subtle)]">
                <span>{post.author}</span>
                <span aria-hidden>·</span>
                <time dateTime={post.publishedAt}>{formatDate(post.publishedAt)}</time>
              </div>
            </article>
          ))}
        </div>

        {posts.length === 0 && (
          <p className="text-center text-[var(--color-fg-muted)]">No posts yet — check back soon.</p>
        )}
      </Container>
    </>
  );
}
