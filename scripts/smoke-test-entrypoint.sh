#!/bin/bash
# Exercises the derived layer without publishing or changing the base image.
# Usage: bash scripts/smoke-test-entrypoint.sh IMAGE
# SMOKE_PLATFORM defaults to linux/amd64; CI supplies each matrix platform.
# SMOKE_RETRIES is the readiness budget shared with smoke-test-nonroot.sh
# (default 120; emulated platforms start slowly). SMOKE_TIMEOUT bounds each
# foreground docker run in seconds (default 600) when a timeout command exists,
# so a hung emulated invocation fails fast instead of consuming the whole job.
set -euo pipefail

IMAGE="${1:?Usage: smoke-test-entrypoint.sh IMAGE}"
PLATFORM="${SMOKE_PLATFORM:-linux/amd64}"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEST_DIR"' EXIT
NAME="entrypoint-smoke-${TEST_DIR##*.}-$$"
export SMOKE_RETRIES="${SMOKE_RETRIES:-120}"
RUN=(docker run --rm --platform "$PLATFORM" --network none)
if command -v timeout >/dev/null 2>&1; then
    RUN=(timeout "${SMOKE_TIMEOUT:-600}" "${RUN[@]}")
fi
# Negative checks must fail for the expected reason, never by timing out (124).
expect_failure() {
    local status=0
    result=$("${RUN[@]}" "$@" 2>&1) || status=$?
    [[ $status -ne 0 && $status -ne 124 ]]
}
SERVER_COMMAND=()
COMMAND=$("${RUN[@]}" "$IMAGE" printenv RESTY_ENTRYPOINT_COMMAND)
if [[ "$COMMAND" == openresty-valgrind ]]; then
    # This diagnostic build uses LuaJIT's system allocator and must be exercised
    # under Valgrind on ARM64. Run hooks/config validation before instrumentation.
    SERVER_COMMAND=(sh -ec '/docker-entrypoint.sh -t; export TMPDIR=/var/run/openresty; exec valgrind --quiet --tool=memcheck openresty-valgrind -g "daemon off; master_process off;"')
fi

bash "$SCRIPT_DIR/smoke-test-nonroot.sh" "$NAME" 0 "$IMAGE" --cap-drop=ALL --security-opt no-new-privileges=true -- ${SERVER_COMMAND[@]+"${SERVER_COMMAND[@]}"}
bash "$SCRIPT_DIR/smoke-test-nonroot.sh" "$NAME-ro" 0 "$IMAGE" \
    --cap-drop=ALL --security-opt no-new-privileges=true --read-only \
    --tmpfs /var/run/openresty:rw,noexec,nosuid,nodev,size=64m,mode=0700,uid=12345,gid=12345 \
    -- ${SERVER_COMMAND[@]+"${SERVER_COMMAND[@]}"}

# Flags select the correct server binary even for debug and Valgrind flavors.
"${RUN[@]}" "$IMAGE" -v

LOG_DIR=$("${RUN[@]}" "$IMAGE" printenv RESTY_LOG_DIR)
mkdir "$TEST_DIR/logs"
result=$("${RUN[@]}" -v "$TEST_DIR/logs:$LOG_DIR" "$IMAGE" -v 2>&1)
[[ "$result" == *'WARNING:'* && "$result" == *'not a symlink'* ]]
result=$("${RUN[@]}" -e NGINX_ENTRYPOINT_QUIET_LOGS=1 \
    -v "$TEST_DIR/logs:$LOG_DIR" "$IMAGE" -v 2>&1)
[[ "$result" != *'WARNING:'* ]]

# A sourced hook must affect the final exec, including through a symlink.
cat > "$TEST_DIR/export.envsh" <<'EOF'
export ENTRYPOINT_TEST_EXPORT=exported
EOF
cat > "$TEST_DIR/openresty" <<'EOF'
#!/bin/sh
printf '%s\n' "${ENTRYPOINT_TEST_EXPORT:-missing}"
EOF
cat > "$TEST_DIR/fail.sh" <<'EOF'
#!/bin/sh
exit 17
EOF
chmod 755 "$TEST_DIR/export.envsh" "$TEST_DIR/openresty" "$TEST_DIR/fail.sh"
mkdir "$TEST_DIR/hooks"
ln -s /probe/export.envsh "$TEST_DIR/hooks/40-export.envsh"
result=$("${RUN[@]}" -e NGINX_ENTRYPOINT_QUIET_LOGS=1 \
    -v "$TEST_DIR:/probe:ro" \
    -v "$TEST_DIR/hooks:/docker-entrypoint.d:ro" \
    "$IMAGE" /probe/openresty)
[[ "$result" == exported ]]

# Other commands bypass startup hooks; a server command propagates failures.
result=$("${RUN[@]}" -v "$TEST_DIR/fail.sh:/docker-entrypoint.d/99-fail.sh:ro" \
    "$IMAGE" sh -c 'echo bypassed')
[[ "$result" == bypassed ]]
expect_failure -v "$TEST_DIR/fail.sh:/docker-entrypoint.d/99-fail.sh:ro" "$IMAGE" -t || {
    echo "Failing startup hook did not stop startup: $result" >&2
    exit 1
}

mkdir "$TEST_DIR/templates"
cat > "$TEST_DIR/templates/default.conf.template" <<'EOF'
server {
    listen 8080;
    location / { return 200 "${ENTRYPOINT_TEST_VALUE}:$request_uri"; }
}
EOF
cat > "$TEST_DIR/templates/tcp.conf.stream-template" <<'EOF'
server {
    listen 18081;
    proxy_pass 127.0.0.1:${ENTRYPOINT_TEST_PORT};
}
EOF
"${RUN[@]}" -e ENTRYPOINT_TEST_VALUE=rendered -e ENTRYPOINT_TEST_PORT=9 \
    -e 'NGINX_ENVSUBST_FILTER=^ENTRYPOINT_TEST_' \
    -v "$TEST_DIR/templates:/etc/nginx/templates:ro" "$IMAGE" sh -ec '
    /docker-entrypoint.sh -t
    grep -F '\''rendered:$request_uri'\'' /etc/nginx/conf.d/default.conf
    grep -F "proxy_pass 127.0.0.1:9;" /etc/nginx/stream-conf.d/tcp.conf
    grep -F "include /etc/nginx/stream-conf.d/*.conf;" /etc/nginx/conf.d/stream.main
    '

# Existing stream configuration must survive, with an explicit startup failure.
printf '%s\n' '# sentinel' > "$TEST_DIR/stream.main"
expect_failure -e ENTRYPOINT_TEST_VALUE=rendered -e ENTRYPOINT_TEST_PORT=9 \
    -v "$TEST_DIR/templates:/etc/nginx/templates:ro" \
    -v "$TEST_DIR/stream.main:/etc/nginx/conf.d/stream.main:ro" "$IMAGE" -t || {
    echo "Existing stream.main was not rejected: $result" >&2
    exit 1
}
[[ "$result" == *'refusing to overwrite'* ]]
[[ $(< "$TEST_DIR/stream.main") == '# sentinel' ]]

# Templates on an unwritable rootfs must fail rather than serve stale config.
expect_failure --user 12345:12345 --read-only \
    -v "$TEST_DIR/templates:/etc/nginx/templates:ro" "$IMAGE" -t || {
    echo "Unwritable template destination was not rejected: $result" >&2
    exit 1
}
[[ "$result" == *'not writable'* ]]
echo "Entrypoint checks passed: $IMAGE ($PLATFORM)"
