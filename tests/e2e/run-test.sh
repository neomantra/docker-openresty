#!/bin/bash
set -e

# Ensure registries are running
if ! docker ps | grep -q openresty-test-ghcr; then
    echo "Starting registries..."
    ./tests/e2e/start-registries.sh
fi

echo "Running E2E test with act..."
# We use --network host to allow the buildx container to reach localhost registries
# We specify the workflow file explicitly
act workflow_dispatch \
    -W tests/e2e/local-test.yml \
    --container-architecture linux/amd64 \
    --bind \
    --network host

echo "Test complete. Verifying images..."
for flavor in alpine-apk bookworm; do
    for suffix in "" -entrypoint; do
        docker pull --platform linux/amd64 "localhost:5001/neomantra/openresty:${flavor}-test${suffix}-amd64"
        docker pull --platform linux/amd64 "localhost:5002/openresty/openresty:${flavor}-test${suffix}-amd64"
    done
    base="localhost:5002/openresty/openresty:${flavor}-test-amd64"
    test "$(docker image inspect --format '{{json .Config.Entrypoint}}' "$base")" = null
    bash ./scripts/smoke-test-entrypoint.sh "localhost:5002/openresty/openresty:${flavor}-test-entrypoint-amd64"
done

echo "✅ verification successful!"
