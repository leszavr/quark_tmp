# production-ready multi-stage Dockerfile for quark-plugin-hub
# Build context: repository root — запускать сборку из корня проекта

FROM node:20-alpine AS base
WORKDIR /app
RUN npm install -g pnpm@latest

# --- Builder: install workspace deps and build target package ---
FROM base AS builder
WORKDIR /app
ARG NPM_REGISTRY=https://registry.npmjs.org
ENV NPM_CONFIG_REGISTRY=${NPM_REGISTRY}

# Копируем весь репозиторий в builder для корректной workspace-инсталляции
COPY . .

# Используем BuildKit cache для pnpm store
RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

# Собираем только пакет плагин-хаба (вызов tsc с абсолютным путём к tsconfig)
RUN pnpm exec tsc -p /app/infra/plugin-hub/tsconfig.json

# --- Production: минимальный runtime образ ---
FROM base AS production
WORKDIR /workspace/plugin-hub
ARG NPM_REGISTRY=https://registry.npmjs.org
ENV NPM_CONFIG_REGISTRY=${NPM_REGISTRY}

# Создаём непривилегированного пользователя
RUN addgroup -g 1001 -S nodejs && adduser -S quark -u 1001 || true

# Копируем скомпилированные артефакты
COPY --chown=quark:nodejs --from=builder /app/infra/plugin-hub/dist ./dist

# Копируем package.json пакета и workspace lockfiles, затем установим production зависимости
COPY --chown=quark:nodejs infra/plugin-hub/package.json ./

# Устанавливаем production зависимости для пакета (без frozen-lockfile,
# чтобы избежать несоответствия lockfile в monorepo). Это делает
# production-образ самодостаточным (дает корректные top-level symlink'и).
RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store \
    pnpm --dir . install --prod --no-frozen-lockfile

USER quark
EXPOSE 3000
ENV NODE_ENV=production

CMD ["node", "dist/index.js"]
