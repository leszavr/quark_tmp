# syntax=docker/dockerfile:1.4
# Auth Service - NestJS + TypeORM + PostgreSQL
FROM node:20-alpine AS base
WORKDIR /app
# Use corepack to provide pnpm (avoids installing pnpm via npm)
RUN corepack enable && corepack prepare pnpm@latest --activate

# --- Builder stage ---
FROM base AS builder

# Build argument для registry с fallback на npmjs.org
ARG NPM_REGISTRY=https://registry.npmjs.org
ENV NPM_CONFIG_REGISTRY=${NPM_REGISTRY}

# ВАЖНО: Build context должен быть корнем репозитория!
# docker build -f services/auth-service/Dockerfile -t quark-auth-service .

# Копируем конфигурацию workspace
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json ./
COPY services/auth-service/package.json ./services/auth-service/

# BuildKit cache mount для pnpm store
RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store \
    pnpm install

# Копируем исходники auth-service
COPY services/auth-service ./services/auth-service

# Собираем приложение
WORKDIR /app/services/auth-service
RUN pnpm run build

# --- Production stage ---
FROM base AS production
WORKDIR /app/services/auth-service

# Build argument для registry (повторно объявляем для production stage)
ARG NPM_REGISTRY=https://registry.npmjs.org
ENV NPM_CONFIG_REGISTRY=${NPM_REGISTRY}

# Копируем package.json
COPY --from=builder /app/services/auth-service/package.json ./

# Копируем workspace конфигурацию для правильной установки зависимостей
COPY --from=builder /app/pnpm-workspace.yaml /app/
COPY --from=builder /app/pnpm-lock.yaml /app/
COPY --from=builder /app/package.json /app/

# Устанавливаем prod dependencies с кешированием
WORKDIR /app
RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store \
    pnpm install --prod

# Копируем собранное приложение
WORKDIR /app/services/auth-service
# Создаем пользователя для безопасности до копирования крупных артефактов
RUN addgroup -g 1001 -S nodejs && adduser -S quark -u 1001

# Копируем собранное приложение и устанавливаем правильного владельца без выполнения дорогостоящего chown -R
COPY --from=builder --chown=quark:nodejs /app/services/auth-service/dist ./dist

USER quark

# Открываем порт
EXPOSE 3001

# Environment
ENV NODE_ENV=production

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "const http = require('http'); http.get('http://localhost:3001/auth/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1); }).on('error', () => process.exit(1));"

# Запускаем приложение
CMD ["node", "dist/main.js"]
