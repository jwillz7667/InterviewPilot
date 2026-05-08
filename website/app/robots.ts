import type { MetadataRoute } from "next";
import { siteConfig } from "@/lib/site";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: "*",
        allow: ["/"],
        disallow: ["/api/", "/_next/", "/admin/"],
      },
      { userAgent: "GPTBot", allow: ["/blog", "/"] },
      { userAgent: "ClaudeBot", allow: ["/blog", "/"] },
      { userAgent: "PerplexityBot", allow: ["/blog", "/"] },
      { userAgent: "Google-Extended", allow: ["/blog", "/"] },
      { userAgent: "OAI-SearchBot", allow: ["/blog", "/"] },
      { userAgent: "CCBot", disallow: "/" },
    ],
    sitemap: `${siteConfig.url}/sitemap.xml`,
    host: siteConfig.url,
  };
}
