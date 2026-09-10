#!/bin/sh
# vim:sw=2:ts=2:et
#
# 10-check-log-symlinks.sh  --  docker-openresty
#
# Warns when access.log or error.log in the image's log directory is not
# a symlink.  The image ships them as symlinks to /dev/stdout and /dev/stderr
# so that logs reach `docker logs`; the most common way they stop being
# symlinks is a volume bind-mounted over the logs directory, which silently
# redirects logging into regular files inside the mount.
#
# The log directory is taken from RESTY_LOG_DIR, defaulting to
# /usr/local/openresty/nginx/logs; flavored images (debug/valgrind) set
# RESTY_LOG_DIR to their flavor-specific prefix in their Dockerfiles.
#
# Warnings are written to stderr and can be suppressed by setting
# NGINX_ENTRYPOINT_QUIET_LOGS, e.g. if logging to files is intentional.
#
# See https://github.com/openresty/docker-openresty/issues/91
# and https://github.com/openresty/docker-openresty/blob/master/README.md#docker-entrypoint
#

set -e

ME=$(basename "$0")
LOG_DIR="${RESTY_LOG_DIR:-/usr/local/openresty/nginx/logs}"

entrypoint_warn() {
  if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
    echo "$@" >&2
  fi
}

warned=""

check_log_symlink() {
  path="$LOG_DIR/$1"
  if [ ! -L "$path" ]; then
    entrypoint_warn "$ME: WARNING: $path is not a symlink to /dev/$2; nginx will write these logs to a file, and they will NOT appear in 'docker logs'"
    warned=1
  fi
}

check_log_symlink access.log stdout
check_log_symlink error.log stderr

if [ -n "$warned" ]; then
  entrypoint_warn "$ME: WARNING: this usually means a volume is bind-mounted over $LOG_DIR, shadowing the image's symlinks.  If logging to files is intended, silence this warning with NGINX_ENTRYPOINT_QUIET_LOGS=1.  See https://github.com/openresty/docker-openresty/issues/91"
fi
