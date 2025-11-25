# Отчёт о сборке и запуске `minio` (инфраструктурный компонент)

**Дата:** 2025-11-25

## Краткое резюме
- MinIO используется как S3-совместимое хранилище. Обычно разворачивается из официального образа `minio/minio` и не требует сборки из исходников.

## Команды для воспроизведения (prod)

1) Поднять MinIO через docker compose (пример):

```bash
# выставьте переменные окружения для учетных данных
export MINIO_ROOT_USER=minio
export MINIO_ROOT_PASSWORD=minio123

docker compose up -d minio
```

2) Проверка работоспособности:

```bash
docker compose logs --tail 200 minio
curl -fsS http://localhost:9000/minio/health/live
```

## Особенности prod-развёртывания
- Рекомендуется подключать MinIO к отдельному volume для постоянного хранения данных.
- Настройте TLS/Reverse proxy (traefik) для публичного доступа или оставьте внутренним компонентом в `quark-network`.
- Укажите политики CORS и lifecycle по необходимости.

## Логи и артефакты
- MinIO хранит данные в volume, проверьте `docker volume ls` и `docker inspect <volume>`.

---

**Статус:** MinIO — инфраструктурный сервис, обычно разворачивается из официального образа; отдельной сборки не требуется.

**Текущий статус (25.11.2025):** `quark-minio` — Running (healthy).

Проверка: `curl -fsS http://localhost:9000/minio/health/live` должен вернуть живой статус.
