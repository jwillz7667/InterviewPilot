import { ArrowRight } from "lucide-react";
import { Container } from "@/components/ui/container";
import { ButtonLink } from "@/components/ui/button";
import { siteConfig } from "@/lib/site";

export function CTA() {
  return (
    <section className="relative py-24 sm:py-32">
      <Container>
        <div className="relative overflow-hidden rounded-[2rem] bg-gradient-to-br from-[var(--color-brand-700)] via-[var(--color-brand-600)] to-[var(--color-brand-500)] p-12 text-center shadow-[var(--shadow-floating)] sm:p-16 lg:p-20">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 opacity-30 mix-blend-overlay"
            style={{
              backgroundImage:
                "radial-gradient(circle at 30% 20%, white, transparent 40%), radial-gradient(circle at 70% 80%, white, transparent 35%)",
            }}
          />
          <div className="relative">
            <h2 className="text-balance text-4xl font-bold tracking-tight text-white sm:text-5xl lg:text-6xl">
              Your next offer is{" "}
              <span className="underline decoration-white/40 decoration-4 underline-offset-8">
                one interview
              </span>{" "}
              away.
            </h2>
            <p className="mx-auto mt-6 max-w-2xl text-balance text-lg leading-relaxed text-white/85 sm:text-xl">
              Free for the first interview. No card. No commitment. Just see if it works for you.
            </p>
            <div className="mt-10 flex flex-col items-stretch justify-center gap-3 sm:flex-row">
              <ButtonLink
                href={siteConfig.appStore}
                variant="primary"
                size="xl"
                className="bg-white text-[var(--color-brand-700)] hover:bg-white/95"
              >
                Download for iOS
                <ArrowRight className="h-4 w-4" />
              </ButtonLink>
              <ButtonLink
                href="/blog"
                variant="ghost"
                size="xl"
                className="text-white hover:bg-white/10"
              >
                Read the prep guides
              </ButtonLink>
            </div>
            <p className="mt-8 text-sm text-white/60">
              4.8 / 5 on the App Store · 1,200+ ratings · Featured in App Store "Productivity"
            </p>
          </div>
        </div>
      </Container>
    </section>
  );
}
