# Отчёт о сборке и запуске `infra/monitoring`

**Дата:** 2025-11-25

## Краткое резюме
- `infra/monitoring` — простая панель (Node.js). Образ собирается из Dockerfile в папке `infra/monitoring`.

## Команды для воспроизведения

```bash
cd /home/odmen/quark
export DOCKER_BUILDKIT=1
docker build -f infra/monitoring/Dockerfile -t quark-monitoring . 2>&1 | tee /tmp/quark-monitoring-build.log
```

## Текущий статус (25.11.2025)
- `quark-monitoring` — Running (healthy).

## Рекомендации
- Убедитесь, что `plugin-hub` доступен (зависимость) при старте мониторинга.
