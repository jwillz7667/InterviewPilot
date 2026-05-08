"use client";

import { Check, X, Zap } from "lucide-react";
import { useState } from "react";
import { Container } from "@/components/ui/container";
import { Badge } from "@/components/ui/badge";
import { ButtonLink } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { siteConfig } from "@/lib/site";

type Cycle = "monthly" | "yearly";

type Tier = {
  id: "free" | "pro" | "premium";
  name: string;
  description: string;
  monthly: { price: string; cents?: string; period: string };
  yearly: { price: string; cents?: string; period: string; saveLabel?: string };
  cta: string;
  href: string;
  highlight?: boolean;
  features: { label: string; included: boolean }[];
};

const TIERS: Tier[] = [
  {
    id: "free",
    name: "Free",
    description: "Try the engine. No card required.",
    monthly: { price: "$0", period: "forever" },
    yearly: { price: "$0", period: "forever" },
    cta: "Download free",
    href: siteConfig.appStore,
    features: [
      { included: true, label: "3 standard interviews / 30 days" },
      { included: true, label: "1 premium interview / 30 days" },
      { included: true, label: "Live transcription + Q classification" },
      { included: true, label: "Resume + JD context" },
      { included: false, label: "Post-interview rubric scoring" },
      { included: false, label: "Voice-prep practice mode" },
      { included: false, label: "GPT-4.1 + o4-mini quality" },
      { included: false, label: "Multi-profile support" },
    ],
  },
  {
    id: "pro",
    name: "Pro",
    description: "Active job seekers. The 80% case.",
    monthly: { price: "$19", cents: ".99", period: "month" },
    yearly: { price: "$14", cents: ".99", period: "month", saveLabel: "Save 25%" },
    cta: "Start with Pro",
    href: siteConfig.appStore,
    highlight: true,
    features: [
      { included: true, label: "25 standard interviews / 30 days" },
      { included: true, label: "10 premium interviews / 30 days" },
      { included: true, label: "Live transcription + Q classification" },
      { included: true, label: "Resume + JD context (3 profiles)" },
      { included: true, label: "Post-interview rubric scoring" },
      { included: false, label: "Voice-prep practice mode" },
      { included: true, label: "GPT-4.1 mini quality" },
      { included: false, label: "Unlimited interviews" },
    ],
  },
  {
    id: "premium",
    name: "Premium",
    description: "Senior IC, EM, and Staff candidates.",
    monthly: { price: "$49", cents: ".99", period: "month" },
    yearly: { price: "$37", cents: ".99", period: "month", saveLabel: "Save 25%" },
    cta: "Go Premium",
    href: siteConfig.appStore,
    features: [
      { included: true, label: "Unlimited standard + premium" },
      { included: true, label: "Live transcription + Q classification" },
      { included: true, label: "Resume + JD context (5 profiles)" },
      { included: true, label: "Post-interview rubric scoring" },
      { included: true, label: "Voice-prep practice mode" },
      { included: true, label: "GPT-4.1 (premium reasoning)" },
      { included: true, label: "o4-mini for coding questions" },
      { included: true, label: "Priority support" },
    ],
  },
];

