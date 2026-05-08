import { siteConfig } from "./site";

type JsonLd = Record<string, unknown>;

export function organizationSchema(): JsonLd {
  return {
    "@context": "https://schema.org",
    "@type": "Organization",
    "@id": `${siteConfig.url}#organization`,
    name: siteConfig.legalEntity,
    url: siteConfig.url,
    logo: `${siteConfig.url}/icon-512.png`,
    sameAs: [
      siteConfig.social.twitter,
      siteConfig.social.linkedin,
      siteConfig.social.github,
    ],
    contactPoint: {
      "@type": "ContactPoint",
      email: siteConfig.email,
      contactType: "customer support",
      availableLanguage: ["en"],
    },
  };
}

export function websiteSchema(): JsonLd {
  return {
    "@context": "https://schema.org",
    "@type": "WebSite",
    "@id": `${siteConfig.url}#website`,
    url: siteConfig.url,
    name: siteConfig.name,
    description: siteConfig.description,
    publisher: { "@id": `${siteConfig.url}#organization` },
    potentialAction: {
      "@type": "SearchAction",
      target: { "@type": "EntryPoint", urlTemplate: `${siteConfig.url}/blog?q={search_term_string}` },
      "query-input": "required name=search_term_string",
    },
  };
}

export function softwareApplicationSchema(): JsonLd {
  return {
    "@context": "https://schema.org",
    "@type": "MobileApplication",
    name: siteConfig.name,
    applicationCategory: "BusinessApplication",
    operatingSystem: "iOS",
    offers: [
      {
        "@type": "Offer",
        name: "Free",
        price: "0",
        priceCurrency: "USD",
      },
      {
        "@type": "Offer",
        name: "Pro Monthly",
        price: "19.99",
        priceCurrency: "USD",
        priceSpecification: {
          "@type": "UnitPriceSpecification",
          price: "19.99",
          priceCurrency: "USD",
          billingDuration: "P1M",
        },
      },
      {
        "@type": "Offer",
        name: "Premium Monthly",
        price: "49.99",
        priceCurrency: "USD",
        priceSpecification: {
          "@type": "UnitPriceSpecification",
          price: "49.99",
          priceCurrency: "USD",
          billingDuration: "P1M",
        },
      },
    ],
    aggregateRating: {
      "@type": "AggregateRating",
      ratingValue: "4.8",
      ratingCount: "1247",
      bestRating: "5",
    },
  };
}

export function articleSchema(input: {
  title: string;
  description: string;
  slug: string;
  publishedAt: string;
  updatedAt?: string;
  author: string;
  image?: string;
  keywords?: string[];
}): JsonLd {
  return {
    "@context": "https://schema.org",
    "@type": "Article",
    headline: input.title,
    description: input.description,
    image: input.image ? [input.image] : [`${siteConfig.url}/og.png`],
    datePublished: input.publishedAt,
    dateModified: input.updatedAt ?? input.publishedAt,
    author: {
      "@type": "Person",
      name: input.author,
      url: `${siteConfig.url}/blog`,
    },
    publisher: {
      "@type": "Organization",
      name: siteConfig.legalEntity,
      logo: { "@type": "ImageObject", url: `${siteConfig.url}/icon-512.png` },
    },
    mainEntityOfPage: {
      "@type": "WebPage",
      "@id": `${siteConfig.url}/blog/${input.slug}`,
    },
    keywords: input.keywords?.join(", "),
  };
}

export function breadcrumbSchema(crumbs: { name: string; href: string }[]): JsonLd {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: crumbs.map((crumb, idx) => ({
      "@type": "ListItem",
      position: idx + 1,
      name: crumb.name,
      item: `${siteConfig.url}${crumb.href}`,
    })),
  };
}

export function faqSchema(faqs: { question: string; answer: string }[]): JsonLd {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqs.map((faq) => ({
      "@type": "Question",
      name: faq.question,
      acceptedAnswer: { "@type": "Answer", text: faq.answer },
    })),
  };
}

