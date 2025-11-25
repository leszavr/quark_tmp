# Отчёт о разворачивании `infra/verdaccio`

**Дата:** 2025-11-25

## Краткое резюме
- `infra/verdaccio` предоставляет локальный npm registry, используется для прогрева кэша и ускорения pnpm install при сборках.

## Быстрый запуск

```bash
docker compose up -d verdaccio
docker compose logs --tail 200 verdaccio
curl -fsS http://localhost:4873/ || echo "verdaccio unreachable"
```

## Текущий статус (25.11.2025)
- `quark-verdaccio` — Running.

## Рекомендации
- Прогрейте кеш перед массовыми сборками: `pnpm install` в пустом временном проекте с `npm_config_registry=http://localhost:4873`.
