export const siteConfig = {
  name: "Interview Ace",
  shortName: "Interview Ace",
  domain: "interviewace.app",
  url: "https://interviewace.app",
  ogImage: "https://interviewace.app/og.png",
  description:
    "Real-time AI interview coach. Live transcription, instant tailored answers, post-interview analytics. Built by senior engineers for senior interviews.",
  tagline: "Pass any interview. With elite AI in your ear.",
  appStore: "https://apps.apple.com/app/interview-ace/id0000000000",
  twitter: "@interviewace",
  email: "support@interviewace.app",
  legalEntity: "Interview Ace, LLC",
  legalAddress: "Wilmington, Delaware, USA",
  founderName: "Interview Ace Team",
  appBundleId: "com.res.jobhopperAI",
  social: {
    twitter: "https://twitter.com/interviewace",
    linkedin: "https://www.linkedin.com/company/interviewace",
    github: "https://github.com/interviewace",
  },
  pricing: {
    free: { price: "Free", period: "forever" },
    pro: { price: "$19.99", period: "month", yearly: "$179.99" },
    premium: { price: "$49.99", period: "month", yearly: "$449.99" },
  },
} as const;

export type SiteConfig = typeof siteConfig;
