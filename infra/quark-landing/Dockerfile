# Dockerfile для Quark Landing - собирается из pnpm workspace (аналогично blog-service)
# Не используется! Landing собирается через корневой workspace context
# ВАЖНО: Build context должен быть корнем репозитория!
# docker build -f infra/quark-landing/Dockerfile -t quark-landing .

FROM node:22-alpine AS builder
ARG NPM_REGISTRY=https://registry.npmjs.org
ENV NPM_CONFIG_REGISTRY=${NPM_REGISTRY}

WORKDIR /workspace

# Use corepack to provide pnpm (avoids installing pnpm via npm)
RUN corepack enable && corepack prepare pnpm@latest --activate

# Копируем workspace конфигурацию
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml .npmrc* ./

# Копируем package.json всех сервисов для workspace
COPY infra/quark-landing/package.json ./infra/quark-landing/

# Устанавливаем зависимости workspace
RUN pnpm install --no-frozen-lockfile || pnpm install

# Копируем исходники landing
COPY infra/quark-landing ./infra/quark-landing

# Собираем landing
WORKDIR /workspace/infra/quark-landing
RUN pnpm build

# Production stage
FROM node:22-alpine AS runner
ARG NPM_REGISTRY=https://registry.npmjs.org
ENV NPM_CONFIG_REGISTRY=${NPM_REGISTRY}

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder /workspace/infra/quark-landing/public ./public

RUN mkdir .next && chown nextjs:nodejs .next

# Next.js standalone создаёт структуру workspace, копируем всё
COPY --from=builder --chown=nextjs:nodejs /workspace/infra/quark-landing/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /workspace/infra/quark-landing/.next/static ./infra/quark-landing/.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# server.js находится в infra/quark-landing/ из-за monorepo структуры
CMD ["node", "infra/quark-landing/server.js"]