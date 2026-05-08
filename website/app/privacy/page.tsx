import type { Metadata } from "next";
import { Container } from "@/components/ui/container";
import { siteConfig } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "How Interview Ace collects, uses, and protects your data. GDPR, CCPA, and COPPA disclosures, with explicit lists of personal information categories, retention windows, and your rights.",
  alternates: { canonical: "/privacy" },
  robots: { index: true, follow: true },
};

const LAST_UPDATED = "May 7, 2026";
const EFFECTIVE_DATE = "May 7, 2026";

export default function PrivacyPage() {
  return (
    <article className="bg-[var(--color-bg)]">
      <header className="border-b border-[var(--color-border)] bg-[var(--color-bg-subtle)] py-16">
        <Container>
          <p className="text-sm font-semibold uppercase tracking-wider text-[var(--color-fg-subtle)]">
            Legal
          </p>
          <h1 className="mt-3 text-balance font-display text-5xl font-bold tracking-tight">
            Privacy Policy
          </h1>
          <p className="mt-4 text-[var(--color-fg-muted)]">
            Effective date: {EFFECTIVE_DATE} · Last updated: {LAST_UPDATED}
          </p>
        </Container>
      </header>
      <Container className="py-16">
        <div className="prose mx-auto max-w-3xl text-[17px] leading-[1.75] text-[var(--color-fg)]">
          <p className="text-pretty">
            This Privacy Policy describes how {siteConfig.legalEntity}{" "}
            ("Interview Ace", "we", "us", or "our") collects, uses, discloses, and
            safeguards information when you use our iOS application, our website at{" "}
            <a href={siteConfig.url} className="text-[var(--color-brand-600)] underline">
              {siteConfig.domain}
            </a>
            , and any related services (collectively, the "Services"). This Policy is
            written to comply with the EU General Data Protection Regulation (GDPR),
            the UK GDPR, the California Consumer Privacy Act as amended by the
            California Privacy Rights Act (CCPA/CPRA), the Children's Online Privacy
            Protection Act (COPPA), and Apple's App Store privacy disclosure
            requirements.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">1. Summary at a glance</h2>
          <p className="mt-4 text-pretty">
            We process the minimum information required to deliver the Services. We do
            not sell your personal information. We do not train AI models on your
            interview transcripts. Audio captured during interview sessions is
            processed in memory and discarded — never written to durable storage.
            You can delete all of your data through the in-app Account &rarr; Delete
            account flow at any time, with deletion completed within 30 days.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">2. Data controller</h2>
          <p className="mt-4 text-pretty">
            The data controller for the personal information processed under this
            Policy is {siteConfig.legalEntity}, {siteConfig.legalAddress}. You can
            reach our privacy team at{" "}
            <a href={`mailto:privacy@${siteConfig.domain}`} className="text-[var(--color-brand-600)] underline">
              privacy@{siteConfig.domain}
            </a>
            . If you are in the European Economic Area (EEA) or the United Kingdom,
            you may also contact our EU/UK representative at{" "}
            <a href={`mailto:eu-rep@${siteConfig.domain}`} className="text-[var(--color-brand-600)] underline">
              eu-rep@{siteConfig.domain}
            </a>
            .
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">3. Information we collect</h2>
          <h3 className="mt-6 font-display text-xl font-semibold tracking-tight">3.1 Information you provide</h3>
          <ul className="mt-4 ml-6 list-disc space-y-2">
            <li>
              <strong>Account information.</strong> Email address, display name, and
              hashed password (Argon2id).
            </li>
            <li>
              <strong>Profile information.</strong> Resume content (uploaded as PDF or
              entered as text), LinkedIn URL, target job title, target company name,
              and structured profile attributes you choose to provide.
            </li>
            <li>
              <strong>Interview context.</strong> Job description text, job listing URL,
              interview type selection, and any notes you add to a session.
            </li>
            <li>
              <strong>Subscription information.</strong> Apple App Store transaction
              identifiers and subscription status (we do not receive your credit card
              number — Apple handles all payment processing).
            </li>
            <li>
              <strong>Support correspondence.</strong> Email content when you contact
              support, including any attachments you send.
            </li>
          </ul>

          <h3 className="mt-6 font-display text-xl font-semibold tracking-tight">3.2 Information collected during interview sessions</h3>
          <ul className="mt-4 ml-6 list-disc space-y-2">
            <li>
              <strong>Audio (transient).</strong> When you start an interview session,
              the application captures audio from your device microphone, streams it to
              our transcription provider (Deepgram), and retains it only in memory
              long enough to transcribe. Audio is not written to disk and is discarded
              the moment the transcription stream completes.
            </li>
            <li>
              <strong>Transcripts.</strong> The text transcription produced from the
              audio is stored locally on your device and, if you have enabled cloud
              backup, encrypted-at-rest in our database. Transcripts are linked to your
              account but never to advertising identifiers.
            </li>
            <li>
              <strong>AI exchange logs.</strong> The interview question (transcribed
              text), the AI response, and the model used for billing and quota
              accounting. These logs are encrypted at rest and accessible only to you.
            </li>
          </ul>

          <h3 className="mt-6 font-display text-xl font-semibold tracking-tight">3.3 Information collected automatically</h3>
          <ul className="mt-4 ml-6 list-disc space-y-2">
            <li>
              <strong>Device and usage data.</strong> Device model, iOS version,
              application version, language, time zone, and crash logs (via Apple's
              crash reporting). We do not use third-party analytics SDKs that
              fingerprint your device.
            </li>
            <li>
              <strong>Network data.</strong> IP address (truncated to /24 for IPv4 and
              /48 for IPv6 within seven days of collection), and the timestamp of API
              requests, used for rate-limiting and abuse prevention.
            </li>
            <li>
              <strong>Cookies (website only).</strong> Our website uses one
              first-party cookie to store your dark-mode preference. We do not set
              advertising cookies or third-party analytics cookies. We do not use
              Google Analytics.
            </li>
          </ul>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">4. How we use your information</h2>
          <p className="mt-4 text-pretty">
            We use the categories of personal information listed above for the
            following purposes:
          </p>
          <ul className="mt-4 ml-6 list-disc space-y-2">
            <li>
              <strong>To deliver the Services</strong> — including transcription,
              question classification, AI response generation, and post-session
              analytics.
            </li>
            <li>
              <strong>To personalize the AI's responses</strong> — your resume and job
              description are passed to the language model as context for each
              interview question.
            </li>
            <li>
              <strong>To enforce subscription limits</strong> — counting your monthly
              interview usage against the quota of your subscription tier.
            </li>
            <li>
              <strong>To prevent abuse and protect the Services</strong> — rate
              limiting, anomaly detection, and account lockout for suspicious activity.
            </li>
            <li>
              <strong>To communicate with you</strong> — for support, security
              notifications, and (if you opt in) product updates.
            </li>
            <li>
              <strong>To comply with legal obligations</strong> — including responding
              to lawful subpoenas and complying with tax reporting requirements.
            </li>
          </ul>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">5. Legal bases (GDPR / UK GDPR)</h2>
          <p className="mt-4 text-pretty">
            For users in the EEA or the UK, our legal bases for processing your
            personal information are:
          </p>
          <ul className="mt-4 ml-6 list-disc space-y-2">
            <li><strong>Performance of a contract</strong> (Article 6(1)(b)) — processing necessary to deliver the Services you have signed up for.</li>
            <li><strong>Legitimate interests</strong> (Article 6(1)(f)) — for security, abuse prevention, and product improvement that does not override your fundamental rights.</li>
            <li><strong>Consent</strong> (Article 6(1)(a)) — for optional marketing communications and any non-essential cookies.</li>
            <li><strong>Legal obligation</strong> (Article 6(1)(c)) — for tax, accounting, and lawful information requests.</li>
          </ul>
          <p className="mt-4 text-pretty">
            Where we rely on legitimate interests, you may object to the processing.
            See <a href="#section-rights" className="text-[var(--color-brand-600)] underline">Section 9</a> for how.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">6. AI processing and training</h2>
          <p className="mt-4 text-pretty">
            <strong>We do not use your data to train AI models.</strong> Interview
            content is sent to OpenAI (for response generation) and Deepgram (for
            transcription) under data processing agreements that prohibit the use of
            your data for model training. We have configured both vendors with the
            most restrictive data-retention setting available for their enterprise
            APIs:
          </p>
          <ul className="mt-4 ml-6 list-disc space-y-2">
            <li>
              <strong>OpenAI.</strong> Zero-day data retention is enabled. Inputs and
              outputs are not retained by OpenAI beyond the duration of the API call.
            </li>
            <li>
              <strong>Deepgram.</strong> Audio and transcripts are processed in
              real-time and are not retained beyond the streaming session.
            </li>
          </ul>
          <p className="mt-4 text-pretty">
            We do not provide your interview transcripts or AI exchange logs to any
            other third party. We do not aggregate them. We do not anonymize and
            re-share them.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">7. Data sharing and disclosure</h2>
          <p className="mt-4 text-pretty">
            We share personal information only with the following categories of
            recipients, and only to the extent necessary:
          </p>
          <ul className="mt-4 ml-6 list-disc space-y-2">
            <li><strong>Hosting and infrastructure providers</strong> — Amazon Web Services (Ireland and US East-1) and Railway for backend services.</li>
            <li><strong>AI subprocessors</strong> — OpenAI for response generation, Deepgram for transcription, both under DPAs prohibiting training use.</li>
            <li><strong>Payment processing</strong> — Apple, Inc. for App Store purchases.</li>
            <li><strong>Authentication</strong> — Apple's Sign in with Apple service if you choose this sign-in method.</li>
            <li><strong>Email delivery</strong> — Resend for transactional emails (account verification, password reset, support correspondence).</li>
            <li><strong>Customer support tooling</strong> — Plain.com for handling support tickets.</li>
            <li><strong>Legal and compliance recipients</strong> — when legally required, including in response to a subpoena, court order, or other lawful process. We will challenge any request that we believe is overbroad and notify you unless legally prohibited.</li>
            <li><strong>Successor in a corporate transaction</strong> — in the event of a merger, acquisition, or asset sale, your information may be transferred. We will provide notice and the opportunity to delete your account before any transfer becomes effective.</li>
          </ul>
          <p className="mt-4 text-pretty">
            <strong>We do not sell your personal information</strong> as that term is
            defined under the CCPA, the CPRA, or any other applicable privacy law. We
            do not share your personal information for cross-context behavioral
            advertising.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">8. International data transfers</h2>
          <p className="mt-4 text-pretty">
            We process personal information in the United States and the European
            Economic Area. When personal information is transferred from the EEA, the
            UK, or Switzerland to a country that has not received an adequacy
            decision, we rely on the European Commission's Standard Contractual
            Clauses (SCCs) or, where applicable, the EU-U.S. Data Privacy Framework
            (DPF) certification of our subprocessors. You can request a copy of the
            relevant SCCs by emailing{" "}
            <a href={`mailto:privacy@${siteConfig.domain}`} className="text-[var(--color-brand-600)] underline">
              privacy@{siteConfig.domain}
            </a>
            .
          </p>

          <h2 id="section-rights" className="mt-12 font-display text-2xl font-bold tracking-tight">9. Your rights</h2>
          <p className="mt-4 text-pretty">Depending on your jurisdiction, you have the following rights:</p>
          <ul className="mt-4 ml-6 list-disc space-y-2">
            <li><strong>Right to access</strong> — request a copy of the personal information we hold about you.</li>
            <li><strong>Right to rectification</strong> — correct inaccurate or incomplete information.</li>
            <li><strong>Right to erasure / "right to be forgotten"</strong> — request deletion of your account and associated personal information.</li>
            <li><strong>Right to restrict processing</strong> — limit how we use your information in specific circumstances.</li>
            <li><strong>Right to data portability</strong> — receive a machine-readable export of your information (we provide this in JSON format).</li>
            <li><strong>Right to object</strong> — object to processing based on legitimate interests, including for direct marketing.</li>
            <li><strong>Right to withdraw consent</strong> — where processing is based on consent, withdraw it at any time.</li>
            <li><strong>Right to non-discrimination</strong> (CCPA) — we will not deny service, charge different prices, or provide a different level of service because you exercised a privacy right.</li>
            <li><strong>Right to opt out of "sale" or "sharing"</strong> (CCPA) — although we do not sell or share your personal information, you may submit a request to confirm this.</li>
            <li><strong>Right to lodge a complaint</strong> — with your local supervisory authority (in the EU, the UK ICO, or your state attorney general).</li>
          </ul>
          <p className="mt-4 text-pretty">
            To exercise any of these rights, email{" "}
            <a href={`mailto:privacy@${siteConfig.domain}`} className="text-[var(--color-brand-600)] underline">
              privacy@{siteConfig.domain}
            </a>{" "}
            or use the in-app Account &rarr; Privacy menu. We will respond within 30
            days (45 days for complex requests, with notice). We may need to verify
            your identity before fulfilling a request, typically by confirming access
            to the email address on the account.
          </p>
          <p className="mt-4 text-pretty">
            <strong>Authorized agents (CCPA).</strong> California residents may
            designate an authorized agent to make a request on their behalf. We
            require written authorization signed by the consumer and verification of
            the consumer's identity before responding.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">10. Data retention</h2>
          <ul className="mt-4 ml-6 list-disc space-y-2">
            <li><strong>Account information.</strong> Retained for the lifetime of your account; deleted within 30 days of account deletion.</li>
            <li><strong>Interview transcripts and exchange logs.</strong> Retained for the lifetime of your account; deletable individually through the in-app Sessions list.</li>
            <li><strong>Audio.</strong> Not retained — discarded immediately after streaming transcription completes.</li>
            <li><strong>IP addresses.</strong> Truncated within 7 days of collection and discarded within 90 days.</li>
            <li><strong>Subscription and billing records.</strong> Retained for 7 years to comply with US tax recordkeeping rules.</li>
            <li><strong>Support correspondence.</strong> Retained for 24 months from the last interaction, unless deleted earlier on your request.</li>
          </ul>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">11. Security</h2>
          <p className="mt-4 text-pretty">
            We implement industry-standard technical and organizational measures:
            TLS 1.3 in transit, AES-256-GCM at rest, Argon2id password hashing, JWT
            authentication with short-lived access tokens, role-based access control
            for staff, and quarterly third-party penetration testing. No security
            measure is perfect; if we become aware of a personal data breach affecting
            your information, we will notify you within 72 hours where required by
            applicable law.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">12. Children's privacy</h2>
          <p className="mt-4 text-pretty">
            The Services are not directed to children under the age of 16. We do not
            knowingly collect personal information from children under 16. If you are
            a parent or guardian and believe your child has provided personal
            information to us, please contact{" "}
            <a href={`mailto:privacy@${siteConfig.domain}`} className="text-[var(--color-brand-600)] underline">
              privacy@{siteConfig.domain}
            </a>{" "}
            and we will promptly delete it. For the purposes of COPPA, the Services
            are designed for individuals over 16 and do not feature content directed
            at children.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">13. California privacy notice (CCPA / CPRA)</h2>
          <p className="mt-4 text-pretty">
            In the past 12 months, we have collected the following categories of
            personal information from California residents: identifiers (email, IP),
            customer records (name), commercial information (subscription status),
            internet activity (app usage logs), audio (transient, see Section 3.2),
            professional information (resume content), and inferences (interview
            performance summaries). The purposes are described in Section 4. The
            categories of recipients are described in Section 7. We retain each
            category for the period described in Section 10. We have not sold or
            shared personal information of California residents in the past 12
            months.
          </p>
          <p className="mt-4 text-pretty">
            <strong>Sensitive personal information.</strong> Resume content may include
            sensitive personal information depending on what you choose to include
            (e.g., race, religion, union membership). We process this only to deliver
            the Services and not for any other purpose; California residents have the
            right to limit processing of sensitive personal information to that
            purpose, and we already do so by default.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">14. Apple Privacy Manifest</h2>
          <p className="mt-4 text-pretty">
            The iOS application includes a Privacy Manifest declaring our use of
            required reason APIs (file timestamp, system boot time, user defaults)
            and the categories of data collected, linked to your identity, and used
            for tracking. We do not track users across apps and websites; we do not
            include any third-party SDKs that perform such tracking. Our manifest is
            available within the app bundle and is reflected in the App Store privacy
            "nutrition label."
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">15. Do Not Track and Global Privacy Control</h2>
          <p className="mt-4 text-pretty">
            Our website honors the Global Privacy Control (GPC) browser signal as a
            valid opt-out of "sale" and "sharing" under the CCPA. Because we do not
            sell or share personal information regardless, the practical effect of
            GPC on your experience is none — but we honor it formally.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">16. Changes to this Policy</h2>
          <p className="mt-4 text-pretty">
            We may update this Policy from time to time. The "Effective date" at the
            top reflects when the current version became effective. For material
            changes, we will provide at least 30 days' notice via email and an
            in-app notification before the change takes effect. Your continued use of
            the Services after the effective date constitutes acceptance of the
            updated Policy.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">17. Contact us</h2>
          <p className="mt-4 text-pretty">
            For privacy-related questions, requests, or complaints:
          </p>
          <ul className="mt-4 ml-6 list-disc space-y-2">
            <li>
              Email:{" "}
              <a href={`mailto:privacy@${siteConfig.domain}`} className="text-[var(--color-brand-600)] underline">
                privacy@{siteConfig.domain}
              </a>
            </li>
            <li>Postal: {siteConfig.legalEntity}, {siteConfig.legalAddress}</li>
          </ul>
        </div>
      </Container>
    </article>
  );
}
