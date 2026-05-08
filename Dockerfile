FROM node:22-alpine AS builder

WORKDIR /app

COPY backend/package.json backend/package-lock.json* ./
COPY backend/prisma ./prisma
RUN npm ci && npx prisma generate

COPY backend/tsconfig.json ./
COPY backend/src ./src
RUN npx tsc

FROM node:22-alpine AS runner

# Healthcheck needs wget; alpine ships busybox wget already, so no apk add.
# Run as a non-root user so a runtime RCE can't pivot to root inside the
# container. UID/GID 10001 is high enough to dodge collisions with most
# host-mounted volumes.
RUN addgroup -S -g 10001 app && adduser -S -u 10001 -G app app

WORKDIR /app

COPY --from=builder --chown=app:app /app/node_modules ./node_modules
COPY --from=builder --chown=app:app /app/dist ./dist
COPY --from=builder --chown=app:app /app/prisma ./prisma
COPY --from=builder --chown=app:app /app/package.json ./

COPY --chown=app:app backend/certs ./certs
COPY --chown=app:app backend/docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

USER app

EXPOSE 3000

# Railway probes /health every 30s; matching here gives `docker run` parity
# locally and lets orchestrators that respect HEALTHCHECK (e.g. compose)
# restart the container without external probes.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget --quiet --tries=1 --spider "http://localhost:${PORT:-3000}/health" || exit 1

ENTRYPOINT ["./docker-entrypoint.sh"]
