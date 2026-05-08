import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { MDXRemote } from "next-mdx-remote/rsc";
import { ArrowLeft, Clock } from "lucide-react";
import { Container } from "@/components/ui/container";
import { Badge } from "@/components/ui/badge";
import { ButtonLink } from "@/components/ui/button";
import { JsonLd } from "@/components/json-ld";
import { getMdxComponents } from "@/components/blog/mdx-components";
import { mdxOptions } from "@/lib/mdx-options";
import { getAllPosts, getPostBySlug, getRelatedPosts } from "@/lib/blog";
import { articleSchema, breadcrumbSchema } from "@/lib/structured-data";
import { formatDate } from "@/lib/utils";
import { siteConfig } from "@/lib/site";

export async function generateStaticParams() {
  const posts = await getAllPosts();
  return posts.map((post) => ({ slug: post.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const post = await getPostBySlug(slug);
  if (!post) return {};

  const ogParams = new URLSearchParams({
    title: post.ogTitle ?? post.title,
    subtitle: post.ogSubtitle ?? post.description,
    eyebrow: post.category,
  });
  const ogUrl = `${siteConfig.url}/og?${ogParams.toString()}`;

  return {
    title: post.title,
    description: post.description,
    alternates: { canonical: `/blog/${post.slug}` },
    keywords: post.tags,
    authors: [{ name: post.author }],
    openGraph: {
      type: "article",
      url: `${siteConfig.url}/blog/${post.slug}`,
      title: post.title,
      description: post.description,
      publishedTime: post.publishedAt,
      modifiedTime: post.updatedAt ?? post.publishedAt,
      authors: [post.author],
      tags: post.tags,
      images: [{ url: ogUrl, width: 1200, height: 630, alt: post.title }],
    },
    twitter: {
      card: "summary_large_image",
      title: post.title,
      description: post.description,
      images: [ogUrl],
    },
  };
}

export default async function BlogPostPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const post = await getPostBySlug(slug);
  if (!post) notFound();

  const related = await getRelatedPosts(slug, 3);

  return (
    <>
      <JsonLd
        data={[
          articleSchema({
            title: post.title,
            description: post.description,
            slug: post.slug,
            publishedAt: post.publishedAt,
            updatedAt: post.updatedAt,
            author: post.author,
            keywords: post.tags,
          }),
          breadcrumbSchema([
            { name: "Home", href: "/" },
            { name: "Blog", href: "/blog" },
            { name: post.title, href: `/blog/${post.slug}` },
          ]),
        ]}
      />
      <article>
        <header className="border-b border-[var(--color-border)] bg-[var(--color-bg-subtle)] pt-12 pb-12 sm:pt-16">
          <Container>
            <Link
              href="/blog"
              className="inline-flex items-center gap-1.5 text-sm text-[var(--color-fg-muted)] hover:text-[var(--color-fg)]"
            >
              <ArrowLeft className="h-4 w-4" />
              All posts
            </Link>
            <div className="mt-6 flex flex-wrap items-center gap-2">
              <Badge variant="brand">{post.category}</Badge>
              {post.tags.slice(0, 3).map((tag) => (
                <Badge key={tag} variant="outline">
                  {tag}
                </Badge>
              ))}
            </div>
            <h1 className="mt-5 max-w-4xl text-balance font-display text-4xl font-bold leading-[1.1] tracking-tight sm:text-5xl lg:text-6xl">
              {post.title}
            </h1>
            <p className="mt-5 max-w-3xl text-balance text-lg leading-relaxed text-[var(--color-fg-muted)] sm:text-xl">
              {post.description}
            </p>
            <div className="mt-8 flex flex-wrap items-center gap-4 text-sm text-[var(--color-fg-subtle)]">
              <span className="font-medium text-[var(--color-fg)]">{post.author}</span>
              {post.authorRole && (
                <>
                  <span aria-hidden>·</span>
                  <span>{post.authorRole}</span>
                </>
              )}
              <span aria-hidden>·</span>
              <time dateTime={post.publishedAt}>{formatDate(post.publishedAt)}</time>
              <span aria-hidden>·</span>
              <span className="flex items-center gap-1">
                <Clock className="h-3.5 w-3.5" />
                {post.readingTime}
              </span>
            </div>
          </Container>
        </header>

        <Container className="py-12 sm:py-16">
          <div className="mx-auto max-w-3xl">
            <div className="prose-invert">
              <MDXRemote
                source={post.content}
                components={getMdxComponents()}
                options={mdxOptions}
              />
            </div>

            <hr className="my-16 border-[var(--color-border)]" />

            <div className="rounded-3xl border border-[var(--color-border)] bg-gradient-to-br from-[var(--color-brand-50)] via-[var(--color-bg-subtle)] to-[var(--color-bg-subtle)] p-8 dark:from-[var(--color-brand-900)]/30 sm:p-10">
              <h2 className="font-display text-2xl font-bold tracking-tight">
                Try {siteConfig.name} on your next interview
              </h2>
              <p className="mt-3 text-pretty text-[var(--color-fg-muted)]">
                Real-time transcription, tailored answers, and post-interview analytics.
                Free for the first interview, no card required.
              </p>
              <div className="mt-6 flex flex-wrap gap-3">
                <ButtonLink href={siteConfig.appStore} variant="brand" size="lg">
                  Download for iOS
                </ButtonLink>
                <ButtonLink href="/pricing" variant="outline" size="lg">
                  See pricing
                </ButtonLink>
              </div>
            </div>
          </div>
        </Container>
      </article>

      {related.length > 0 && (
        <section className="border-t border-[var(--color-border)] bg-[var(--color-bg-subtle)] py-16">
          <Container>
            <h2 className="font-display text-3xl font-bold tracking-tight">Keep reading</h2>
            <div className="mt-8 grid gap-6 md:grid-cols-3">
              {related.map((p) => (
                <Link
                  key={p.slug}
                  href={`/blog/${p.slug}`}
                  className="group flex flex-col rounded-3xl border border-[var(--color-border)] bg-[var(--color-bg)] p-6 transition-all hover:border-[var(--color-border-strong)] hover:shadow-[var(--shadow-sharp)]"
                >
                  <span className="text-xs text-[var(--color-fg-subtle)]">{p.category}</span>
                  <h3 className="mt-2 font-display text-lg font-semibold tracking-tight group-hover:text-[var(--color-brand-600)] dark:group-hover:text-[var(--color-brand-300)]">
                    {p.title}
                  </h3>
                  <p className="mt-2 line-clamp-3 text-sm text-[var(--color-fg-muted)]">
                    {p.description}
                  </p>
                </Link>
              ))}
            </div>
          </Container>
        </section>
      )}
    </>
  );
}
