import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';

import { withDatabaseRetry } from '../../config/database.js';

import {
  appleLoginSchema,
  loginSchema,
  logoutSchema,
  refreshSchema,
  registerSchema,
} from './auth.schema.js';
import {
  authenticateWithApple,
  registerUser,
  loginUser,
  createRefreshToken,
  rotateRefreshToken,
  revokeRefreshToken,
} from './auth.service.js';

const ACCESS_TOKEN_TTL = '15m';

export function buildAuthHandlers(app: FastifyInstance) {
  function issueAccessToken(user: { id: string; email: string }) {
    return app.jwt.sign({ sub: user.id, email: user.email }, { expiresIn: ACCESS_TOKEN_TTL });
  }

  function userAgentOf(request: FastifyRequest): string | undefined {
    const ua = request.headers['user-agent'];
    if (!ua) return undefined;
    if (Array.isArray(ua)) return ua[0]?.slice(0, 255);
    return ua.slice(0, 255);
  }

  async function register(request: FastifyRequest, reply: FastifyReply) {
    const input = registerSchema.parse(request.body);
    const user = await registerUser(input);

    const accessToken = issueAccessToken(user);
    const refreshToken = await createRefreshToken(user.id, undefined, userAgentOf(request));

    reply.status(201).send({
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        appAccountToken: user.appAccountToken,
      },
      accessToken,
      refreshToken,
    });
  }

  async function login(request: FastifyRequest, reply: FastifyReply) {
    const input = loginSchema.parse(request.body);
    const user = await loginUser(input);

    const accessToken = issueAccessToken(user);
    const refreshToken = await createRefreshToken(user.id, input.deviceId, userAgentOf(request));

    reply.send({
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        appAccountToken: user.appAccountToken,
      },
      accessToken,
      refreshToken,
    });
  }

  async function apple(request: FastifyRequest, reply: FastifyReply) {
    const input = appleLoginSchema.parse(request.body);
    const user = await authenticateWithApple(input);
    const accessToken = issueAccessToken(user);
    const refreshToken = await createRefreshToken(user.id, undefined, userAgentOf(request));

    reply.send({
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        appAccountToken: user.appAccountToken,
      },
      accessToken,
      refreshToken,
    });
  }

  async function refresh(request: FastifyRequest, reply: FastifyReply) {
    const { refreshToken: oldToken } = refreshSchema.parse(request.body);
    const { userId, newToken } = await rotateRefreshToken(oldToken, userAgentOf(request));

    const user = await withDatabaseRetry((prisma) =>
      prisma.user.findUniqueOrThrow({
        where: { id: userId },
        select: { id: true, email: true },
      })
    );

    const accessToken = issueAccessToken(user);

    reply.send({ accessToken, refreshToken: newToken });
  }

  async function logout(request: FastifyRequest, reply: FastifyReply) {
    const { refreshToken } = logoutSchema.parse(request.body);
    await revokeRefreshToken(refreshToken);
    reply.send({ success: true });
  }

  return { register, login, apple, refresh, logout };
}
