# Отчёт о сборке и запуске `quark-auth`

**Дата:** 2025-11-25

## Краткое резюме
- Сборка `auth-service` выполнена локально через `docker compose build auth-service` и завершилась успешно.
- Образ: `quark-auth-service` (локальный тег), артефакты `dist/` сгенерированы в builder stage.

## Команды для воспроизведения

1) Запустить зависимости (в сети `quark-network`):

```bash
docker compose up -d verdaccio vault postgres redis nats
```

2) Убедиться, что зависимости готовы (health):

```bash
docker ps --filter "name=quark-postgres" --format "{{.Names}} {{.Status}}"
docker ps --filter "name=quark-redis" --format "{{.Names}} {{.Status}}"
docker ps --filter "name=quark-vault" --format "{{.Names}} {{.Status}}"
```

3) Построить образ (рекомендуемый способ — через `docker compose`):

```bash
cd /path/to/quark
export DOCKER_BUILDKIT=1
docker compose build auth-service --pull --no-cache 2>&1 | tee /tmp/quark-auth-build.log
```

4) Быстрая проверка (через `docker compose`):

```bash
docker compose up -d auth-service
docker compose logs --tail 200 auth-service
```

## Наблюдения и предупреждения

- Во время `pnpm install` в builder stage появились предупреждения:
	- `Ignored build scripts: @nestjs/core, esbuild. Run "pnpm approve-builds" ...`
	- Это нормально для CI-процесса, если все требуемые артефакты генерируются в builder stage. В противном случае в builder stage нужно явно запускать `pnpm approve-builds` или `pnpm run build`.
- В логах сборки видно успешный `pnpm install` и `pnpm run build` → `dist` собран.
- Рекомендуется запускать сборку из корня репозитория и использовать `docker compose build` (позволяет корректно передавать network и build args). При необходимости можно передать `--network host` в `docker build` чтобы видеть локальный Verdaccio.

## Проверка работоспособности

- После запуска `auth-service` через `docker compose up -d auth-service` сервис должен стать `healthy` (если настроен healthcheck). Проверить:

```bash
docker compose ps auth-service
docker compose logs --tail 100 auth-service
curl -fsS http://localhost:3001/auth/health
```

## Логи и артефакты
- Build log: `/tmp/quark-auth-build.log` (если использовали `tee`).
- Сборочные артефакты находятся в image layer (скопированы в `/app/services/auth-service/dist` во втором слое).

## Рекомендации
- Для CI: поднять Verdaccio перед сборкой, прогреть кеш и затем запускать `docker compose build auth-service`.
- При возникающих ошибках pnpm (timeout к verdaccio) — проверьте доступность verdaccio и повторите прогрев.


---

**Текущий статус (25.11.2025):** `quark-auth` — Running (healthy).

Примечания:
- Сборка и запуск проверены локально. Сборка происходила с использованием BuildKit и pnpm workspace.
- Для корректной сборки требуется доступ к локальному `verdaccio` (рекомендуется поднять до сборки).

Время сборки (локально): ~1m 36s (см. `/tmp/quark-auth-build.log` при использовании `tee`).
