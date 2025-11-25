#!/bin/bash
set -euo pipefail
export DOCKER_BUILDKIT=1

# Скрипт поднимает зависимости (через docker-compose), ждёт их готовности,
# собирает образ auth-service и запускает тестовый контейнер в сети quark-network.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Проверки наличия команд
if ! command -v docker &>/dev/null; then
  echo "Docker не найден в PATH" >&2
  exit 1
fi
if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
  echo "Docker Compose не найден (проверьте 'docker compose' или 'docker-compose')" >&2
  # не выходим — попробуем использовать 'docker compose' позже
fi

# Параметры (можно переопределить в окружении)
: "${POSTGRES_USER:=quark_user}"
: "${POSTGRES_PASSWORD:=quark_password}"
: "${VAULT_DEV_ROOT_TOKEN_ID:=myroot}"
: "${NPM_REGISTRY:=http://localhost:4873}"

# Жёстко зафиксированное имя сети (по docker-compose.yml)
NETWORK="quark-network"

COMPOSE_SERVICES=(postgres redis vault nats verdaccio)

echo "Использую сеть: $NETWORK"

# Поднимаем зависимости
echo "Поднимаю зависимости: ${COMPOSE_SERVICES[*]}"
docker compose up -d "${COMPOSE_SERVICES[@]}"

# Функция ожидания с таймаутом
wait_until() {
  local name="$1"; local check_cmd="$2"; local timeout=${3:-60}
  local start=$(date +%s)
  echo "Ожидаю $name (таймаут ${timeout}s)..."
  while true; do
    if eval "$check_cmd" &>/dev/null; then
      echo "$name доступен"
      return 0
    fi
    if (( $(date +%s) - start >= timeout )); then
      echo "Таймаут ожидания $name" >&2
      return 1
    fi
    sleep 2
  done
}

# Ожидания
wait_until "Postgres" "docker exec quark-postgres pg_isready -U ${POSTGRES_USER} >/dev/null 2>&1" 60 || true
wait_until "Redis" "docker exec quark-redis redis-cli ping | grep -q PONG" 60 || true
wait_until "Vault" "curl -s --fail http://127.0.0.1:8200/v1/sys/health >/dev/null 2>&1" 60 || true
wait_until "Verdaccio" "curl -s --fail ${NPM_REGISTRY} >/dev/null 2>&1" 60 || true
wait_until "NATS" "docker inspect -f '{{.State.Running}}' quark-nats | grep -q true" 30 || true

# Убедимся, что сеть существует
if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  echo "Сеть $NETWORK не найдена — создаю"
  docker network create "$NETWORK"
fi

# Собираем auth-service
echo "Собираю образ quark-auth..."
# Используем сеть хоста для сборки, чтобы контейнер сборки видел локальный Verdaccio (localhost:4873)
DOCKER_BUILDKIT=1 docker build --network host -f services/auth-service/Dockerfile -t quark-auth --build-arg NPM_REGISTRY=${NPM_REGISTRY} .

# Запускаем тестовый контейнер
docker rm -f quark-auth-test 2>/dev/null || true

echo "Запускаю контейнер quark-auth-test в сети $NETWORK"
docker run --name quark-auth-test -d --network "$NETWORK" -p 3001:3001 \
  -e NODE_ENV=development \
  -e PORT=3001 \
  -e DB_HOST=postgres \
  -e DB_PORT=5432 \
  -e DB_USER="${POSTGRES_USER}" \
  -e DB_PASSWORD="${POSTGRES_PASSWORD}" \
  -e DB_NAME=quark_auth \
  -e REDIS_URL="redis://redis:6379" \
  -e VAULT_URL="http://vault:8200" \
  -e VAULT_TOKEN="${VAULT_DEV_ROOT_TOKEN_ID}" \
  -e PLUGIN_HUB_URL="http://plugin-hub:3000" \
  -e SERVICE_URL="http://auth-service:3001" \
  -e CORS_ORIGIN='*' \
  -e NPM_REGISTRY="${NPM_REGISTRY}" \
  quark-auth || { echo "Не удалось запустить контейнер quark-auth-test" >&2; exit 0; }

sleep 2

echo
 docker ps -a --filter name=quark-auth-test --format 'Status: {{.Status}}\nImage: {{.Image}}\nNames: {{.Names}}'

echo
 docker logs --tail 200 quark-auth-test || true
