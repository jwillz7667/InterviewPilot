import fs from "node:fs/promises";
import path from "node:path";
import matter from "gray-matter";
import readingTime from "reading-time";

export type Post = {
  slug: string;
  title: string;
  description: string;
  publishedAt: string;
  updatedAt?: string;
  author: string;
  authorRole?: string;
  tags: string[];
  category: string;
  readingTime: string;
  readingMinutes: number;
  ogTitle?: string;
  ogSubtitle?: string;
  draft?: boolean;
  content: string;
};

const POSTS_DIR = path.join(process.cwd(), "content", "posts");

async function readPostFile(file: string): Promise<Post | null> {
  if (!file.endsWith(".mdx")) return null;
  const slug = file.replace(/\.mdx$/, "");
  const raw = await fs.readFile(path.join(POSTS_DIR, file), "utf8");
  const { data, content } = matter(raw);
  if (data.draft) return null;
  const stats = readingTime(content);
  return {
    slug,
    title: data.title,
    description: data.description,
    publishedAt: data.publishedAt,
    updatedAt: data.updatedAt,
    author: data.author ?? "Interview Ace Team",
    authorRole: data.authorRole,
    tags: data.tags ?? [],
    category: data.category ?? "Interview prep",
    readingTime: stats.text,
    readingMinutes: Math.ceil(stats.minutes),
    ogTitle: data.ogTitle,
    ogSubtitle: data.ogSubtitle,
    draft: data.draft ?? false,
    content,
  };
}

export async function getAllPosts(): Promise<Post[]> {
  try {
    const files = await fs.readdir(POSTS_DIR);
    const posts = await Promise.all(files.map(readPostFile));
    return posts
      .filter((p): p is Post => p !== null)
      .sort((a, b) => new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime());
  } catch {
    return [];
  }
}

export async function getPostBySlug(slug: string): Promise<Post | null> {
  try {
    return await readPostFile(`${slug}.mdx`);
  } catch {
    return null;
  }
}

export async function getRelatedPosts(slug: string, limit = 3): Promise<Post[]> {
  const all = await getAllPosts();
  const current = all.find((p) => p.slug === slug);
  if (!current) return all.slice(0, limit);
  const tagSet = new Set(current.tags);
  return all
    .filter((p) => p.slug !== slug)
    .map((p) => ({
      post: p,
      score: p.tags.filter((t) => tagSet.has(t)).length + (p.category === current.category ? 1 : 0),
    }))
    .sort((a, b) => b.score - a.score || new Date(b.post.publishedAt).getTime() - new Date(a.post.publishedAt).getTime())
    .slice(0, limit)
    .map((x) => x.post);
}
