import { Container } from "@/components/ui/container";
import { Badge } from "@/components/ui/badge";

const steps = [
  {
    n: "01",
    title: "Set up your profile",
    description:
      "Drop in your resume PDF and the job listing URL. We extract structured signals — tech stack, role level, domain — and store them locally on-device.",
  },
  {
    n: "02",
    title: "Start the session",
    description:
      "Tap start before your call. Interview Ace listens via your iPhone mic, transcribes the interviewer in real time, and ignores your own voice via VAD.",
  },
  {
    n: "03",
    title: "Read tailored answers",
    description:
      "Each question is classified, routed to the right model, and the answer streams in <600ms. Answers cite your real experience, not generic templates.",
  },
  {
    n: "04",
    title: "Review and improve",
    description:
      "Premium tier scores each exchange against a senior-engineer rubric, surfaces your weakest claim, and queues a targeted prep prompt for round two.",
  },
];

export function HowItWorks() {
  return (
    <section
      id="how-it-works"
      aria-labelledby="how-heading"
      className="relative py-24 sm:py-32 bg-[var(--color-bg-subtle)] border-y border-[var(--color-border)]"
    >
      <Container>
        <div className="mx-auto max-w-3xl text-center">
          <Badge variant="brand">How it works</Badge>
          <h2
            id="how-heading"
            className="mt-4 text-balance text-4xl font-bold tracking-tight sm:text-5xl"
          >
            Four steps. Roughly four minutes to set up.
          </h2>
          <p className="mt-5 text-lg text-[var(--color-fg-muted)]">
            From "I have an interview tomorrow" to "I'm in the room and reading
            answers off my phone" — most users get there in under five minutes.
          </p>
        </div>
        <ol className="mx-auto mt-16 grid max-w-5xl grid-cols-1 gap-6 md:grid-cols-2">
          {steps.map((step) => (
            <li
              key={step.n}
              className="relative flex gap-5 rounded-3xl border border-[var(--color-border)] bg-[var(--color-bg)] p-7"
            >
              <div className="font-display text-3xl font-bold tracking-tight text-[var(--color-brand-600)] dark:text-[var(--color-brand-300)]">
                {step.n}
              </div>
              <div>
                <h3 className="font-display text-xl font-semibold tracking-tight">
                  {step.title}
                </h3>
                <p className="mt-2 text-[15px] leading-relaxed text-[var(--color-fg-muted)]">
                  {step.description}
                </p>
              </div>
            </li>
          ))}
        </ol>
      </Container>
    </section>
  );
}
