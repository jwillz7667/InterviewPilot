import { PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  // Test user
  const testEmail = 'dev@interviewpilot.app';
  const testPassword = 'InterviewPilot2026!';

  const passwordHash = await argon2.hash(testPassword, {
    type: argon2.argon2id,
    memoryCost: 65536,
    timeCost: 3,
    parallelism: 4,
  });

  const user = await prisma.user.upsert({
    where: { email: testEmail },
    update: {
      displayName: 'Sandbox Test User',
      emailVerified: true,
      isSandboxTester: true,
      lastLoginAt: new Date(),
    },
    create: {
      email: testEmail,
      passwordHash,
      displayName: 'Sandbox Test User',
      emailVerified: true,
      isSandboxTester: true,
      lastLoginAt: new Date(),
      settings: {
        create: {
          defaultInterviewType: 'general',
          defaultResponseFormat: 'hybrid',
          shouldPreGenerate: true,
        },
      },
    },
  });

  console.log(`Test user created/found: ${user.email} (id: ${user.id})`);

  await prisma.userEntitlement.upsert({
    where: { userId: user.id },
    update: {
      tier: 'SANDBOX',
      status: 'SANDBOX',
      provider: 'INTERNAL',
      product: 'SANDBOX_FULL_ACCESS',
      productId: 'sandbox.full.access',
      sandboxFullAccess: true,
      lastVerifiedAt: new Date(),
    },
    create: {
      userId: user.id,
      tier: 'SANDBOX',
      status: 'SANDBOX',
      provider: 'INTERNAL',
      product: 'SANDBOX_FULL_ACCESS',
      productId: 'sandbox.full.access',
      sandboxFullAccess: true,
      trialInterviewLimit: 5,
      lastVerifiedAt: new Date(),
    },
  });

  // Sample answer bank
  const existingBank = await prisma.answerBank.findFirst({
    where: { userId: user.id, name: 'Senior iOS Engineer Prep' },
  });

  if (!existingBank) {
    await prisma.answerBank.create({
      data: {
        userId: user.id,
        name: 'Senior iOS Engineer Prep',
        resumeText: 'Sample resume text for testing',
        jobDescription: 'Senior iOS Engineer at a top tech company',
        interviewType: 'technical',
        answers: {
          create: [
            {
              question: 'Tell me about a time you led a complex iOS architecture migration.',
              response:
                'I led our team of 8 engineers through a migration from UIKit to SwiftUI across our main app serving 2M DAU. I architected a hybrid approach using UIHostingController bridges, which let us migrate screen-by-screen over 4 months without a big-bang rewrite. We reduced UI-related crashes by 73% and improved feature delivery velocity by 40%.',
              questionType: 'behavioral',
            },
            {
              question: 'How would you design a real-time data sync system for an iOS app?',
              response:
                'I would use a WebSocket connection for real-time updates combined with a local Core Data or SwiftData store for offline resilience. The sync protocol uses vector clocks for conflict resolution with a last-write-wins fallback. On reconnection, the client sends its last-seen timestamp and the server returns a delta. This approach reduced our sync latency from 2s polling to 50ms push.',
              questionType: 'systemDesign',
            },
            {
              question: 'Explain Swift concurrency and how you handle data races.',
              response:
                'Swift concurrency uses structured concurrency with async/await, actors for isolation, and Sendable for thread-safe value passing. I use @MainActor for UI state, dedicated actors for shared mutable state, and TaskGroups for parallel work. In our last project, adopting strict concurrency checking eliminated 100% of our threading crashes in production.',
              questionType: 'technical',
            },
            {
              question: 'What is your approach to testing iOS applications?',
              response:
                'I follow a testing pyramid: unit tests for business logic (XCTest, 80% coverage target), integration tests for service layer interactions, and UI tests for critical flows (XCUITest). I use protocol-oriented design for dependency injection, making services easily mockable. Our CI pipeline runs 2,400 tests in under 3 minutes using parallel test plans.',
              questionType: 'technical',
            },
            {
              question: 'Why are you interested in this role?',
              response:
                'I am drawn to the intersection of AI and mobile that this role represents. Having built real-time audio processing pipelines and shipped apps to millions of users, I see this as the perfect opportunity to push the boundaries of what is possible on-device. The team\'s focus on performance and user experience aligns perfectly with my engineering philosophy.',
              questionType: 'background',
            },
          ],
        },
      },
    });
    console.log('Sample answer bank created');
  }

  // Sample interview session
  const existingSession = await prisma.interviewSession.findFirst({
    where: { userId: user.id },
  });

  if (!existingSession) {
    await prisma.interviewSession.create({
      data: {
        clientId: '00000000-0000-0000-0000-000000000001',
        userId: user.id,
        startedAt: new Date(Date.now() - 30 * 60 * 1000), // 30 min ago
        endedAt: new Date(),
        resumeText: 'Sample resume',
        jobDescription: 'Senior iOS Engineer',
        interviewType: 'technical',
        responseFormat: 'hybrid',
        modelUsed: 'gpt-4.1-nano',
        totalTokensUsed: 4500,
        estimatedCost: 0.15,
        exchanges: {
          create: [
            {
              clientId: '00000000-0000-0000-0000-000000000010',
              timestamp: new Date(Date.now() - 25 * 60 * 1000),
              questionTranscript: 'Tell me about yourself and your experience with iOS development.',
              questionType: 'background',
              generatedResponse:
                'I have been building iOS apps for over 8 years, starting with Objective-C and transitioning fully to Swift. Most recently, I architected a SwiftUI-based app serving 2 million daily active users.',
              responseLatencyMs: 1200,
              wasPreComputed: false,
              sequenceOrder: 0,
            },
            {
              clientId: '00000000-0000-0000-0000-000000000011',
              timestamp: new Date(Date.now() - 20 * 60 * 1000),
              questionTranscript: 'How do you handle memory management in Swift?',
              questionType: 'technical',
              generatedResponse:
                'Swift uses ARC for memory management. I am careful with retain cycles by using weak and unowned references in closures and delegate patterns. I regularly profile with Instruments to catch leaks.',
              responseLatencyMs: 980,
              wasPreComputed: true,
              sequenceOrder: 1,
            },
            {
              clientId: '00000000-0000-0000-0000-000000000012',
              timestamp: new Date(Date.now() - 15 * 60 * 1000),
              questionTranscript:
                'Describe a challenging bug you debugged recently.',
              questionType: 'behavioral',
              generatedResponse:
                'We had a race condition in our real-time audio pipeline where two actors were mutating shared state. I used Instruments Thread Sanitizer to isolate the issue, then refactored to use a dedicated serial actor, eliminating the data race entirely.',
              responseLatencyMs: 1450,
              wasPreComputed: false,
              sequenceOrder: 2,
            },
          ],
        },
      },
    });
    console.log('Sample interview session created with 3 exchanges');
  }

  console.log('\nSeed complete!');
  console.log('─────────────────────────────────────');
  console.log(`Test account: ${testEmail}`);
  console.log(`Password:     ${testPassword}`);
  console.log('─────────────────────────────────────');
}

main()
  .catch((e) => {
    console.error('Seed error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
