# Отчёт о сборке `auth-ui-integration`

**Дата:** 2025-11-25

## Описание
- `auth-ui-integration` содержит тесты/интеграционные скрипты для интеграции UI и auth-service. В прод-сборке отдельного docker-образа обычно не требуется.

## Запуск тестов

```bash
cd /home/odmen/quark/services/auth-ui-integration
pnpm install
pnpm test
```

## Текущий статус
- Нет отдельного прод-образа. Для интеграционных тестов используйте `docker compose` со всеми зависимостями.
