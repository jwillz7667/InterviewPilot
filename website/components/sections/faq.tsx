"use client";

import { ChevronDown } from "lucide-react";
import { useState } from "react";
import { Container } from "@/components/ui/container";
import { Badge } from "@/components/ui/badge";
import { JsonLd } from "@/components/json-ld";
import { faqSchema } from "@/lib/structured-data";
import { cn } from "@/lib/utils";

const FAQS = [
  {
    question: "Is this cheating?",
    answer:
      "No more than using a search engine, an IDE with autocomplete, or a STAR-method cheat sheet on Notion. Real interviews increasingly happen via video call, and using AI to structure your thinking under pressure is a skill — one that maps directly to how senior engineers actually work. We have a long-form post on this if you want the full argument.",
  },
  {
    question: "Will the interviewer know I'm using it?",
    answer:
      "The audio is one-way: Interview Ace listens to the interviewer through your phone's mic and shows answers on your screen. It does not transmit any audio out. There's no browser extension, no overlay on Zoom — it's a phone-side reading aid.",
  },
  {
    question: "How fast does it actually respond?",
    answer:
      "Median answer latency is under 600ms from the interviewer finishing the question. We use predictive endpointing to start generating before they finish speaking — for most questions, the answer is already streaming in by the time the question lands.",
  },
  {
    question: "What models do you use?",
    answer:
      "Standard tier uses GPT-4.1 mini for general questions. Premium tier upgrades to GPT-4.1 for behavioral and design questions, and to o4-mini for coding questions where reasoning depth matters. Transcription is Deepgram Nova-3 across all tiers.",
  },
  {
    question: "Does it work for non-software roles?",
    answer:
      "Yes. The product was built around senior engineering interviews but the same prompt engineering scales to product management, data science, design, and finance roles. We auto-detect the domain from your resume and JD and route to the appropriate prompt strategy.",
  },
  {
    question: "Is my data private?",
    answer:
      "Audio is processed in-memory and discarded — never written to disk, never stored. Transcripts are encrypted at rest and you can wipe your full session history with one tap. We do not train any models on your interview data. Full disclosures on the Privacy page.",
  },
  {
    question: "Can I cancel anytime?",
    answer:
      "Yes. Subscriptions are managed through your Apple ID — cancel from Settings &rarr; Apple ID &rarr; Subscriptions at any time. No retention dark patterns. You keep access until the end of the current billing period.",
  },
  {
    question: "What if I have an interview today and need it now?",
    answer:
      "Free tier gives you 3 standard + 1 premium interview every 30 days, no card required. Most users get through their first interview on the free plan and only upgrade once they're in their second loop.",
  },
];

export function FAQ() {
  return (
    <section
      id="faq"
      aria-labelledby="faq-heading"
      className="relative py-24 sm:py-32 bg-[var(--color-bg-subtle)] border-y border-[var(--color-border)]"
    >
      <JsonLd data={faqSchema(FAQS)} />
      <Container>
        <div className="mx-auto max-w-3xl text-center">
          <Badge variant="brand">FAQ</Badge>
          <h2
            id="faq-heading"
            className="mt-4 text-balance text-4xl font-bold tracking-tight sm:text-5xl"
          >
            The common questions, answered honestly.
          </h2>
        </div>
        <div className="mx-auto mt-12 max-w-3xl divide-y divide-[var(--color-border)] rounded-3xl border border-[var(--color-border)] bg-[var(--color-bg)]">
          {FAQS.map((faq, idx) => (
            <FAQItem key={faq.question} faq={faq} defaultOpen={idx === 0} />
          ))}
        </div>
      </Container>
    </section>
  );
}

function FAQItem({
  faq,
  defaultOpen,
}: {
  faq: { question: string; answer: string };
  defaultOpen: boolean;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <details
      open={open}
      onToggle={(e) => setOpen((e.target as HTMLDetailsElement).open)}
      className="group"
    >
      <summary className="flex cursor-pointer list-none items-center justify-between gap-6 px-6 py-5 text-left">
        <h3 className="font-display text-lg font-semibold tracking-tight text-[var(--color-fg)]">
          {faq.question}
        </h3>
        <ChevronDown
          className={cn(
            "h-5 w-5 shrink-0 text-[var(--color-fg-muted)] transition-transform duration-300",
            open && "rotate-180",
          )}
        />
      </summary>
      <div className="px-6 pb-6 -mt-1 text-[15px] leading-relaxed text-[var(--color-fg-muted)] text-pretty">
        {faq.answer}
      </div>
    </details>
  );
}
