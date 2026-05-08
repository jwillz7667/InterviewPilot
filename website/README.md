# Interview Ace — Marketing Site

Next.js 15 marketing site, blog, and legal pages for Interview Ace.

## Stack

- Next.js 15.3+ (App Router, Turbopack, RSC, Partial Prerendering)
- React 19.1
- Tailwind CSS v4 (CSS-first `@theme` config)
- Motion 12 (animations)
- next-mdx-remote 5 + rehype-pretty-code (Shiki) for the blog
- next-themes for dark mode
- @vercel/og for dynamic OG images

## Local development

```bash
npm install
npm run dev
# open http://localhost:3000
```

## Scripts

- `npm run dev` — start dev server on `:3000`
- `npm run build` — production build
- `npm run start` — start production server
- `npm run lint` — ESLint
- `npm run typecheck` — TypeScript no-emit check
- `npm run format` — Prettier

## Deploying to Vercel

1. Push this repo to GitHub
2. In Vercel, **New Project** → import the repo
3. Set **Root Directory** to `website`
4. Framework preset auto-detects as **Next.js**
5. Add environment variables (see `.env.example`):
   - `NEXT_PUBLIC_SITE_URL` — public URL of the site (e.g., `https://interviewace.app`)
6. Deploy

The `vercel.json` in this directory locks framework, build commands, region (`iad1`), and content-type headers for `llms.txt` / `ai.txt` / `feed.xml`.

## Structure

```
app/                 App Router routes
  blog/              Blog index and [slug] dynamic route
  pricing/           Standalone pricing page
  privacy/           Privacy policy (GDPR + CCPA + COPPA)
  terms/             Terms of service (Apple disclosures + arbitration)
  og/                Dynamic OG image (edge runtime)
  feed.xml/          RSS feed
  manifest.ts        Web app manifest
  robots.ts          robots.txt with AI-bot rules
  sitemap.ts         XML sitemap (incl. blog posts)
  layout.tsx         Root layout, default metadata, fonts
  globals.css        Tailwind v4 + design tokens
components/
  sections/          Landing page sections (hero, features, pricing, FAQ, etc.)
  blog/              Blog-specific MDX components
  ui/                Buttons, badge, container, logo
  site-header.tsx    Sticky header with theme toggle
  site-footer.tsx    Footer
content/posts/       MDX blog posts
lib/
  blog.ts            Filesystem-based MDX loader
  site.ts            Site config (name, URL, pricing)
  structured-data.ts JSON-LD schema builders
  mdx-options.ts     Rehype/remark plugin config
  utils.ts           cn(), formatDate(), absoluteUrl()
public/
  llms.txt           AI-crawler discovery (2026 standard)
  ai.txt             AI training/use policy
```

## SEO

- Per-route `metadata` with canonical, OG, Twitter cards
- JSON-LD on landing (`Organization`, `WebSite`, `MobileApplication`), pricing (`MobileApplication` + breadcrumb), blog posts (`Article` + breadcrumb), FAQ (`FAQPage`)
- Dynamic OG images via `/og?title=&subtitle=&eyebrow=`
- `sitemap.xml`, `robots.txt`, `feed.xml` all generated
- `llms.txt` and `ai.txt` for AI-crawler standards
- Apple Web App and PWA manifest

## Adding a blog post

Drop a new `.mdx` file in `content/posts/`. Frontmatter:

```yaml
---
title: "Your title"
description: "One-sentence summary used in OG and search results"
publishedAt: "2026-05-01"
updatedAt: "2026-05-08"     # optional
author: "Author Name"
authorRole: "Senior Engineer at X"  # optional
category: "System Design"
tags: ["tag1", "tag2"]
ogTitle: "Override title"   # optional
ogSubtitle: "Override subtitle"  # optional
draft: false                 # optional, drafts excluded from production
---
```

Then write MDX. The post auto-appears in the index, sitemap, RSS feed, and gets a per-post OG image.
