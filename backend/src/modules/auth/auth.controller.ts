import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { registerSchema, loginSchema, refreshSchema, logoutSchema } from './auth.schema.js';
import {
  registerUser,
  loginUser,
  createRefreshToken,
  rotateRefreshToken,
  revokeRefreshToken,
} from './auth.service.js';
import { getPrisma } from '../../config/database.js';

export function buildAuthHandlers(app: FastifyInstance) {
  async function register(request: FastifyRequest, reply: FastifyReply) {
    const input = registerSchema.parse(request.body);
    const user = await registerUser(input);

    const accessToken = app.jwt.sign(
      { sub: user.id, email: user.email },
      { expiresIn: '30d' }
    );
    const refreshToken = await createRefreshToken(user.id);

    reply.status(201).send({
      user: { id: user.id, email: user.email, displayName: user.displayName },
      accessToken,
      refreshToken,
    });
  }

  async function login(request: FastifyRequest, reply: FastifyReply) {
    const input = loginSchema.parse(request.body);
    const user = await loginUser(input);

    const accessToken = app.jwt.sign(
      { sub: user.id, email: user.email },
      { expiresIn: '30d' }
    );
    const refreshToken = await createRefreshToken(user.id, input.deviceId);

    reply.send({
      user: { id: user.id, email: user.email, displayName: user.displayName },
      accessToken,
      refreshToken,
    });
  }

  async function refresh(request: FastifyRequest, reply: FastifyReply) {
    const { refreshToken: oldToken } = refreshSchema.parse(request.body);
    const { userId, newToken } = await rotateRefreshToken(oldToken);

    const prisma = getPrisma();
    const user = await prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { id: true, email: true },
    });

    const accessToken = app.jwt.sign(
      { sub: user.id, email: user.email },
      { expiresIn: '30d' }
    );

    reply.send({ accessToken, refreshToken: newToken });
  }

  async function logout(request: FastifyRequest, reply: FastifyReply) {
    const { refreshToken } = logoutSchema.parse(request.body);
    await revokeRefreshToken(refreshToken);
    reply.send({ success: true });
  }

  return { register, login, refresh, logout };
}
