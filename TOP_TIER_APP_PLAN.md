# InterviewPilot Top-Tier Product Plan

Date: 2026-03-13
Status: Proposed
Owner: Product + iOS + Backend

## 1. Executive Direction

InterviewPilot already has a credible technical base:

- Native SwiftUI app with polished UI
- Auth, subscriptions, and App Store billing
- Live audio capture + transcription + AI response generation
- Voice prep mode
- Session history and review
- Backend with Prisma/Postgres and session sync

What it does not yet have is the product depth, trust layer, growth loop, and operational maturity that distinguish a strong prototype from a top-selling App Store product.

The core strategic shift is this:

- Keep the live intelligence capability as an optional assistive layer for practice and consented coaching use cases
- Reposition the product around interview preparation, rehearsal, coaching, review, and measurable improvement
- Build a long-term retention loop so users return across multiple job searches, interview rounds, and companies

Top-selling apps win on repeat value, trust, polish, and progress tracking. This plan is designed around those four levers.

## 2. Product Positioning

### Current Position

The current app feels like a real-time interview helper with prep features attached.

### Target Position

InterviewPilot becomes an AI interview operating system:

- Personalized job workspace
- Resume-aware prep engine
- Mock interview simulator
- Live practice and rehearsal coach
- Session review and improvement plans
- Progress dashboard across companies and roles

### Positioning Statement

InterviewPilot helps candidates prepare for interviews with structured AI coaching, realistic mock interviews, company-specific practice, and detailed post-session feedback.

### Why This Matters

- Better App Store positioning
- Stronger long-term retention
- Lower trust risk
- More defensible subscription value
- Clearer path to enterprise, coaching, and B2B extensions later

## 3. North Star and Success Metrics

### North Star Metric

Weekly active candidates completing at least one meaningful prep action:

- mock interview
- question bank review
- drill session
- session review

### Core Metrics

- Activation: user creates first workspace within 1 session
- Time to value: first personalized question bank generated in under 2 minutes
- Retention: D7, D30, D90 by subscription tier
- Conversion: free-to-paid conversion after first review cycle
- Engagement: sessions per workspace, drills completed, streaks maintained
- Outcome proxy: self-reported interview confidence improvement
- Reliability: session success rate, live transcription uptime, AI response latency

### Quality Targets

- Crash-free sessions: 99.5%+
- Live session start success: 98%+
- Median time to first answer: under 1.5s for live practice
- Background sync success: 99%+

## 4. Product Principles

- Trust first: privacy, transparency, and explicit data controls
- Fast to value: the first personalized prep artifact must appear quickly
- Resume and job aware everywhere: all major surfaces should personalize
- Practice over gimmicks: every premium feature must improve readiness
- Review must drive action: every session should produce next steps
- Premium means outcomes: better coaching, not just more tokens

## 5. Current State Assessment

### Strengths Already Present

- Strong visual polish and coherent design system
- Functional auth and billing stack
- Working live audio and AI pipeline
- Backend persistence for sessions, exchanges, billing, and answer banks
- Voice prep mode already proves a second product surface

### Highest-Impact Gaps

- Answer bank generation exists but is not wired into the user journey
- History and sync are incomplete and fragmented
- Review is descriptive, not genuinely coaching-oriented
- Settings, account management, and preferences are thin
- No progress loop, no reminders, no streaks, no training plan
- No analytics, crash reporting, CI, test strategy, or feature flagging
- Raw vendor API keys are delivered to the client, which is not a production-grade security model

## 6. Target Product Surface

### Core Product Areas

1. Dashboard
2. Job Workspaces
3. Personalized Question Bank
4. Mock Interview / Voice Prep
5. Live Practice / Coaching Session
6. Session Review and Scorecards
7. Drills, Flashcards, and Weekly Plans
8. Progress Dashboard
9. Subscription, Referral, and Lifecycle
10. Support, Privacy, and Account Controls

### Recommended Tab Structure

