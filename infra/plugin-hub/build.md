# Отчёт и воспроизводимая инструкция по сборке и запуску `quark-plugin-hub`

Этот документ содержит команды и порядок действий, чтобы воспроизвести локальную сборку образа `quark-plugin-hub` и старт сервиса на другой машине.

Предусловия
- Docker (с BuildKit) и `docker compose` v2 установленны.
- pnpm workspace файлы находятся в корне репозитория (`pnpm-workspace.yaml`, `pnpm-lock.yaml`).
- Рекомендуется запустить локальный Verdaccio (см. шаг 1) для ускорения сборки и надёжности.

Краткая команда сборки

```bash
cd /path/to/quark
export DOCKER_BUILDKIT=1
docker build -f infra/plugin-hub/Dockerfile -t quark-plugin-hub .
```

Полная воспроизводимая последовательность (рекомендуемая)

1) Запустить Verdaccio (локальный npm registry)

```bash
# запускает verdaccio из docker-compose
docker compose up -d verdaccio

# проверить доступность
curl -fsS http://localhost:4873/ || echo "verdaccio unreachable"
```

2) Прогрев кэша Verdaccio (рекомендуется)

Прогрев кэша означает выполнить одиночный `pnpm install` в чистом окружении либо сделать быстрый `pnpm fetch` в пустой директории для загрузки зависимостей в Verdaccio uplink.

```bash
# пример быстрого fetch
mkdir -p /tmp/quark-fetch && cd /tmp/quark-fetch
cat > package.json <<'JSON'
{ "name": "quark-cache-warm", "version": "0.0.0", "dependencies": { "left-pad": "1.3.0" } }
JSON
npm_config_registry=http://localhost:4873 pnpm install
```

3) Поднять core infra (Vault, Postgres, Redis, NATS)

```bash
docker compose up -d vault postgres redis nats

# подождать здоровья
docker ps --filter "name=quark-postgres" --format "{{.Names}} {{.Status}}"
docker ps --filter "name=quark-redis" --format "{{.Names}} {{.Status}}"
```

4) Собрать образ `quark-plugin-hub`

```bash
cd /path/to/quark
export DOCKER_BUILDKIT=1
docker build -f infra/plugin-hub/Dockerfile -t quark-plugin-hub .
```

5) Локальная проверка через `-test` контейнер (smoke test)

Я рекомендую использовать `docker compose` для запуска сервиса, чтобы контейнер получил правильные сетевые алиасы и `depends_on`.

Вариант A — быстрый тест через наш helper (использует обычный `docker run`):

```bash
./scripts/test-then-prod.sh quark-plugin-hub 15
```

Вариант B — тест через `docker compose` (рекомендую для точной репликации окружения):

```bash
# запустить сервис через compose, чтобы получить алиас 'redis'
docker compose up -d plugin-hub
docker compose logs --tail 200 plugin-hub
```

Проверки после запуска

- Логи: `docker compose logs --tail 200 plugin-hub` должны содержать строки:
  - `✅ Connected to Redis`
  - `✅ Connected to NATS`
  - `PluginHub started with full functionality!`

- Health endpoint: `curl -fsS http://localhost:3000/health`

Траблшутинг (частые ошибки и решения)

- Скорее всегоая проблема: `getaddrinfo EAI_AGAIN redis` или `Cannot connect to redis`.
  - Причина: контейнер не резолвит хост `redis` (запуск через `docker run` без правильной сети/алиасов).
  - Быстрое решение: запускать через `docker compose up plugin-hub` или стартовать контейнер с `--network quark-network --network-alias redis`.
    ```bash
    docker run --name quark-plugin-hub -d --network quark-network --network-alias redis -p 3000:3000 quark-plugin-hub
    ```

- Если в логах есть `Ignored build scripts: esbuild`:
  - Убедитесь, что все build-скрипты были выполнены в builder stage и артефакты (`dist`) корректно скопированы в production stage.
  - При необходимости добавить `pnpm approve-builds` в builder stage или явно запускать `pnpm run build` в builder.

- Проблемы с pnpm lockfile (ERR_PNPM_OUTDATED_LOCKFILE):
  - Решение: выполнять `pnpm install` на уровне workspace в builder (как в Dockerfile), либо в production stage использовать `pnpm install --prod --no-frozen-lockfile` если lockfile несовместим.

Дополнительные советы для CI / другой машины

- Убедитесь, что `pnpm-workspace.yaml` и `pnpm-lock.yaml` копируются в контекст сборки (Dockerfile настроен корректно).
- В CI рекомендуется предварительно поднять Verdaccio (или настроить CI так, чтобы registry был доступен) для стабильных и быстрых сборок.
- Добавьте в CI шаги: `docker compose up -d verdaccio` → прогрев кеша → `docker compose up -d vault postgres redis nats` → `docker compose build plugin-hub` → `docker compose up -d plugin-hub`.

Контакты/логи
- Локальные логи сборки сохраняются в терминале; для подробной отладки можно сохранить вывод сборки в файл:
  ```bash
  DOCKER_BUILDKIT=1 docker build -f infra/plugin-hub/Dockerfile -t quark-plugin-hub . 2>&1 | tee /tmp/quark-plugin-hub-build.log
  ```

Файлы, задействованные в сборке
- `infra/plugin-hub/Dockerfile`
- `infra/plugin-hub/src/` -> билдер -> `dist`
- `infra/plugin-hub/package.json` (и root `pnpm-workspace.yaml`, `pnpm-lock.yaml`)

Авторы и дата
- Сборка и верификация: Development Team (самописный отчет)
- Дата: 2025-11-21
