import { Star } from "lucide-react";
import { Container } from "@/components/ui/container";
import { Badge } from "@/components/ui/badge";

const testimonials = [
  {
    quote:
      "I had three days to prep for a Stripe staff loop. Interview Ace got me to think in trade-offs the way the bar raisers do — and I had the answer ready before the question fully landed.",
    name: "Priya R.",
    role: "Staff Engineer @ Stripe",
  },
  {
    quote:
      "The post-interview rubric is the killer feature. It told me my STAR answers were strong on Action and weak on Result — fixed it for round two and got the offer.",
    name: "Marcus T.",
    role: "Senior PM @ Datadog",
  },
  {
    quote:
      "I'm a hiring manager. I built a fake set of system design questions for our loop and ran them through this. The answers were better than 80% of what I see in real loops. Genuinely impressive.",
    name: "Jenna L.",
    role: "EM @ Notion",
  },
  {
    quote:
      "The voice-prep mode caught my filler words and pacing issues before my actual interview. That alone is worth the Premium tier.",
    name: "David K.",
    role: "Senior SWE @ Vercel",
  },
  {
    quote:
      "I'd been bombing onsites for two months. Three weeks with this app and I had four offers. The o4-mini coding answers are genuinely better than what I'd write under pressure.",
    name: "Aisha N.",
    role: "Staff Engineer @ Airbnb",
  },
  {
    quote:
      "What sold me: the answers cite my actual resume, not generic templates. Interviewers asked follow-ups and the suggestions held up.",
    name: "Tom B.",
    role: "Tech Lead @ Linear",
  },
];

export function Testimonials() {
  return (
    <section
      aria-labelledby="testimonials-heading"
      className="relative py-24 sm:py-32"
    >
      <Container>
        <div className="mx-auto max-w-3xl text-center">
          <Badge variant="brand">Testimonials</Badge>
          <h2
            id="testimonials-heading"
            className="mt-4 text-balance text-4xl font-bold tracking-tight sm:text-5xl"
          >
            Senior engineers and PMs landing offers in days, not months.
          </h2>
        </div>
        <div className="mt-16 columns-1 gap-6 sm:columns-2 lg:columns-3">
          {testimonials.map((t) => (
            <figure
              key={t.name}
              className="mb-6 break-inside-avoid rounded-3xl border border-[var(--color-border)] bg-[var(--color-bg-subtle)] p-7"
            >
              <div className="flex items-center gap-0.5 text-[var(--color-warning)]">
                {Array.from({ length: 5 }).map((_, i) => (
                  <Star key={i} className="h-4 w-4 fill-current" />
                ))}
              </div>
              <blockquote className="mt-4 text-pretty text-[15px] leading-relaxed text-[var(--color-fg)]">
                "{t.quote}"
              </blockquote>
              <figcaption className="mt-5 text-sm">
                <div className="font-semibold text-[var(--color-fg)]">{t.name}</div>
                <div className="text-[var(--color-fg-subtle)]">{t.role}</div>
              </figcaption>
            </figure>
          ))}
        </div>
      </Container>
    </section>
  );
}
