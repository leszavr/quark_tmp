# Отчёт о сборке и запуске `quark-landing`

**Дата:** 2025-11-25

## Краткое резюме
- `quark-landing` — статический/Next.js сайт (или похожая фронтенд-страница). Сборка проходила успешно и образ был создан (`quark-quark-landing`).

## Команды для воспроизведения

1) Поднять зависимости:

```bash
docker compose up -d verdaccio vault postgres redis nats
```

2) Сборка образа:

```bash
cd /home/odmen/quark
export DOCKER_BUILDKIT=1
docker compose build quark-landing 2>&1 | tee /tmp/quark-landing-build.log
```

3) Запуск и проверка:

```bash
docker compose up -d quark-landing
docker compose logs --tail 200 quark-landing
curl -fsS http://localhost:3200/ | head -n 1
```

## Особенности сборки
- Следует запускать сборку из корня монорепозитория, чтобы pnpm workspace корректно резолвил зависимости.
- В production-стадии важно убедиться, что собранные статические файлы скопированы в production-образ и служатся корректно (проверьте `public` / `out` / `.next` в зависимости от фреймворка).

## Логи и артефакты
- Build log: `/tmp/quark-landing-build.log`.

---

**Статус:** `quark-landing` собран и образ создан.

**Текущий статус (25.11.2025):** `quark-landing` — Running (healthy).

Проверка: `curl -fsS http://localhost:3200/` возвращает HTML-страницу главной.
