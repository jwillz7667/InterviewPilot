"use client";

import { motion, AnimatePresence } from "motion/react";
import { useEffect, useState } from "react";
import { Mic, Sparkles } from "lucide-react";

type Stage = {
  question: string;
  classification: string;
  answer: string[];
};

const STAGES: Stage[] = [
  {
    question: "Walk me through how you'd design a real-time leaderboard for 50M users.",
    classification: "System Design · Distributed Systems",
    answer: [
      "Start with constraints — write QPS, read QPS, latency budget, eventual vs. strong consistency.",
      "Use a sorted set in Redis Cluster keyed by leaderboard ID; shard by user ID hash.",
      "Async fan-out via Kafka to a write-through cache; reads go to a regional read replica.",
      "Top-100 served from an in-memory snapshot rebuilt every 200ms; tail queries hit the sorted set.",
    ],
  },
  {
    question: "Tell me about a time you disagreed with a senior engineer.",
    classification: "Behavioral · Conflict Resolution",
    answer: [
      "Situation: Q3 2024, our staff engineer pushed for a Kafka rewrite for a low-traffic ingestion path.",
      "Task: I was tech lead and had to decide before the freeze.",
      "Action: I built a 2-day spike comparing Kafka vs. existing SQS; benchmarked p99 latency at our actual load.",
      "Result: SQS won by 40% on cost; we shipped the smaller change. Staff eng later cited it as a good call.",
    ],
  },
  {
    question: "Reverse a linked list — recursive and iterative. Trade-offs?",
    classification: "Coding · Linked List",
    answer: [
      "Iterative: O(n) time, O(1) space — three pointers (prev, curr, next).",
      "Recursive: O(n) time, O(n) stack — cleaner but blows the stack at ~10k nodes on most JVMs.",
      "Production answer: iterative every time. Recursion is for whiteboard charm, not real systems.",
    ],
  },
];

export function LiveTranscriptDemo() {
  const [stageIdx, setStageIdx] = useState(0);
  const [revealedLines, setRevealedLines] = useState(0);
  const [pulse, setPulse] = useState(0);

  const stage = STAGES[stageIdx]!;

  useEffect(() => {
    setRevealedLines(0);
    const interval = setInterval(() => {
      setRevealedLines((n) => {
        if (n >= stage.answer.length) {
          clearInterval(interval);
          return n;
        }
        return n + 1;
      });
    }, 700);
    return () => clearInterval(interval);
  }, [stageIdx, stage.answer.length]);

  useEffect(() => {
    if (revealedLines >= stage.answer.length) {
      const t = setTimeout(() => setStageIdx((i) => (i + 1) % STAGES.length), 4500);
      return () => clearTimeout(t);
    }
  }, [revealedLines, stage.answer.length]);

  useEffect(() => {
    const t = setInterval(() => setPulse((p) => p + 1), 1200);
    return () => clearInterval(t);
  }, []);

  return (
    <div className="relative">
      <div className="absolute -inset-1 rounded-[2rem] bg-gradient-to-br from-[var(--color-brand-500)]/20 via-[var(--color-accent-500)]/10 to-transparent blur-2xl" />
      <div className="relative overflow-hidden rounded-[2rem] border border-[var(--color-border)] bg-[var(--color-bg-subtle)] shadow-[var(--shadow-floating)]">
        <div className="flex items-center justify-between border-b border-[var(--color-border)] px-5 py-3">
          <div className="flex items-center gap-2">
            <span className="relative inline-flex">
              <span className="h-2.5 w-2.5 rounded-full bg-[oklch(60%_0.22_25)]" />
              <span
                key={pulse}
                className="absolute inset-0 h-2.5 w-2.5 animate-ping rounded-full bg-[oklch(60%_0.22_25)] opacity-75"
              />
            </span>
            <span className="text-xs font-medium text-[var(--color-fg-muted)]">
              Live · {STAGES[stageIdx]!.classification}
            </span>
          </div>
          <div className="flex items-center gap-1.5 text-xs text-[var(--color-fg-subtle)]">
            <Mic className="h-3.5 w-3.5" />
            <span>16 kHz · Nova-3</span>
          </div>
        </div>
        <div className="space-y-5 p-5 sm:p-6">
          <AnimatePresence mode="wait">
            <motion.div
              key={`q-${stageIdx}`}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              transition={{ duration: 0.4 }}
            >
              <div className="text-xs font-medium uppercase tracking-wider text-[var(--color-fg-subtle)]">
                Interviewer
              </div>
              <p className="mt-1 text-base font-medium text-[var(--color-fg)]">
                "{stage.question}"
              </p>
            </motion.div>
          </AnimatePresence>

          <div className="rounded-2xl border border-[var(--color-brand-200)] bg-gradient-to-br from-[var(--color-brand-50)] to-transparent p-4 dark:border-[var(--color-brand-800)] dark:from-[var(--color-brand-900)]/30">
            <div className="mb-3 flex items-center gap-2">
              <Sparkles className="h-3.5 w-3.5 text-[var(--color-brand-600)] dark:text-[var(--color-brand-300)]" />
              <span className="text-xs font-semibold uppercase tracking-wider text-[var(--color-brand-700)] dark:text-[var(--color-brand-200)]">
                Suggested answer · streaming
              </span>
            </div>
            <ul className="space-y-2.5 text-sm text-[var(--color-fg)]">
              {stage.answer.map((line, idx) => (
                <AnimatePresence key={`${stageIdx}-${idx}`} mode="wait">
                  {idx < revealedLines && (
                    <motion.li
                      initial={{ opacity: 0, y: 6 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ duration: 0.35, delay: 0.05 }}
                      className="flex gap-2"
                    >
                      <span className="mt-1.5 inline-block h-1 w-1 shrink-0 rounded-full bg-[var(--color-brand-500)]" />
                      <span className="leading-relaxed text-pretty">{line}</span>
                    </motion.li>
                  )}
                </AnimatePresence>
              ))}
            </ul>
          </div>

          <div className="flex items-center justify-between text-xs text-[var(--color-fg-subtle)]">
            <span>Resume + JD context · 4 prior exchanges</span>
            <span className="font-mono">{revealedLines * 142}ms</span>
          </div>
        </div>
      </div>
    </div>
  );
}
