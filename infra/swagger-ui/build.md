# Отчёт о сборке и запуске `infra/swagger-ui`

**Дата:** 2025-11-25

## Краткое резюме
- `infra/swagger-ui` — контейнер на базе официального `swagger-ui`, конфигурируется через `SWAGGER_JSON=/swagger.yaml` и `docker-compose` volume.

## Команды для воспроизведения

```bash
cd /home/odmen/quark
export DOCKER_BUILDKIT=1
docker compose build swagger-ui
docker compose up -d swagger-ui
```

## Текущий статус (25.11.2025)
- `quark-swagger-ui` — Running (port mapped `8081:8080`).

## Рекомендации
- Убедитесь, что `infra/swagger.yaml` корректен и доступен контейнеру через volume.
- Для интеграции с Traefik используйте метки в `docker-compose.yml`.