- Home
- Workspaces
- Practice
- Progress
- Settings

## 7. Target User Flow

1. User signs in
2. User creates a workspace for a target role/company
3. User uploads or selects a resume version
4. User imports or pastes a job description
5. App generates:
   - company and role summary
   - likely question bank
   - strengths/risk areas
   - recommended prep plan
6. User completes mock interviews and drills
7. Each session produces:
   - transcript
   - scorecard
   - missed opportunities
   - targeted drills
8. Progress dashboard shows trends across sessions
9. Notifications and reminders drive return usage

## 8. Major Epics

## Epic A: Secure Production Architecture

### Goal

Replace prototype-grade AI credential handling and improve operational safety.

### Why

Top apps do not expose raw provider keys to clients unless there is a narrowly scoped ephemeral strategy. The current model is too loose for a serious paid product.

### Scope

- Remove direct raw OpenAI/Deepgram key delivery to the device
- Introduce backend AI gateway or short-lived scoped credentials
- Add request signing, rate limits per user, and usage accounting
- Add telemetry for model errors and latency
- Add secure deletion and export paths

### Backend Changes

- New `ai-proxy` module for:
  - answer bank generation
  - review generation
  - scoring and drills
  - optional live ephemeral session bootstrapping
- Usage ledger table for token/session cost accounting
- Rate-limit rules by tier and route

### Acceptance Criteria

- No long-lived vendor secret is returned to client devices
- Per-user usage is auditable
- AI failures surface actionable diagnostics

## Epic B: Job Workspaces

### Goal

Make the app organized around interview opportunities, not isolated sessions.

### Scope

- Create, edit, archive, and duplicate workspaces
- Attach company, role, location, seniority, and interview stage
- Support multiple resume versions per user
- Save imported job descriptions and generated company briefs
- Show upcoming prep tasks and most recent activity

### iOS Screens

- Workspace list
- Create/edit workspace
- Workspace detail
- Resume manager
- Job description importer
- Company brief screen

### Backend/API

- `GET/POST/PATCH /api/v1/workspaces`
- `GET/POST/PATCH /api/v1/resumes`
- `GET/POST/PATCH /api/v1/job-postings`
- `GET /api/v1/workspaces/:id/summary`

### Suggested Prisma Models

- `Workspace`
- `ResumeAsset`
- `JobPosting`
- `CompanyBrief`
- `InterviewPlan`

### Acceptance Criteria

- A user can manage multiple active interview processes cleanly
- Every session belongs to a workspace
- Workspace context is reused across prep and review

## Epic C: Personalized Question Bank and Prep Assets

### Goal

Turn the existing answer-bank code into a real moat.

### Scope

- Generate question banks during setup
- Persist and reload generated banks
- Allow user editing, pinning, regenerating, and marking confidence
- Add flashcards and quick review mode
- Add “why this question matters” explanations

### Immediate Codebase Alignment

This epic should wire together:

- existing `AnswerBankService`
- existing answer-banks backend routes
- `PreGenerationView`
- session setup flow

### iOS Screens

- Generation progress
- Question bank list
- Question detail editor
- Flashcard mode
- Saved answer variants

### Backend/API

- Extend `/api/v1/answer-banks`
- Add question-level notes, confidence, tags, and pinned state
- Add regenerate endpoint for single-question rewrites

### Acceptance Criteria

- Setup can generate and save a reusable question bank
- Live and mock sessions can draw from stored prep assets
- Users can edit generated content instead of treating it as disposable output

## Epic D: Session Review, Scoring, and Coaching

### Goal

Transform review from a passive recap into an actionable coaching loop.

### Scope

- Session scorecard
- Question-by-question ratings
- Filler word and verbosity analysis
- STAR quality checks
- technical depth and tradeoff completeness scoring
- missed personalization opportunities
- follow-up question weakness detection
- recommended next drills

### iOS Screens

