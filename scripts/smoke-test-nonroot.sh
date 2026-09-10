#!/bin/bash
# Smoke-tests non-root startup of an image (#119, #125):
# runs it with an arbitrary UID and checks that it serves HTTP.
#
# Usage: ./smoke-test-nonroot.sh <container_name> <host_port> <image> [docker run flags...] [-- command...]
# Use host_port 0 to have Docker select a free localhost port.
# Example: ./smoke-test-nonroot.sh openresty-smoke 0 ghcr.io/openresty/openresty:bookworm-entrypoint \
#              --read-only --tmpfs /tmp --tmpfs /var/run/openresty
#
# env:
#   SMOKE_RETRIES: readiness attempts (default 30)
#   SMOKE_PLATFORM: image platform (default linux/amd64)

set -e

NAME="$1"
PORT="$2"
IMAGE="$3"
shift 3 2>/dev/null || {
    echo "Usage: $0 <container_name> <host_port> <image> [docker run flags...]"
    exit 1
}

RETRIES="${SMOKE_RETRIES:-30}"
PLATFORM="${SMOKE_PLATFORM:-linux/amd64}"

echo "Smoke-testing non-root startup: $IMAGE ($NAME)..."
DOCKER_FLAGS=()
while [[ $# -gt 0 && "$1" != -- ]]; do
    DOCKER_FLAGS+=("$1")
    shift
done
if [[ "${1:-}" == -- ]]; then shift; fi
CID=$(docker create --name "$NAME" --platform "$PLATFORM" \
    --user 12345:12345 -p "127.0.0.1:${PORT}:80" "${DOCKER_FLAGS[@]}" \
    "$IMAGE" "$@")
trap 'docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT
docker start "$CID" >/dev/null
if ! ADDRESS=$(docker port "$CID" 80/tcp); then
    docker logs "$CID" >&2 || true
    exit 1
fi
PORT="${ADDRESS##*:}"

ok=""
for _ in $(seq 1 "$RETRIES"); do
    curl --max-time 2 -fsS -o /dev/null "http://127.0.0.1:${PORT}/" && { ok=1; break; }
    [[ $(docker inspect -f '{{.State.Running}}' "$CID") == true ]] || break
    sleep 1
done

if [[ -z "$ok" ]]; then
    echo "❌ non-root smoke test failed for $IMAGE ($NAME); container logs:"
    docker logs "$CID" || true
    exit 1
fi

echo "✅ non-root smoke test passed for $IMAGE ($NAME)"
