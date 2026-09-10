#!/bin/sh
# vim:sw=4:ts=4:et
#
# docker-entrypoint.sh  --  docker-openresty
#
# Adapted from the official Nginx image's entrypoint:
#   https://github.com/nginx/docker-nginx/blob/master/entrypoint/docker-entrypoint.sh
#
# See https://github.com/openresty/docker-openresty/blob/master/README.md#docker-entrypoint
#

set -e

entrypoint_log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

# If the first argument is a flag (e.g. `docker run openresty/openresty:bookworm-entrypoint -g "daemon off; env FOO;"`),
# prepend the default OpenResty command so the flags are passed to it.
if [ "${1#-}" != "$1" ]; then
    set -- "${RESTY_ENTRYPOINT_COMMAND:-openresty}" "$@"
fi

case "$(basename "$1")" in
    openresty|openresty-debug|openresty-valgrind|nginx|nginx-debug)
        if [ -d /docker-entrypoint.d/ ]; then
            entrypoint_log "$0: /docker-entrypoint.d/ is not empty, will attempt to perform configuration"

            entrypoint_log "$0: Looking for shell scripts in /docker-entrypoint.d/"
            # Keep sourced .envsh exports in this shell for the final exec.
            # Use a separate descriptor so scripts retain the container's stdin.
            while IFS= read -r f <&3; do
                [ -n "$f" ] || continue
                case "$f" in
                    *.envsh)
                        if [ -x "$f" ]; then
                            entrypoint_log "$0: Sourcing $f";
                            # User-provided hooks are resolved at startup.
                            # shellcheck disable=SC1090
                            . "$f"
                        else
                            # warn on shell scripts without exec bit
                            entrypoint_log "$0: Ignoring $f, not executable";
                        fi
                        ;;
                    *.sh)
                        if [ -x "$f" ]; then
                            entrypoint_log "$0: Launching $f";
                            "$f"
                        else
                            # warn on shell scripts without exec bit
                            entrypoint_log "$0: Ignoring $f, not executable";
                        fi
                        ;;
                    *) entrypoint_log "$0: Ignoring $f";;
                esac
            done 3<<EOF
$(find /docker-entrypoint.d/ -follow -type f -print | sort -V)
EOF

            entrypoint_log "$0: Configuration complete; ready for start up"
        else
            entrypoint_log "$0: No files found in /docker-entrypoint.d/, skipping configuration"
        fi
        ;;
esac

exec "$@"