- Review overview
- Scorecard
- Exchange coach detail
- Improvement plan
- Drill recommendations

### Backend/API

- `GET /api/v1/sessions/:id/review`
- `POST /api/v1/sessions/:id/review/regenerate`
- `POST /api/v1/drills`

### Suggested Prisma Models

- `SessionReview`
- `ExchangeFeedback`
- `CoachingInsight`
- `RecommendedDrill`

### Acceptance Criteria

- Every completed session can produce a structured scorecard
- The app always offers at least one clear next action
- Review artifacts persist and can be compared over time

## Epic E: Voice Prep Evolution

### Goal

Promote Voice Prep from a side mode into a core premium workflow.

### Scope

- Persist voice-prep sessions
- Support interviewer personas
- Add round templates:
  - recruiter screen
  - hiring manager
  - behavioral
  - technical
  - system design
- Add interruption handling and answer timing coaching
- Add “coach mode” after each answer with optional feedback

### iOS Screens

- Practice lobby
- Scenario picker
- Voice prep session
- Practice review

### Backend/API

- Persist practice sessions and transcripts
- Generate structured review and drills

### Acceptance Criteria

- Voice prep sessions appear in history and progress
- Users can select realistic interviewer modes
- Practice produces measurable coaching output

## Epic F: Progress System and Retention Loop

### Goal

Create a reason to keep coming back between interviews.

### Scope

- Weekly goals
- streaks
- reminders
- confidence tracking
- progress trends by interview type
- skill heatmap
- saved wins and weak spots

### iOS Screens

- Progress dashboard
- Weekly plan
- Habit reminders
- Skill heatmap

### Backend/API

- `GET /api/v1/progress`
- `GET /api/v1/goals`
- `PUT /api/v1/goals`
- push token registration

### Suggested Prisma Models

- `UserGoal`
- `SkillProgress`
- `NotificationPreference`
- `DevicePushToken`

### Acceptance Criteria

- Users can see improvement over time
- The app can recommend what to do next this week
- Notifications are tied to actual unfinished prep work

## Epic G: Premium Monetization and Lifecycle

### Goal

Move from a basic paywall to a mature subscription system.

### Scope

- Refined plan packaging
- usage caps and premium feature gating
- intro offers and win-back
- referral program
- upgrade prompts tied to value moments
- subscription FAQ and self-serve support

### Premium Packaging Recommendation

- Free: limited workspace count, limited mock sessions, limited review depth
- Plus: unlimited workspaces, question banks, review scorecards
- Pro: advanced voice prep, interviewer personas, adaptive drills, premium coaching

### Acceptance Criteria

- Upgrade prompts are triggered by value completion, not only hard stops
- Paid tiers map to outcomes users understand

## Epic H: Trust, Privacy, and App Store Readiness

### Goal

Build the layer users and reviewers expect from a serious consumer app.

### Scope

- Privacy center
- consent and data handling explanations
- export data
- delete account
- contact support
- Terms and Privacy links
- onboarding that explains safe/expected product use

### Acceptance Criteria

- Privacy and account controls are available in-app
- The product language emphasizes prep and coaching rather than deceptive use

## Epic I: Operational Excellence

### Goal

Reach the delivery maturity of a professional app company.

### Scope

- Unit tests
- integration tests
- smoke UI tests
- CI/CD
- crash reporting
- product analytics
- feature flags
- remote config
- release checklists
- observability dashboards

### Tooling Recommendation

- CI: GitHub Actions or Bitrise
- Crash reporting: Sentry or Firebase Crashlytics
- Analytics: Amplitude or Mixpanel
- Feature flags: LaunchDarkly, Statsig, or a lightweight internal system
- API monitoring: structured logs + uptime alerts

### Acceptance Criteria

- Main flows are covered by automated checks
- Production releases are repeatable
- Team can monitor failures and rollout changes safely

## 9. Suggested Data Model Expansion

Add the following models incrementally. Do not build them all at once.

### Phase 1 Required

