# Отчёт о сборке и запуске `quark-blog-service`

**Дата:** 2025-11-25

## Краткое резюме
- Сборка `blog-service` выполнена в multi-stage Dockerfile с использованием pnpm workspace.
- Для корректной работы в production-стадии пришлось скопировать `node_modules` из builder-а, чтобы избежать проблем с pnpm symlink'ами в monorepo (drizzle-zod и другие пакеты стали доступны).

## Команды для воспроизведения

1) Поднять зависимости в сети `quark-network`:

```bash
docker compose up -d verdaccio vault postgres redis nats
```

2) Сборка образа (рекомендуемый способ — через `docker compose`):

```bash
cd /home/odmen/quark
export DOCKER_BUILDKIT=1
docker compose build blog-service 2>&1 | tee /tmp/quark-blog-build.log
```

3) Запуск сервиса:

```bash
docker compose up -d blog-service
docker compose logs --tail 200 blog-service
curl -fsS http://localhost:3004/api/health
```

## Особенности сборки и прод-режима
- Builder stage делает `pnpm install --frozen-lockfile` на уровне workspace и выполняет `pnpm run build` внутри `services/blog-service`.
- В production-стадии Dockerfile копирует `node_modules` из builder, затем выполняет `pnpm install --prod --frozen-lockfile || true`. Это гарантирует наличие runtime-зависимостей даже если pnpm workspace резолвинг ведёт себя иначе при установке в production stage.
- Если хотите избежать копирования `node_modules`, можно экспериментировать с `pnpm install --filter ./services/blog-service... --prod` в production-стадии, но это требует тщательного тестирования.

## Проверки и наблюдения
- После внесения правки и пересборки `drizzle-zod` доступен в production-образе (`import('drizzle-zod')` проходит).
- Лог при старте показывает, что сервер запущен на порту 3004 и health эндпоинт отвечает 200.

## Логи и артефакты
- Build log: `/tmp/quark-blog-build.log`.
- Сборочный артефакт: `dist/` скопирован в production-образ и запускается `node dist/index.prod.js`.

## Рекомендации
- Для CI: прогреть кеш Verdaccio, затем запускать сборку с BuildKit.
- Для чистоты образа можно оптимизировать production-stage, но нужно проверить `pnpm --filter` в контексте workspace.

---

**Статус:** `quark-blog-service` успешно собран и запущен (health OK).

**Текущий статус (25.11.2025):** `quark-blog-service` — Running (healthy).

Дополнительно:
- В production-образе проверил импорт `drizzle-zod` — доступен.
- Логи старта: сервис отвечает на `/api/health` 200.
