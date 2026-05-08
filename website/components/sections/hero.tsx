"use client";

import { motion } from "motion/react";
import { ArrowRight, Sparkles } from "lucide-react";
import { ButtonLink } from "@/components/ui/button";
import { Container } from "@/components/ui/container";
import { Badge } from "@/components/ui/badge";
import { siteConfig } from "@/lib/site";
import { LiveTranscriptDemo } from "@/components/sections/live-transcript-demo";

export function Hero() {
  return (
    <section
      aria-labelledby="hero-heading"
      className="relative overflow-hidden pt-12 pb-20 sm:pt-20 sm:pb-32 lg:pt-28"
    >
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 -z-10 grid-pattern opacity-40 dark:opacity-30"
      />
      <div
        aria-hidden
        className="pointer-events-none absolute -top-40 left-1/2 -z-10 h-[40rem] w-[60rem] -translate-x-1/2 rounded-full bg-gradient-to-br from-[var(--color-brand-300)]/30 via-[var(--color-accent-400)]/20 to-transparent blur-3xl dark:from-[var(--color-brand-700)]/40 dark:via-[var(--color-accent-600)]/20"
      />
      <Container>
        <div className="grid items-center gap-12 lg:grid-cols-[1.1fr_1fr] lg:gap-16">
          <div className="flex flex-col items-start">
            <motion.div
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
            >
              <Badge variant="brand" className="mb-6">
                <Sparkles className="h-3 w-3" aria-hidden />
                Powered by GPT-4.1 &amp; o4-mini · Deepgram Nova-3
              </Badge>
            </motion.div>
            <motion.h1
              id="hero-heading"
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1], delay: 0.05 }}
              className="text-balance text-5xl font-bold leading-[1.05] tracking-[-0.04em] sm:text-6xl lg:text-7xl"
            >
              Pass any interview.{" "}
              <span className="gradient-text">With elite AI in your ear.</span>
            </motion.h1>
            <motion.p
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1], delay: 0.12 }}
              className="mt-6 max-w-xl text-balance text-lg leading-relaxed text-[var(--color-fg-muted)] sm:text-xl"
            >
              {siteConfig.name} listens to your interview in real time, classifies every question,
              and generates a tailored answer&nbsp;— calibrated to your resume, the role, and the company&nbsp;—
              before the interviewer finishes speaking.
            </motion.p>
            <motion.div
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1], delay: 0.18 }}
              className="mt-10 flex flex-col items-stretch gap-3 sm:flex-row sm:items-center"
            >
              <ButtonLink href={siteConfig.appStore} variant="brand" size="xl">
                Download for iOS
                <ArrowRight className="h-4 w-4" />
              </ButtonLink>
              <ButtonLink href="/#how-it-works" variant="outline" size="xl">
                See how it works
              </ButtonLink>
            </motion.div>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.6, delay: 0.3 }}
              className="mt-10 grid grid-cols-3 gap-6 border-t border-[var(--color-border)] pt-8 text-sm sm:grid-cols-3"
            >
              <Stat value="< 600ms" label="Median answer latency" />
              <Stat value="4.8 / 5" label="App Store rating" />
              <Stat value="38%" label="Higher offer rate" />
            </motion.div>
          </div>
          <motion.div
            initial={{ opacity: 0, scale: 0.96, y: 16 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1], delay: 0.15 }}
          >
            <LiveTranscriptDemo />
          </motion.div>
        </div>
      </Container>
    </section>
  );
}

function Stat({ value, label }: { value: string; label: string }) {
  return (
    <div>
      <div className="font-display text-2xl font-bold tracking-tight text-[var(--color-fg)] sm:text-3xl">
        {value}
      </div>
      <div className="mt-1 text-xs text-[var(--color-fg-subtle)] sm:text-sm">{label}</div>
    </div>
  );
}
