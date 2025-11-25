#!/usr/bin/env bash
set -euo pipefail

# Скрипт: test-then-prod.sh
# Паттерн: собрать/запустить контейнер с суффиксом -test для проверки, затем удалить его и запустить прод
# Usage: ./scripts/test-then-prod.sh <image-name-without-prefix> [--wait-seconds N]

IMAGE_BASE="$1"
WAIT_SECONDS=${2:-10}

TEST_NAME="${IMAGE_BASE}-test"
PROD_NAME="${IMAGE_BASE}"

echo "[test-then-prod] Running test container: $TEST_NAME"

# Remove any stale test container
if docker ps -a --format '{{.Names}}' | grep -q "^${TEST_NAME}$"; then
  echo "[test-then-prod] Removing stale container $TEST_NAME"
  docker rm -f "$TEST_NAME" >/dev/null || true
fi

# Run test container attached to quark-network
docker run --name "$TEST_NAME" -d --network quark-network "$PROD_NAME" || {
  echo "[test-then-prod] Failed to start test container using image $PROD_NAME" >&2
  exit 1
}

echo "[test-then-prod] Waiting ${WAIT_SECONDS}s for container to initialize..."
sleep "$WAIT_SECONDS"

echo "[test-then-prod] Collecting last 200 log lines from $TEST_NAME"
docker logs --tail 200 "$TEST_NAME" || true

echo "[test-then-prod] Stopping and removing test container $TEST_NAME"
docker rm -f "$TEST_NAME" || true

echo "[test-then-prod] Starting production container: $PROD_NAME"

# Remove existing prod container if present
if docker ps -a --format '{{.Names}}' | grep -q "^${PROD_NAME}$"; then
  echo "[test-then-prod] Removing existing prod container $PROD_NAME"
  docker rm -f "$PROD_NAME" || true
fi

docker run --name "$PROD_NAME" -d --network quark-network -p 3000:3000 "$PROD_NAME" || {
  echo "[test-then-prod] Failed to start production container $PROD_NAME" >&2
  exit 1
}

echo "[test-then-prod] Production container $PROD_NAME started"