- `Workspace`
  - `id`
  - `userId`
  - `title`
  - `companyName`
  - `roleTitle`
  - `stage`
  - `status`
  - `createdAt`
  - `updatedAt`

- `ResumeAsset`
  - `id`
  - `userId`
  - `name`
  - `rawText`
  - `sourceType`
  - `isDefault`

- `JobPosting`
  - `id`
  - `workspaceId`
  - `sourceUrl`
  - `rawText`
  - `parsedMetadata`

### Phase 2 Required

- `SessionReview`
  - `id`
  - `sessionId`
  - `overallScore`
  - `summary`
  - `strengths`
  - `risks`
  - `recommendedFocus`

- `ExchangeFeedback`
  - `id`
  - `reviewId`
  - `exchangeId`
  - `score`
  - `feedback`
  - `missedOpportunity`
  - `improvedAnswer`

- `RecommendedDrill`
  - `id`
  - `reviewId`
  - `title`
  - `reason`
  - `skill`

### Phase 3 Required

- `UserGoal`
- `SkillProgress`
- `NotificationPreference`
- `DevicePushToken`
- `AnalyticsEvent` or external analytics pipeline

## 10. API Roadmap

## Phase 1 APIs

- `GET /api/v1/workspaces`
- `POST /api/v1/workspaces`
- `PATCH /api/v1/workspaces/:id`
- `GET /api/v1/workspaces/:id`
- `GET /api/v1/workspaces/:id/assets`
- `POST /api/v1/workspaces/:id/generate-question-bank`
- `GET /api/v1/answer-banks/:id`
- `PATCH /api/v1/answer-banks/:id/questions/:questionId`

## Phase 2 APIs

- `GET /api/v1/sessions/:id/review`
- `POST /api/v1/sessions/:id/review`
- `GET /api/v1/workspaces/:id/progress`
- `GET /api/v1/drills`
- `POST /api/v1/drills/:id/complete`

## Phase 3 APIs

- `GET /api/v1/dashboard`
- `GET /api/v1/goals`
- `PUT /api/v1/goals`
- `PUT /api/v1/notifications/preferences`
- `POST /api/v1/devices/push-token`

## 11. iOS Screen Map

## New Screens

- HomeDashboardView
- WorkspaceListView
- WorkspaceDetailView
- WorkspaceEditorView
- ResumeLibraryView
- JobImportView
- CompanyBriefView
- QuestionBankView
- QuestionDetailView
- FlashcardReviewView
- PracticeLobbyView
- MockInterviewScenarioView
- SessionScorecardView
- ProgressDashboardView
- WeeklyPlanView
- PrivacyCenterView
- SupportView

## Existing Screens To Expand

- `SessionSetupView`
- `PreGenerationView`
- `PrepSessionView`
- `SessionReviewView`
- `SessionHistoryView`
- `SettingsView`

## 12. Prioritized Build Order

## Phase 0: Stabilize and Secure

Duration: 1-2 weeks

### Deliverables

- AI key delivery replaced with secure gateway or ephemeral strategy
- add analytics and crash reporting
- add CI with backend build and iOS build
- add smoke tests for auth, setup, session start
- add sync status reporting and retry queue

### Exit Criteria

- Production architecture no longer depends on long-lived raw vendor keys on client
- Build and release health visible to team

## Phase 1: Core Product Moat

Duration: 2-4 weeks

### Deliverables

- Job workspaces
- resume library
- question bank generation integrated into setup
- answer bank persistence and editing
- workspace-centric navigation

### Exit Criteria

- New user can create workspace, generate personalized prep assets, and return to them later

## Phase 2: Review and Coaching

Duration: 2-4 weeks

### Deliverables

- session scorecard
- exchange-level coaching
- recommended drills
- better session history with remote hydration
- practice session persistence

### Exit Criteria

- Every session produces a meaningful review artifact and at least one next action

## Phase 3: Practice Depth and Retention

