#!/usr/bin/env bash
# Smoke test: build Docker image and verify health + frontend.
set -euo pipefail

IMAGE=finally
CONTAINER=finally-test
DB_DIR=/tmp/finally-test-db
PORT=8000

cleanup() {
    docker rm -f "$CONTAINER" 2>/dev/null || true
}
trap cleanup EXIT

echo "==> Building Docker image..."
docker build -t "$IMAGE" .

echo "==> Starting container..."
mkdir -p "$DB_DIR"
docker run -d --name "$CONTAINER" \
    -p "${PORT}:8000" \
    -v "${DB_DIR}:/app/db" \
    -e LLM_MOCK=true \
    -e OPENROUTER_API_KEY=test \
    "$IMAGE"

echo "==> Waiting for health endpoint..."
for i in $(seq 1 30); do
    status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/api/health" 2>/dev/null || true)
    if [ "$status" = "200" ]; then
        echo "    Health OK (attempt $i)"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "ERROR: health endpoint did not respond after 30 attempts"
        docker logs "$CONTAINER"
        exit 1
    fi
    sleep 1
done

health=$(curl -s "http://localhost:${PORT}/api/health")
if [ "$health" != '{"status":"ok"}' ]; then
    echo "ERROR: unexpected health response: $health"
    exit 1
fi
echo "    Health response: $health"

echo "==> Verifying frontend HTML..."
content_type=$(curl -s -o /dev/null -w "%{content_type}" "http://localhost:${PORT}/")
if [[ "$content_type" != text/html* ]]; then
    echo "ERROR: / returned content-type: $content_type (expected text/html)"
    exit 1
fi
echo "    Content-Type: $content_type"

echo "==> Checking container logs for errors..."
if docker logs "$CONTAINER" 2>&1 | grep -iE "^(ERROR|CRITICAL|Traceback)" | grep -v "HTTP"; then
    echo "ERROR: found errors in container logs"
    exit 1
fi

echo "==> All smoke tests passed."
