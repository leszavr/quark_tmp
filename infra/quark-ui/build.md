# Отчёт о сборке и запуске `quark-ui` (Next.js)

**Дата:** 2025-11-25

## Краткое резюме
- `quark-ui` — Next.js 13 приложение, собирается в `.next` и запускается через `next start`.
- Для production-образа важно, чтобы `.next`, `public`, `package.json` и `node_modules` находились в одном и том же рабочем каталоге. Я скопировал `.next` в абсолютный путь `/app/infra/quark-ui` и заменил CMD на прямой запуск Next через `node node_modules/next/dist/bin/next start -p 3101`.

## Команды для воспроизведения

1) Поднять зависимости:

```bash
docker compose up -d verdaccio vault postgres redis nats
```

2) Сборка образа:

```bash
cd /home/odmen/quark
export DOCKER_BUILDKIT=1
docker compose build quark-ui 2>&1 | tee /tmp/quark-ui-build.log
```

3) Запуск сервиса:

```bash
docker compose up -d quark-ui
docker compose logs --tail 200 quark-ui
curl -fsS http://localhost:3101/_next/ | head -n 1
```

## Особенности сборки и прод-режима
- Builder stage выполняет `pnpm install --frozen-lockfile` и `pnpm run build` в `/app/infra/quark-ui`.
- Production-стадия копирует `.next` и `public` в `/app/infra/quark-ui` и делает `pnpm install --prod --frozen-lockfile` на уровне `/app`.
- Вместо `pnpm start` используется прямой запуск `next start` через node, чтобы избежать того, что `pnpm` может добавить неподдерживаемые флаги (в нашем окружении `pnpm` добавлял опции `--filter`/`--silent`, что ломало запуск).

## Проверки и наблюдения
- После пересборки `.next` явно присутствует в образе и Next стартует на `:3101`.
- Логи показывают: "ready started server on [::]:3101, url: http://localhost:3101".

## Логи и артефакты
- Build log: `/tmp/quark-ui-build.log`.
- Сборочный артефакт: `.next` скопирован в production-образ.

## Рекомендации
- Если хотите более «чистый» образ, можно сохранять node_modules только для runtime-пакетов или использовать `pnpm --filter` в production-stage, но проверяйте корректность резолвинга workspace-пакетов.

---

**Статус:** `quark-ui` успешно собран и запущен.

**Текущий статус (25.11.2025):** `quark-ui` — Running (healthy).

Примечание: для старта использован прямой `node node_modules/next/dist/bin/next start -p 3101`.
