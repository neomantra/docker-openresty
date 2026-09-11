#!/bin/bash
# Test the stock vhost, Lua execution, and actual access/error log delivery.
# Valgrind flavors are diagnostic builds and are run under instrumentation.
set -euo pipefail
IMAGE="${1:?Usage: smoke-test-image.sh IMAGE FLAVOR [standard|entrypoint]}"
FLAVOR="${2:?Missing flavor}"
KIND="${3:-standard}"
PLATFORM="${SMOKE_PLATFORM:-linux/amd64}"
RETRIES="${SMOKE_RETRIES:-120}"
ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
CID=""
cleanup() {
    if [[ -n "$CID" ]]; then
        docker logs "$CID" >&2 || true
        docker rm -f "$CID" >/dev/null || true
    fi
}
trap cleanup EXIT
case "$KIND" in
    standard)
        [[ $(docker image inspect -f '{{json .Config.Entrypoint}}' "$IMAGE") == null ]]
        ;;
    entrypoint)
        [[ $(docker image inspect -f '{{json .Config.Entrypoint}}' "$IMAGE") == '["/docker-entrypoint.sh"]' ]]
        ;;
    *) echo "Unknown image kind: $KIND" >&2; exit 1 ;;
esac
COMMAND=()
if [[ "$FLAVOR" == bookworm-valgrind* ]]; then
    COMMAND=(sh -ec 'if [ -x /docker-entrypoint.sh ]; then /docker-entrypoint.sh -t; fi; export TMPDIR=/var/run/openresty; exec valgrind --quiet --tool=memcheck openresty-valgrind -g "daemon off; master_process off;"')
fi
for mode in default lua; do
    port=80 path=/
    if [[ "$mode" == lua ]]; then port=8080; path=/smoke; fi
    CID=$(docker create --platform "$PLATFORM" -p "127.0.0.1::${port}" \
        "$IMAGE" ${COMMAND[@]+"${COMMAND[@]}"})
    if [[ "$mode" == lua ]]; then
        docker cp "$ROOT/tests/fixtures/smoke.conf" "$CID:/etc/nginx/conf.d/zz-smoke.conf"
    fi
    docker start "$CID" >/dev/null
    address=$(docker port "$CID" "$port/tcp")
    ready=false
    for ((attempt=0; attempt<RETRIES; attempt++)); do
        if response=$(curl --max-time 2 -fsS "http://127.0.0.1:${address##*:}$path"); then
            ready=true
            break
        fi
        [[ $(docker inspect -f '{{.State.Running}}' "$CID") == true ]] || break
        sleep 1
    done
    [[ "$ready" == true ]] || { echo "Startup failed: $IMAGE ($mode)" >&2; exit 1; }
    if [[ "$mode" == lua ]]; then
        [[ "$response" == openresty-smoke-lua:42 ]]
    fi
    # The log driver may deliver the response and log records asynchronously.
    logged=false
    for ((attempt=0; attempt<RETRIES; attempt++)); do
        logs=$(docker logs "$CID" 2>&1)
        if [[ "$logs" == *"GET $path HTTP/1.1"* ]] && \
            { [[ "$mode" == default ]] || [[ "$logs" == *openresty-smoke-error* ]]; }; then
            logged=true
            break
        fi
        sleep 1
    done
    [[ "$logged" == true ]] || { echo "Missing access/error logs: $IMAGE" >&2; exit 1; }
    docker rm -f "$CID" >/dev/null
    CID=""
done
echo "HTTP, Lua, and logging checks passed: $IMAGE ($PLATFORM, $KIND)"
