import {
  AudioLines,
  Brain,
  ClipboardCheck,
  GraduationCap,
  Lock,
  ShieldCheck,
  Target,
  Workflow,
  Zap,
} from "lucide-react";
import { Container } from "@/components/ui/container";
import { Badge } from "@/components/ui/badge";

const features = [
  {
    icon: AudioLines,
    title: "Real-time transcription",
    description:
      "Deepgram Nova-3 transcribes the interviewer with 95%+ accuracy at 16 kHz. Predictive endpointing fires before they finish — you get a head start.",
  },
  {
    icon: Brain,
    title: "Question classification",
    description:
      "Every question is auto-classified — behavioral, system design, coding, product, or culture-fit — and routed to the right model and prompt strategy.",
  },
  {
    icon: Target,
    title: "Resume-aware answers",
    description:
      "Answers are generated against your structured resume, the job description's tech stack, and the company context. No generic STAR boilerplate.",
  },
  {
    icon: Zap,
    title: "Sub-600ms streaming",
    description:
      "Tokens stream as they're generated. You read ahead in your AirPods while the interviewer is still asking the next question.",
  },
  {
    icon: GraduationCap,
    title: "Practice mode",
    description:
      "Run full mock interviews with an AI interviewer that adapts to your answers, probes weak claims, and grades you on the same rubric used at FAANG.",
  },
  {
    icon: ClipboardCheck,
    title: "Post-interview analytics",
    description:
      "Premium tier replays each exchange with rubric-based scoring, weakest-answer breakdown, and follow-up question prep for the next round.",
  },
  {
    icon: Workflow,
    title: "Voice-prep mode",
    description:
      "OpenAI Realtime voice rehearsal — talk to the AI, get instant feedback on filler words, pacing, and structure. Premium-only.",
  },
  {
    icon: ShieldCheck,
    title: "Tier-gated quality",
    description:
      "Free runs on GPT-4.1 mini. Premium uses GPT-4.1 (reasoning) and o4-mini for coding questions, with longer prompts and richer context.",
  },
  {
    icon: Lock,
    title: "Privacy-first by design",
    description:
      "Audio is processed and discarded — never stored. Transcripts are encrypted at rest and you can wipe your session history with one tap.",
  },
];

export function Features() {
  return (
    <section
      id="features"
      aria-labelledby="features-heading"
      className="relative py-24 sm:py-32"
    >
      <Container>
        <div className="mx-auto max-w-3xl text-center">
          <Badge variant="brand">Features</Badge>
          <h2
            id="features-heading"
            className="mt-4 text-balance text-4xl font-bold tracking-tight sm:text-5xl"
          >
            Built like a senior interviewer is in your corner.
          </h2>
          <p className="mt-5 text-lg leading-relaxed text-[var(--color-fg-muted)]">
            Every component — transcription, classification, prompting, streaming — is tuned for the
            three things that actually win interviews: speed, structure, and specificity.
          </p>
        </div>
        <div className="mt-16 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((feature) => (
            <FeatureCard key={feature.title} {...feature} />
          ))}
        </div>
      </Container>
    </section>
  );
}

function FeatureCard({
  icon: Icon,
  title,
  description,
}: {
  icon: typeof AudioLines;
  title: string;
  description: string;
}) {
  return (
    <article className="group relative overflow-hidden rounded-3xl border border-[var(--color-border)] bg-[var(--color-bg-subtle)] p-7 transition-all duration-300 hover:border-[var(--color-border-strong)] hover:shadow-[var(--shadow-sharp)]">
      <div
        aria-hidden
        className="absolute inset-0 -z-10 bg-gradient-to-br from-[var(--color-brand-500)]/[0.03] to-transparent opacity-0 transition-opacity duration-500 group-hover:opacity-100"
      />
      <div className="inline-flex h-11 w-11 items-center justify-center rounded-xl border border-[var(--color-border)] bg-[var(--color-bg)] text-[var(--color-brand-600)] transition-transform duration-500 group-hover:-translate-y-0.5 dark:text-[var(--color-brand-300)]">
        <Icon className="h-5 w-5" />
      </div>
      <h3 className="mt-5 font-display text-lg font-semibold tracking-tight">{title}</h3>
      <p className="mt-2 text-sm leading-relaxed text-[var(--color-fg-muted)]">{description}</p>
    </article>
  );
}
