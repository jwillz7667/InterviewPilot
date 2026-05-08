import type { Metadata } from "next";
import { Pricing } from "@/components/sections/pricing";
import { FAQ } from "@/components/sections/faq";
import { CTA } from "@/components/sections/cta";
import { JsonLd } from "@/components/json-ld";
import { breadcrumbSchema, softwareApplicationSchema } from "@/lib/structured-data";
import { siteConfig } from "@/lib/site";

export const metadata: Metadata = {
  title: "Pricing — Free, Pro, and Premium plans",
  description:
    "Choose the plan that fits your job search. Free includes 3 standard + 1 premium interview every 30 days. Pro is $19.99/mo for active job seekers. Premium is unlimited and unlocks GPT-4.1 + o4-mini.",
  alternates: { canonical: "/pricing" },
  openGraph: {
    title: `Pricing · ${siteConfig.name}`,
    description: "Free, Pro, and Premium plans for the real-time AI interview coach.",
    url: `${siteConfig.url}/pricing`,
  },
};

export default function PricingPage() {
  return (
    <>
      <JsonLd
        data={[
          softwareApplicationSchema(),
          breadcrumbSchema([
            { name: "Home", href: "/" },
            { name: "Pricing", href: "/pricing" },
          ]),
        ]}
      />
      <div className="border-b border-[var(--color-border)] bg-[var(--color-bg-subtle)] pt-16 pb-12">
        <div className="mx-auto max-w-3xl px-6 text-center sm:px-8">
          <h1 className="text-balance text-5xl font-bold tracking-tight sm:text-6xl">
            Plans for every stage of your search.
          </h1>
          <p className="mt-5 text-lg text-[var(--color-fg-muted)]">
            Free is genuinely free. Pro pays for itself with one extra interview offer.
            Premium is for senior candidates who interview at 5+ companies in a quarter.
          </p>
        </div>
      </div>
      <Pricing standalone />
      <FAQ />
      <CTA />
    </>
  );
}
