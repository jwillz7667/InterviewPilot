import { createHash } from 'node:crypto';

import type { FastifyRequest, FastifyReply } from 'fastify';

import { getEnv } from '../../config/env.js';
import { AppError } from '../../utils/errors.js';
import { getLogger } from '../../utils/logger.js';

const logger = getLogger().child({ module: 'attest' });

import { verifyAssertion } from './attest.service.js';

const KEY_ID_HEADER = 'x-attest-key-id';
const ASSERTION_HEADER = 'x-attest-assertion';
const NONCE_HEADER = 'x-attest-nonce';

/**
 * Fastify preHandler hook that requires a valid App Attest assertion before
 * the route handler runs. Mounted only on routes that touch billing-quota
 * mutations or paid AI calls. The clientData the device signs is
 * `<method>|<path>|<nonce>|<sha256(body)>` so each request is uniquely bound.
 *
 * When APP_ATTEST_REQUIRED=false, missing/invalid headers log but pass — gives
 * us a release to roll the iOS side out before flipping enforcement.
 */
export async function appAttestHook(
  request: FastifyRequest,
  _reply: FastifyReply
): Promise<void> {
  const env = getEnv();
  const required = env.APP_ATTEST_REQUIRED;
  const userId = request.user?.sub;

  const keyId = request.headers[KEY_ID_HEADER];
  const assertion = request.headers[ASSERTION_HEADER];
  const nonce = request.headers[NONCE_HEADER];

  if (!userId) {
    // The route should already be authenticated; if it isn't, App Attest
    // can't bind the assertion to a user. Skip — auth middleware will reject.
    return;
  }

  if (typeof keyId !== 'string' || typeof assertion !== 'string' || typeof nonce !== 'string') {
    logger.warn({ userId, route: request.url }, 'attest.assertion.absent');
    if (required) {
      throw new AppError(401, 'App Attest assertion required', 'ATTEST_REQUIRED');
    }
    return;
  }

  const bodyHash = createHash('sha256')
    .update(request.body ? JSON.stringify(request.body) : '')
    .digest('hex');
  const clientData = Buffer.from(
    `${request.method}|${request.url}|${nonce}|${bodyHash}`,
    'utf8'
  );

  try {
    await verifyAssertion({
      userId,
      keyId,
      assertionBase64: assertion,
      clientData,
    });
    logger.debug({ userId, keyId, route: request.url }, 'attest.assertion.verified');
  } catch (err) {
    logger.warn(
      { userId, keyId, route: request.url, err },
      'attest.assertion.failed'
    );
    if (required) {
      throw err;
    }
  }
}
