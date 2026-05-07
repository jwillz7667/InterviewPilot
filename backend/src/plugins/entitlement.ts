import { FastifyInstance, FastifyRequest } from 'fastify';
import fp from 'fastify-plugin';
import { InterviewQuality, SubscriptionTier } from '@prisma/client';
import {
  authorizeAiCall,
  getBillingSummary,
  getSessionAccessGrant,
  type BillingSummary,
} from '../modules/billing/billing.service.js';
import {
  type FeatureKey,
  type ModelChoice,
  type QuestionRouting,
  selectModel,
} from '../modules/billing/billing.constants.js';
import { PaymentRequiredError, UnauthorizedError } from '../utils/errors.js';

declare module 'fastify' {
  interface FastifyRequest {
    /**
     * Server-authoritative entitlement check for AI calls. Verifies that the user owns the
     * supplied access grant and returns the model the server has authorised for this call.
     * Throws 402 if the user lacks billing context, or 403 if the grant belongs to someone else.
     */
    requireGrantedAiCall: (
      sessionClientId: string,
      routing?: QuestionRouting
    ) => Promise<{ model: ModelChoice; quality: InterviewQuality; tier: SubscriptionTier }>;

    /**
     * Resolve a model selection by quality alone (no grant lookup). Useful for endpoints that
     * have already verified ownership through another channel (e.g. realtime session bootstrap).
     */
    resolveAiModel: (
      quality: InterviewQuality,
      routing?: QuestionRouting
    ) => ModelChoice;

    /**
     * Verifies that the caller's tier grants the requested feature flag. Returns the cached
     * billing summary on success; throws 402 with `requiredFeature` in `details` on miss.
     */
    requireFeature: (feature: FeatureKey) => Promise<BillingSummary>;

    /**
     * Quick readonly accessor for the caller's current billing summary (cached for 30s).
     */
    billingSummary: () => Promise<BillingSummary>;
  }
}

async function entitlementPlugin(app: FastifyInstance) {
  app.decorateRequest('requireGrantedAiCall', async function (
    this: FastifyRequest,
    sessionClientId: string,
    routing: QuestionRouting = 'default'
  ) {
    const userId = this.user?.sub;
    if (!userId) {
      throw new UnauthorizedError('Authenticated session required');
    }
    return authorizeAiCall(userId, sessionClientId, routing);
  });

  app.decorateRequest('resolveAiModel', function (
    this: FastifyRequest,
    quality: InterviewQuality,
    routing: QuestionRouting = 'default'
  ) {
    return selectModel(quality, routing);
  });

  app.decorateRequest('requireFeature', async function (
    this: FastifyRequest,
    feature: FeatureKey
  ) {
    const userId = this.user?.sub;
    if (!userId) {
      throw new UnauthorizedError('Authenticated session required');
    }
    const summary = await getBillingSummary(userId);
    if (!summary.featureFlags[feature]) {
      throw new PaymentRequiredError(`This feature requires an upgrade.`, {
        requiredFeature: feature,
        currentTier: summary.tier,
      });
    }
    return summary;
  });

  app.decorateRequest('billingSummary', async function (this: FastifyRequest) {
    const userId = this.user?.sub;
    if (!userId) {
      throw new UnauthorizedError('Authenticated session required');
    }
    return getBillingSummary(userId);
  });

  // Re-export for ergonomic usage in service callers.
  void getSessionAccessGrant;
}

export default fp(entitlementPlugin, {
  name: 'entitlement',
});
