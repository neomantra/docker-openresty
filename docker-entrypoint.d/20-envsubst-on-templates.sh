#!/bin/sh
# vim:sw=2:ts=2:et
#
# 20-envsubst-on-templates.sh  --  docker-openresty
#
# Adapted from the official Nginx image's template-processing script:
#   https://github.com/nginx/docker-nginx/blob/master/entrypoint/20-envsubst-on-templates.sh
#
# Renders `*.template` files from /etc/nginx/templates into /etc/nginx/conf.d
# using `envsubst`, substituting the environment variables referenced therein.
#
# Stream templates (`*.stream-template`) are rendered into /etc/nginx/stream-conf.d
# and a `stream` block including that directory is written to
# /etc/nginx/conf.d/stream.main, which the default nginx.conf includes
# via `include /etc/nginx/conf.d/*.main;`.
#
# See https://github.com/openresty/docker-openresty/blob/master/README.md#docker-entrypoint
#

set -e

ME=$(basename "$0")

entrypoint_log() {
  if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
    echo "$@"
  fi
}

add_stream_block() {
  mainfile="/etc/nginx/conf.d/stream.main"

  if grep -q -E "^[[:space:]]*stream[[:space:]]*\{" /etc/nginx/conf.d/*.main 2>/dev/null; then
    entrypoint_log "$ME: a stream block already exists in /etc/nginx/conf.d/*.main; include $stream_output_dir/*.conf there to enable stream templates"
  elif [ -e "$mainfile" ] || [ -L "$mainfile" ]; then
    entrypoint_log "$ME: ERROR: $mainfile already exists and does not contain a stream block; refusing to overwrite it"
    return 1
  else
    entrypoint_log "$ME: Writing $mainfile to include $stream_output_dir/*.conf"
    cat << END > "$mainfile"
# added by "$ME"
stream {
  include $stream_output_dir/*.conf;
}
END
  fi
}

auto_envsubst() {
  template_dir="${NGINX_ENVSUBST_TEMPLATE_DIR:-/etc/nginx/templates}"
  suffix="${NGINX_ENVSUBST_TEMPLATE_SUFFIX:-.template}"
  output_dir="${NGINX_ENVSUBST_OUTPUT_DIR:-/etc/nginx/conf.d}"
  stream_suffix="${NGINX_ENVSUBST_STREAM_TEMPLATE_SUFFIX:-.stream-template}"
  stream_output_dir="${NGINX_ENVSUBST_STREAM_OUTPUT_DIR:-/etc/nginx/stream-conf.d}"
  filter="${NGINX_ENVSUBST_FILTER:-}"
  [ -d "$template_dir" ] || return 0
  if ! command -v envsubst >/dev/null; then
    entrypoint_log "$ME: ERROR: $template_dir exists, but envsubst is not available"
    return 1
  fi
  if [ ! -w "$output_dir" ]; then
    entrypoint_log "$ME: ERROR: $template_dir exists, but $output_dir is not writable"
    return 1
  fi
  defined_envs=$(awk -v filter="$filter" 'END { for (name in ENVIRON) if (name ~ filter) printf "${%s} ", name }' < /dev/null)
  find "$template_dir" -follow -type f -name "*$suffix" -print | while read -r template; do
    relative_path="${template#"$template_dir/"}"
    output_path="$output_dir/${relative_path%"$suffix"}"
    subdir=$(dirname "$relative_path")
    # create a subdirectory where the template file exists
    mkdir -p "$output_dir/$subdir"
    entrypoint_log "$ME: Running envsubst on $template to $output_path"
    envsubst "$defined_envs" < "$template" > "$output_path"
  done

  # Print the first file with the stream suffix, this will be false if there are none
  if test -n "$(find "$template_dir" -name "*$stream_suffix" -print -quit)"; then
    mkdir -p "$stream_output_dir"
    if [ ! -w "$stream_output_dir" ]; then
      entrypoint_log "$ME: ERROR: $template_dir exists, but $stream_output_dir is not writable"
      return 1
    fi
    add_stream_block
    find "$template_dir" -follow -type f -name "*$stream_suffix" -print | while read -r template; do
      relative_path="${template#"$template_dir/"}"
      output_path="$stream_output_dir/${relative_path%"$stream_suffix"}"
      subdir=$(dirname "$relative_path")
      # create a subdirectory where the template file exists
      mkdir -p "$stream_output_dir/$subdir"
      entrypoint_log "$ME: Running envsubst on $template to $output_path"
      envsubst "$defined_envs" < "$template" > "$output_path"
    done
  fi
}

auto_envsubst

exit 0