Duration: 2-3 weeks

### Deliverables

- interviewer personas
- round templates
- progress dashboard
- goals and reminders
- streaks and weekly plan

### Exit Criteria

- Users have a reason to return weekly even without an immediate interview tomorrow

## Phase 4: Monetization and Scale

Duration: 2-3 weeks

### Deliverables

- refined paywall and value moment prompts
- referral flow
- win-back lifecycle
- support/privacy/account center
- localization and accessibility pass

### Exit Criteria

- Product is commercially and operationally credible at scale

## 13. Concrete Codebase Refactor Plan

## iOS

### Session Setup

- convert `SessionSetupViewModel` into a workspace-aware orchestrator
- load existing workspace state
- trigger prep generation before session launch
- pass generated answer bank into live session

### History and Review

- merge local SwiftData storage with backend hydration
- preserve transcript, review, and session mode
- add sync states: pending, synced, failed

### Settings

- bind to backend settings endpoints
- add account, privacy, notifications, support, and data controls

### Voice Prep

- persist practice sessions
- allow selectable scenarios
- add post-session review path

## Backend

### New Modules

- `workspaces`
- `resumes`
- `job-postings`
- `reviews`
- `drills`
- `dashboard`
- `notifications`
- `ai-proxy`

### Existing Modules To Expand

- `answer-banks`
- `sessions`
- `settings`
- `billing`
- `users`

## 14. Testing Plan

## iOS

- Unit tests:
  - prompt shaping
  - classification
  - workspace orchestration
  - review parsing
- Integration tests:
  - session setup to question bank creation
  - local + remote sync reconciliation
- UI tests:
  - auth
  - create workspace
  - generate prep
  - start practice session

## Backend

- route validation tests
- auth and billing flow tests
- session sync tests
- review generation contract tests
- Prisma integration tests against test database

## 15. Analytics Events

Track these from day one of the roadmap:

- `workspace_created`
- `resume_uploaded`
- `job_posting_imported`
- `question_bank_generated`
- `question_bank_opened`
- `mock_session_started`
- `live_practice_started`
- `session_completed`
- `review_opened`
- `drill_started`
- `drill_completed`
- `paywall_viewed`
- `trial_limit_hit`
- `purchase_started`
- `purchase_completed`
- `notification_enabled`

## 16. Accessibility and Localization

Top-selling apps do not treat these as cleanup tasks.

### Accessibility

- Dynamic Type audit
- VoiceOver labels across major controls
- sufficient contrast in glass surfaces
- motion reduction support
- haptics not required for comprehension

### Localization

- begin with English
- add infrastructure for localization immediately
- first expansion target: Spanish

## 17. Risks and Mitigations

### Risk: Product remains perceived as a cheating tool

Mitigation:

- reframe onboarding, marketing, and in-app copy toward preparation and coaching
- prioritize mock interview and review features above live-assist expansion

### Risk: AI cost scales faster than revenue

Mitigation:

- central usage accounting
- caching and reuse of prep artifacts
- tier-based rate limits
- small/fast models for classification and drafts

### Risk: Session reliability suffers under network variability

Mitigation:

- local buffering
- retry queue
- sync state UI
- degraded-mode handling

### Risk: Team ships features without insight

Mitigation:

- analytics, crash reporting, and feature flags before large roadmap expansion

## 18. Recommended Immediate Next Build

If the team starts implementation now, the first milestone should be:

1. Secure AI access model
2. Workspace model and navigation
3. Integrated question-bank generation during setup
4. Persisted answer bank editing and reuse
5. Remote-backed history with sync states
6. Review v2 scorecard skeleton

This is the smallest slice that changes the app from “cool demo” to “serious product.”

## 19. Final Recommendation

Do not optimize first for more covert live-answer behaviors.

Optimize first for:

- personalized prep assets
- realistic rehearsal
- actionable review
- trust and reliability
- weekly retention

That is the path to a robust, premium, App Store-scalable product.
