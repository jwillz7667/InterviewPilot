import { Container } from "@/components/ui/container";

const LOGOS = [
  "Stripe",
  "Datadog",
  "Vercel",
  "Linear",
  "Figma",
  "Notion",
  "Anthropic",
  "Airbnb",
];

export function SocialProof() {
  return (
    <section className="border-y border-[var(--color-border)] bg-[var(--color-bg-subtle)] py-12">
      <Container>
        <p className="mb-8 text-center text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-fg-subtle)]">
          Used by candidates landing offers at
        </p>
        <div
          className="grid grid-cols-2 items-center gap-x-8 gap-y-6 sm:grid-cols-4 lg:grid-cols-8"
          aria-label="Companies where Interview Ace users have received offers"
        >
          {LOGOS.map((name) => (
            <div
              key={name}
              className="flex items-center justify-center text-base font-semibold tracking-tight text-[var(--color-fg-subtle)] grayscale opacity-70 transition-opacity hover:opacity-100"
            >
              {name}
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}
