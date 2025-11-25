# Отчёт о сборке и запуске `infra/quark-landing`

**Дата:** 2025-11-25

## Краткое резюме
- `infra/quark-landing` содержит Dockerfile для сборки standalone Next.js landing. Образ собирается из корня репозитория и использует pnpm workspace.

## Команды для воспроизведения

```bash
cd /home/odmen/quark
export DOCKER_BUILDKIT=1
docker build -f infra/quark-landing/Dockerfile -t quark-quark-landing . 2>&1 | tee /tmp/quark-landing-build.log
```

## Особенности
- Production-стадия использует standalone build, копирует `.next/standalone` и статические файлы.
- В образе запускается `node infra/quark-landing/server.js` под пользователем `nextjs`.

## Текущий статус (25.11.2025)
- `quark-quark-landing` — Running (healthy).

## Рекомендации
- Сборку и запуск выполнять из корня репо.
- Убедитесь, что `pnpm-workspace.yaml` и `pnpm-lock.yaml` копируются в контекст сборки.