export function Pricing({ standalone = false }: { standalone?: boolean }) {
  const [cycle, setCycle] = useState<Cycle>("yearly");

  return (
    <section
      id="pricing"
      aria-labelledby="pricing-heading"
      className={cn("relative py-24 sm:py-32", standalone && "pt-12")}
    >
      <Container>
        <div className="mx-auto max-w-3xl text-center">
          <Badge variant="brand">Pricing</Badge>
          <h2
            id="pricing-heading"
            className="mt-4 text-balance text-4xl font-bold tracking-tight sm:text-5xl"
          >
            One offer pays for it for life.
          </h2>
          <p className="mt-5 text-lg text-[var(--color-fg-muted)]">
            Free is genuinely free, forever. Premium is one yes-decision in your search away from
            paying for itself many times over.
          </p>

          <div
            role="radiogroup"
            aria-label="Billing cycle"
            className="mt-8 inline-flex items-center gap-1 rounded-full border border-[var(--color-border)] bg-[var(--color-bg-subtle)] p-1 text-sm"
          >
            <button
              type="button"
              role="radio"
              aria-checked={cycle === "monthly"}
              onClick={() => setCycle("monthly")}
              className={cn(
                "rounded-full px-4 py-1.5 font-medium transition-colors",
                cycle === "monthly"
                  ? "bg-[var(--color-bg)] text-[var(--color-fg)] shadow-sm"
                  : "text-[var(--color-fg-muted)] hover:text-[var(--color-fg)]",
              )}
            >
              Monthly
            </button>
            <button
              type="button"
              role="radio"
              aria-checked={cycle === "yearly"}
              onClick={() => setCycle("yearly")}
              className={cn(
                "inline-flex items-center gap-2 rounded-full px-4 py-1.5 font-medium transition-colors",
                cycle === "yearly"
                  ? "bg-[var(--color-bg)] text-[var(--color-fg)] shadow-sm"
                  : "text-[var(--color-fg-muted)] hover:text-[var(--color-fg)]",
              )}
            >
              Yearly
              <span className="rounded-full bg-[var(--color-brand-100)] px-1.5 py-0.5 text-[10px] font-semibold text-[var(--color-brand-700)] dark:bg-[var(--color-brand-900)] dark:text-[var(--color-brand-200)]">
                −25%
              </span>
            </button>
          </div>
        </div>

        <div className="mx-auto mt-14 grid max-w-6xl grid-cols-1 gap-6 lg:grid-cols-3">
          {TIERS.map((tier) => (
            <PricingCard key={tier.id} tier={tier} cycle={cycle} />
          ))}
        </div>

        <p className="mt-10 text-center text-xs text-[var(--color-fg-subtle)]">
          Prices in USD. Subscriptions auto-renew unless canceled at least 24 hours before the period
          ends. Manage in App Store settings. See <a href="/terms" className="underline hover:text-[var(--color-fg)]">Terms</a>.
        </p>
      </Container>
    </section>
  );
}

function PricingCard({ tier, cycle }: { tier: Tier; cycle: Cycle }) {
  const billing = tier[cycle];
  return (
    <article
      className={cn(
        "relative flex flex-col rounded-3xl border p-8 transition-all",
        tier.highlight
          ? "border-[var(--color-brand-500)] bg-gradient-to-br from-[var(--color-brand-50)] via-[var(--color-bg)] to-[var(--color-bg)] shadow-[var(--shadow-floating)] dark:from-[var(--color-brand-900)]/40"
          : "border-[var(--color-border)] bg-[var(--color-bg-subtle)]",
      )}
    >
      {tier.highlight && (
        <span className="absolute -top-3 left-8 inline-flex items-center gap-1 rounded-full bg-[var(--color-brand-600)] px-3 py-1 text-[11px] font-semibold uppercase tracking-wider text-white">
          <Zap className="h-3 w-3" />
          Most popular
        </span>
      )}
      <h3 className="font-display text-2xl font-bold tracking-tight">{tier.name}</h3>
      <p className="mt-1 text-sm text-[var(--color-fg-muted)]">{tier.description}</p>

      <div className="mt-6 flex items-baseline gap-1">
        <span className="font-display text-5xl font-bold tracking-tight">{billing.price}</span>
        {billing.cents && (
          <span className="font-display text-2xl font-semibold text-[var(--color-fg-muted)]">
            {billing.cents}
          </span>
        )}
        <span className="ml-1.5 text-sm text-[var(--color-fg-muted)]">/ {billing.period}</span>
      </div>
      {cycle === "yearly" && "saveLabel" in billing && billing.saveLabel && (
        <p className="mt-1 text-xs font-medium text-[var(--color-success)]">
          {billing.saveLabel} · billed yearly
        </p>
      )}

      <ButtonLink
        href={tier.href}
        variant={tier.highlight ? "brand" : "outline"}
        size="lg"
        className="mt-6 w-full"
      >
        {tier.cta}
      </ButtonLink>

      <ul className="mt-8 space-y-3 border-t border-[var(--color-border)] pt-8 text-sm">
        {tier.features.map((f) => (
          <li
            key={f.label}
            className={cn(
              "flex items-start gap-2.5",
              !f.included && "text-[var(--color-fg-subtle)]",
            )}
          >
            {f.included ? (
              <Check className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-success)]" aria-hidden />
            ) : (
              <X className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-fg-subtle)]" aria-hidden />
            )}
            <span className={cn(f.included && "text-[var(--color-fg)]")}>{f.label}</span>
          </li>
        ))}
      </ul>
    </article>
  );
}
