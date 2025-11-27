# syntax=docker/dockerfile:1.4
# Quark UI - Next.js 13 + React 18 + TypeScript
FROM node:20-alpine AS base
WORKDIR /app
# Use corepack to provide pnpm (avoids installing pnpm via npm)
RUN corepack enable && corepack prepare pnpm@latest --activate

# --- Builder stage ---
FROM base AS builder

# ВАЖНО: Build context должен быть корнем репозитория!
# docker build -f infra/quark-ui/Dockerfile -t quark-ui .

# Build argument для registry с fallback на npmjs.org
ARG NPM_REGISTRY=https://registry.npmjs.org
ENV NPM_CONFIG_REGISTRY=${NPM_REGISTRY}

# Копируем конфигурацию workspace
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json ./
COPY infra/quark-ui/package.json ./infra/quark-ui/

# BuildKit cache mount для pnpm store
RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

# Копируем исходники quark-ui
COPY infra/quark-ui ./infra/quark-ui

# Собираем Next.js приложение
WORKDIR /app/infra/quark-ui
RUN pnpm run build

# --- Production stage ---
FROM base AS production
WORKDIR /app/infra/quark-ui
# Build argument для registry (повторно объявляем для production stage)
# По умолчанию используем внутренний Verdaccio (переопределяемый при сборке)
ARG NPM_REGISTRY=http://verdaccio:4873
ENV NPM_CONFIG_REGISTRY=${NPM_REGISTRY}

# Копируем package.json
COPY --from=builder /app/infra/quark-ui/package.json ./

# Копируем workspace конфигурацию
COPY --from=builder /app/pnpm-workspace.yaml /app/
COPY --from=builder /app/pnpm-lock.yaml /app/
COPY --from=builder /app/package.json /app/

# Устанавливаем prod dependencies с кешированием
WORKDIR /app
RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store \
    pnpm install --prod --frozen-lockfile

# Копируем собранное Next.js приложение в абсолютный путь package
COPY --from=builder /app/infra/quark-ui/.next /app/infra/quark-ui/.next
COPY --from=builder /app/infra/quark-ui/public /app/infra/quark-ui/public

# Ensure runtime commands run in the package folder so `pnpm start` finds package.json
WORKDIR /app/infra/quark-ui

# Открываем порт
EXPOSE 3101

# Environment
ENV PORT=3101
ENV NODE_ENV=production

# Запускаем Next.js напрямую чтобы избежать добавления pnpm флагов (например --filter)
CMD ["node", "node_modules/next/dist/bin/next", "start", "-p", "3101"]
