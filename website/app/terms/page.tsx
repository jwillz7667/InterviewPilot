import type { Metadata } from "next";
import { Container } from "@/components/ui/container";
import { siteConfig } from "@/lib/site";

export const metadata: Metadata = {
  title: "Terms of Service",
  description:
    "The terms governing your use of Interview Ace, including Apple App Store subscription disclosures, acceptable use, intellectual property, AI-generated content disclaimers, dispute resolution, and class action waiver.",
  alternates: { canonical: "/terms" },
  robots: { index: true, follow: true },
};

const LAST_UPDATED = "May 7, 2026";
const EFFECTIVE_DATE = "May 7, 2026";

export default function TermsPage() {
  return (
    <article className="bg-[var(--color-bg)]">
      <header className="border-b border-[var(--color-border)] bg-[var(--color-bg-subtle)] py-16">
        <Container>
          <p className="text-sm font-semibold uppercase tracking-wider text-[var(--color-fg-subtle)]">
            Legal
          </p>
          <h1 className="mt-3 text-balance font-display text-5xl font-bold tracking-tight">
            Terms of Service
          </h1>
          <p className="mt-4 text-[var(--color-fg-muted)]">
            Effective date: {EFFECTIVE_DATE} · Last updated: {LAST_UPDATED}
          </p>
        </Container>
      </header>
      <Container className="py-16">
        <div className="prose mx-auto max-w-3xl text-[17px] leading-[1.75] text-[var(--color-fg)]">
          <p className="text-pretty">
            <strong>
              Please read these Terms of Service ("Terms") carefully. They contain a
              binding arbitration clause and a class action waiver in Section 18.
            </strong>{" "}
            By creating an account or using the Services, you agree to be bound by
            these Terms.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">1. Acceptance of Terms</h2>
          <p className="mt-4 text-pretty">
            These Terms form a legally binding agreement between you and{" "}
            {siteConfig.legalEntity} ("Interview Ace", "we", "us", or "our"),
            governing your use of the Interview Ace iOS application, the website at{" "}
            {siteConfig.domain}, and any related products and services
            (collectively, the "Services"). If you do not agree to these Terms, do
            not use the Services.
          </p>
          <p className="mt-4 text-pretty">
            You must be at least 16 years old (or the age of majority in your
            jurisdiction, whichever is greater) to use the Services. If you are using
            the Services on behalf of a company or other legal entity, you represent
            that you have the authority to bind that entity to these Terms.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">2. The Services</h2>
          <p className="mt-4 text-pretty">
            Interview Ace provides AI-powered tools to help users prepare for and
            participate in job interviews. Features include real-time audio
            transcription, AI-generated answer suggestions, post-session analytics,
            and practice mock interview functionality. The specific features
            available depend on your subscription tier (Free, Pro, or Premium) as
            described on{" "}
            <a href="/pricing" className="text-[var(--color-brand-600)] underline">
              {siteConfig.url}/pricing
            </a>
            .
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">3. Your account</h2>
          <p className="mt-4 text-pretty">
            You are responsible for the security of your account. You must keep your
            login credentials confidential and notify us promptly at{" "}
            <a href={`mailto:security@${siteConfig.domain}`} className="text-[var(--color-brand-600)] underline">
              security@{siteConfig.domain}
            </a>{" "}
            if you suspect unauthorized access. You are responsible for all activity
            that occurs under your account, regardless of whether you authorized it.
          </p>
          <p className="mt-4 text-pretty">
            You agree to provide accurate information during account registration and
            to keep that information up to date. We may suspend or terminate
            accounts that we believe contain false information.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">4. Subscriptions and billing</h2>
          <p className="mt-4 text-pretty">
            We offer paid subscriptions ("Pro" and "Premium") in addition to a free
            tier ("Free"). Subscriptions are billed through Apple's App Store using
            the Apple ID associated with your device.
          </p>
          <h3 className="mt-6 font-display text-xl font-semibold tracking-tight">4.1 Apple App Store disclosures</h3>
          <ul className="mt-4 ml-6 list-disc space-y-2">
            <li>Subscriptions are available in monthly and annual billing periods.</li>
            <li>Payment will be charged to your Apple ID at confirmation of purchase.</li>
            <li>
              Subscriptions automatically renew unless auto-renew is turned off at
              least 24 hours before the end of the current period.
            </li>
            <li>
              Your account will be charged for renewal within 24 hours prior to the
              end of the current period at the rate then displayed in the App Store.
            </li>
            <li>
              You can manage and cancel your subscription by going to your account
              settings on the App Store after purchase: Settings &rarr; [your name]{" "}
              &rarr; Subscriptions.
            </li>
            <li>
              Any unused portion of a free trial period will be forfeited when you
              purchase a subscription, where applicable.
            </li>
          </ul>
          <h3 className="mt-6 font-display text-xl font-semibold tracking-tight">4.2 Refunds</h3>
          <p className="mt-4 text-pretty">
            All refund requests for App Store purchases must be submitted to Apple via{" "}
            <a
              href="https://reportaproblem.apple.com"
              target="_blank"
              rel="noopener noreferrer"
              className="text-[var(--color-brand-600)] underline"
            >
              reportaproblem.apple.com
            </a>
            . We do not have access to your payment method and cannot process refunds
            directly. Apple's refund policy applies. Where local law (for example, EU
            consumer-protection law) requires a withdrawal right, you retain that
            right and may exercise it through Apple.
          </p>
          <h3 className="mt-6 font-display text-xl font-semibold tracking-tight">4.3 Quotas and tier changes</h3>
          <p className="mt-4 text-pretty">
            Each tier includes a quota of standard and premium interviews per
            30-day rolling period as described on the pricing page. Quotas reset on
            a rolling 30-day basis from your subscription start date. Unused quota
            does not carry over between periods. Upgrading or downgrading your
            subscription updates your quota for the next billing cycle. Apple
            handles proration of charges according to its standard rules.
          </p>
          <h3 className="mt-6 font-display text-xl font-semibold tracking-tight">4.4 Price changes</h3>
          <p className="mt-4 text-pretty">
            We may change the prices of subscriptions. For existing subscribers, any
            price increase will take effect no earlier than the next renewal period
            after we provide you with at least 30 days' notice via email and an in-app
            notification. You may cancel at any time before the new price takes
            effect.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">5. Free tier</h2>
          <p className="mt-4 text-pretty">
            We offer a Free tier with a limited monthly quota and reduced feature
            set. We may modify, suspend, or discontinue the Free tier at any time
            with reasonable advance notice. We will not retroactively reduce the
            features of any paid tier you have already purchased.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">6. Acceptable Use Policy</h2>
          <p className="mt-4 text-pretty">You agree not to:</p>
          <ul className="mt-4 ml-6 list-disc space-y-2">
            <li>
              Use the Services to deceive an interviewer about your underlying skills
              or qualifications. The Services are designed to amplify your own
              thinking, not to misrepresent who you are.
            </li>
            <li>
              Use the Services in any setting where their use is explicitly
              prohibited by an interviewer, employer, or applicable contract.
            </li>
            <li>
              Use the Services for any unlawful purpose, or to violate any law or
              regulation in your jurisdiction (including export controls and
              sanctions lists).
            </li>
            <li>
              Reverse engineer, decompile, disassemble, or otherwise attempt to
              derive the source code of any part of the Services, except to the
              extent permitted by applicable law.
            </li>
            <li>
              Use any automated means to access the Services, including scraping,
              bots, or API circumvention, except through our documented public APIs.
            </li>
            <li>
              Probe, scan, or test the vulnerability of any system or network we
              operate, or breach any security or authentication measure.
            </li>
            <li>
              Submit content to the Services that infringes any third party's
              intellectual property rights, contains malicious code, or violates any
              law or these Terms.
            </li>
            <li>
              Resell, lease, or sublicense access to the Services without our prior
              written agreement.
            </li>
            <li>
              Submit personal information of third parties (other than information
              that is reasonably included in your resume, such as the names of
              former colleagues or managers) without their consent.
            </li>
            <li>
              Use the Services to compete directly with us, including building a
              competing product trained on our outputs.
            </li>
          </ul>
          <p className="mt-4 text-pretty">
            We may suspend or terminate your access to the Services if you violate
            this Acceptable Use Policy, with or without notice depending on the
            severity.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">7. AI-generated content disclaimer</h2>
          <p className="mt-4 text-pretty">
            <strong>
              The AI-generated suggestions provided by the Services are not guaranteed
              to be accurate, complete, or appropriate for any particular situation.
            </strong>{" "}
            Language models can hallucinate, omit important caveats, or produce
            content that, while plausible, is factually incorrect or contextually
            inappropriate. You are solely responsible for reviewing and adapting any
            output before relying on it.
          </p>
          <p className="mt-4 text-pretty">
            The Services do not provide legal, financial, medical, or professional
            advice. AI-generated content should not be relied upon as a substitute
            for professional judgment in any context where accuracy is critical.
          </p>
          <p className="mt-4 text-pretty">
            <strong>You retain ownership of the content you submit.</strong> We do
            not claim ownership of your resume, job description, or any text you
            input. You retain ownership of the AI-generated outputs to the extent
            permitted by applicable law, subject to the underlying model providers'
            terms; we do not assert a copyright claim against you for using the
            outputs in your job search.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">8. Intellectual property</h2>
          <h3 className="mt-6 font-display text-xl font-semibold tracking-tight">8.1 Our IP</h3>
          <p className="mt-4 text-pretty">
            The Services, including all software, designs, text, graphics, prompts,
            and trademarks, are owned by {siteConfig.legalEntity} or our licensors
            and are protected by copyright, trademark, and other intellectual
            property laws. We grant you a limited, non-exclusive, non-transferable,
            revocable license to use the Services for your personal, non-commercial
            purposes (or for the internal business purposes of your employer if you
            have purchased a business subscription).
          </p>
          <h3 className="mt-6 font-display text-xl font-semibold tracking-tight">8.2 Your content</h3>
          <p className="mt-4 text-pretty">
            You retain ownership of all content you submit to the Services
            ("User Content"). You grant us a limited, worldwide, royalty-free
            license to host, store, transmit, and process User Content solely to
            provide the Services to you. This license terminates when you delete
            your User Content or your account, except to the extent required by
            applicable law (for example, retention of billing records).
          </p>
          <h3 className="mt-6 font-display text-xl font-semibold tracking-tight">8.3 Feedback</h3>
          <p className="mt-4 text-pretty">
            If you provide us with suggestions, ideas, or feedback about the
            Services ("Feedback"), you grant us a perpetual, irrevocable, worldwide,
            royalty-free license to use, modify, and incorporate the Feedback into
            the Services without compensation or attribution.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">9. Third-party services and AI subprocessors</h2>
          <p className="mt-4 text-pretty">
            The Services rely on third-party AI providers, including OpenAI for
            language models and Deepgram for transcription. Your use of the Services
            is subject to those providers' acceptable use policies as they apply to
            our integration. We have configured these providers to disable training
            on your data and to retain your inputs and outputs for the minimum
            duration available.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">10. Privacy</h2>
          <p className="mt-4 text-pretty">
            Your use of the Services is also governed by our{" "}
            <a href="/privacy" className="text-[var(--color-brand-600)] underline">
              Privacy Policy
            </a>
            , which is incorporated into these Terms by reference.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">11. Modifications to the Services</h2>
          <p className="mt-4 text-pretty">
            We may modify, update, suspend, or discontinue any part of the Services
            at any time. Where the change materially reduces functionality you have
            paid for, we will provide reasonable notice and a pro rata refund for
            the unused portion of any prepaid subscription, processed through Apple.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">12. Termination</h2>
          <p className="mt-4 text-pretty">
            You may terminate your account at any time through the in-app Account{" "}
            &rarr; Delete account flow. We may suspend or terminate your account at
            any time for any breach of these Terms. Upon termination, your right to
            access the Services ends immediately, and we will delete your User
            Content within 30 days, except where retention is required by law.
            Sections 7, 8, 13, 14, 15, 16, 17, 18, and 19 survive termination.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">13. Disclaimer of warranties</h2>
          <p className="mt-4 text-pretty">
            <strong>
              THE SERVICES ARE PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES
              OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING WARRANTIES OF
              MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
              NON-INFRINGEMENT.
            </strong>{" "}
            We do not warrant that the Services will be uninterrupted, error-free,
            or that the AI-generated outputs will be accurate or suitable for any
            specific purpose. To the maximum extent permitted by law, we disclaim
            all such warranties.
          </p>
          <p className="mt-4 text-pretty">
            Some jurisdictions do not allow the exclusion of certain warranties.
            Where this is the case, the exclusions in this section apply to the
            maximum extent permitted by your local law.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">14. Limitation of liability</h2>
          <p className="mt-4 text-pretty">
            <strong>
              TO THE MAXIMUM EXTENT PERMITTED BY LAW, IN NO EVENT WILL{" "}
              {siteConfig.legalEntity.toUpperCase()} BE LIABLE TO YOU FOR ANY
              INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES,
              INCLUDING LOST PROFITS, LOST DATA, OR LOST OPPORTUNITY (INCLUDING ANY
              JOB OFFER OR EMPLOYMENT OUTCOME), ARISING OUT OF OR IN CONNECTION WITH
              THE SERVICES, REGARDLESS OF THE LEGAL THEORY UNDER WHICH SUCH DAMAGES
              ARE SOUGHT.
            </strong>
          </p>
          <p className="mt-4 text-pretty">
            <strong>
              OUR TOTAL CUMULATIVE LIABILITY ARISING OUT OF OR RELATED TO THESE
              TERMS OR THE SERVICES WILL NOT EXCEED THE GREATER OF (A) THE AMOUNT
              YOU PAID US IN THE 12 MONTHS PRECEDING THE EVENT GIVING RISE TO THE
              CLAIM, OR (B) US$100.
            </strong>
          </p>
          <p className="mt-4 text-pretty">
            These limitations apply even if the limited remedy fails of its
            essential purpose. Some jurisdictions do not allow these limitations;
            in those jurisdictions, our liability is limited to the maximum extent
            permitted by law.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">15. Indemnification</h2>
          <p className="mt-4 text-pretty">
            You agree to indemnify, defend, and hold harmless{" "}
            {siteConfig.legalEntity}, its officers, directors, employees, and agents
            from and against any claims, damages, losses, costs, and expenses
            (including reasonable attorneys' fees) arising from (i) your use of the
            Services, (ii) your violation of these Terms, or (iii) your violation
            of any third party's rights, including intellectual property rights.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">16. Governing law</h2>
          <p className="mt-4 text-pretty">
            These Terms are governed by the laws of the State of Delaware, USA,
            without regard to its conflict of laws principles. The United Nations
            Convention on Contracts for the International Sale of Goods does not
            apply.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">17. Apple-specific terms</h2>
          <p className="mt-4 text-pretty">
            The following provisions apply to use of the iOS application acquired
            through the Apple App Store:
          </p>
          <ul className="mt-4 ml-6 list-disc space-y-2">
            <li>These Terms are between you and {siteConfig.legalEntity} only, not Apple. Apple is not responsible for the application or its content.</li>
            <li>The license granted is a non-transferable license to use the application on Apple-branded products you own or control, in accordance with the Usage Rules in the App Store Terms of Service.</li>
            <li>{siteConfig.legalEntity} is solely responsible for providing maintenance and support for the application; Apple has no obligation to provide any maintenance or support.</li>
            <li>{siteConfig.legalEntity} is solely responsible for any product warranties, whether express or implied by law, to the extent not effectively disclaimed. In the event of any failure of the application to conform to any applicable warranty, you may notify Apple, and Apple will refund the purchase price for the application; Apple has no other warranty obligation.</li>
            <li>{siteConfig.legalEntity} is solely responsible for addressing any claims related to the application or your use of it, including (i) product liability, (ii) failure to conform to legal requirements, and (iii) consumer-protection or similar claims.</li>
            <li>In the event of a third-party claim that the application or your use of it infringes that party's intellectual property rights, {siteConfig.legalEntity}, not Apple, is solely responsible for the investigation, defense, settlement, and discharge of such claim.</li>
            <li>You represent that you are not located in a country subject to U.S. Government embargo and that you are not on any U.S. Government list of prohibited or restricted parties.</li>
            <li>Apple and Apple's subsidiaries are third-party beneficiaries of these Terms and, upon your acceptance of these Terms, will have the right to enforce these Terms against you as third-party beneficiaries.</li>
          </ul>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">18. Dispute resolution and class action waiver</h2>
          <p className="mt-4 text-pretty">
            <strong>Please read this section carefully — it affects your legal rights.</strong>
          </p>
          <h3 className="mt-6 font-display text-xl font-semibold tracking-tight">18.1 Informal resolution</h3>
          <p className="mt-4 text-pretty">
            Before filing a claim, you agree to try to resolve the dispute informally
            by contacting{" "}
            <a href={`mailto:legal@${siteConfig.domain}`} className="text-[var(--color-brand-600)] underline">
              legal@{siteConfig.domain}
            </a>
            . We will try to resolve the dispute by contacting you via the email
            address on your account. If we cannot reach a resolution within 60 days,
            either party may proceed to formal resolution.
          </p>
          <h3 className="mt-6 font-display text-xl font-semibold tracking-tight">18.2 Binding arbitration</h3>
          <p className="mt-4 text-pretty">
            Any dispute that is not resolved informally will be resolved by binding
            arbitration administered by JAMS under its Streamlined Arbitration Rules
            and Procedures. The arbitration will take place in Wilmington, Delaware
            (or remotely at the parties' agreement). The arbitrator's award is final
            and binding, and judgment on the award may be entered in any court of
            competent jurisdiction.
          </p>
          <h3 className="mt-6 font-display text-xl font-semibold tracking-tight">18.3 Class action waiver</h3>
          <p className="mt-4 text-pretty">
            <strong>
              YOU AND {siteConfig.legalEntity.toUpperCase()} AGREE TO RESOLVE
              DISPUTES ON AN INDIVIDUAL BASIS. YOU WAIVE THE RIGHT TO PARTICIPATE IN
              A CLASS ACTION, CLASS ARBITRATION, OR REPRESENTATIVE ACTION.
            </strong>{" "}
            The arbitrator has no power to combine multiple claimants' claims into a
            class proceeding.
          </p>
          <h3 className="mt-6 font-display text-xl font-semibold tracking-tight">18.4 Exceptions</h3>
          <p className="mt-4 text-pretty">
            Either party may seek (i) small-claims court relief for individual
            disputes within the scope of small-claims jurisdiction, or
            (ii) injunctive or equitable relief in a court of competent jurisdiction
            to protect intellectual property rights, regardless of this section.
          </p>
          <h3 className="mt-6 font-display text-xl font-semibold tracking-tight">18.5 Right to opt out of arbitration</h3>
          <p className="mt-4 text-pretty">
            You may opt out of the arbitration agreement and class action waiver by
            sending written notice to{" "}
            <a href={`mailto:legal@${siteConfig.domain}`} className="text-[var(--color-brand-600)] underline">
              legal@{siteConfig.domain}
            </a>{" "}
            within 30 days of first accepting these Terms. Your notice must include
            your name, the email address on your account, and a clear statement that
            you wish to opt out of arbitration.
          </p>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">19. General provisions</h2>
          <ul className="mt-4 ml-6 list-disc space-y-2">
            <li><strong>Entire agreement.</strong> These Terms, together with the Privacy Policy, constitute the entire agreement between you and us regarding the Services.</li>
            <li><strong>Severability.</strong> If any provision is held invalid or unenforceable, the remaining provisions remain in effect.</li>
            <li><strong>No waiver.</strong> Our failure to enforce any provision is not a waiver of our right to enforce it later.</li>
            <li><strong>Assignment.</strong> You may not assign these Terms without our prior written consent. We may assign these Terms in connection with a merger, acquisition, or sale of assets.</li>
            <li><strong>Force majeure.</strong> Neither party is liable for failures or delays caused by events beyond reasonable control (war, natural disaster, internet outages, government action).</li>
            <li><strong>Notices.</strong> We may provide notice via email to the address on your account, in-app notifications, or by posting to our website. You may provide notice to us at the email address in Section 20.</li>
            <li><strong>Headings.</strong> Section headings are for convenience only and do not affect interpretation.</li>
          </ul>

          <h2 className="mt-12 font-display text-2xl font-bold tracking-tight">20. Contact us</h2>
          <p className="mt-4 text-pretty">
            For questions about these Terms or the Services:
          </p>
          <ul className="mt-4 ml-6 list-disc space-y-2">
            <li>
              General inquiries:{" "}
              <a href={`mailto:${siteConfig.email}`} className="text-[var(--color-brand-600)] underline">
                {siteConfig.email}
              </a>
            </li>
            <li>
              Legal:{" "}
              <a href={`mailto:legal@${siteConfig.domain}`} className="text-[var(--color-brand-600)] underline">
                legal@{siteConfig.domain}
              </a>
            </li>
            <li>Postal: {siteConfig.legalEntity}, {siteConfig.legalAddress}</li>
          </ul>
        </div>
      </Container>
    </article>
  );
}
