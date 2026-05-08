import type { MDXRemoteProps } from "next-mdx-remote/rsc";
import rehypeSlug from "rehype-slug";
import rehypeAutolinkHeadings from "rehype-autolink-headings";
import rehypePrettyCode from "rehype-pretty-code";
import remarkGfm from "remark-gfm";

export const mdxOptions: MDXRemoteProps["options"] = {
  parseFrontmatter: false,
  mdxOptions: {
    remarkPlugins: [remarkGfm],
    rehypePlugins: [
      rehypeSlug,
      [
        rehypeAutolinkHeadings,
        {
          behavior: "append",
          properties: {
            className: ["heading-anchor"],
            "aria-label": "Link to this section",
          },
        },
      ],
      [
        rehypePrettyCode,
        {
          theme: { dark: "github-dark-dimmed", light: "github-light" },
          keepBackground: false,
          defaultLang: "ts",
        },
      ],
    ],
  },
};
