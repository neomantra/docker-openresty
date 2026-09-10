# Optional entrypoint layer for any standard Linux OpenResty flavor.
# CI supplies the exact digest of the base image built in the same job.
ARG RESTY_ENTRYPOINT_BASE="openresty/openresty:bookworm"
FROM ${RESTY_ENTRYPOINT_BASE}

ARG RESTY_ENTRYPOINT_BASE
ARG RESTY_ENTRYPOINT_COMMAND="openresty"
ARG RESTY_PREFIX="/usr/local/openresty"

LABEL resty_entrypoint_base="${RESTY_ENTRYPOINT_BASE}"
ENV RESTY_ENTRYPOINT_COMMAND="${RESTY_ENTRYPOINT_COMMAND}"
ENV RESTY_LOG_DIR="${RESTY_PREFIX}/nginx/logs"

# Most base flavors already include envsubst. Install it only when missing.
RUN if ! command -v envsubst >/dev/null 2>&1; then \
        if command -v apk >/dev/null 2>&1; then \
            apk add --no-cache --virtual .entrypoint-gettext gettext \
            && cp /usr/bin/envsubst /usr/local/bin/envsubst \
            && apk add --no-cache libintl \
            && apk del .entrypoint-gettext; \
        elif command -v microdnf >/dev/null 2>&1; then \
            microdnf install -y gettext && microdnf clean all; \
        elif command -v dnf >/dev/null 2>&1; then \
            dnf install -y gettext && dnf clean all; \
        elif command -v apt-get >/dev/null 2>&1; then \
            apt-get update \
            && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gettext-base \
            && rm -rf /var/lib/apt/lists/*; \
        else \
            echo "No supported package manager for installing envsubst" >&2; exit 1; \
        fi; \
    fi \
    && command -v envsubst \
    && command -v "${RESTY_ENTRYPOINT_COMMAND}" \
    && sed -i 's|^#pid[[:space:]]*logs/nginx.pid;|pid /var/run/openresty/nginx.pid;|' "${RESTY_PREFIX}/nginx/conf/nginx.conf" \
    && grep -q '^pid /var/run/openresty/nginx.pid;' "${RESTY_PREFIX}/nginx/conf/nginx.conf" \
    && sed -i "s|/usr/local/openresty/nginx/html|${RESTY_PREFIX}/nginx/html|g" /etc/nginx/conf.d/default.conf \
    && mkdir -p /var/run/openresty \
    && chmod 1777 /var/run/openresty

COPY --chmod=755 docker-entrypoint.sh /docker-entrypoint.sh
COPY --chmod=755 docker-entrypoint.d/ /docker-entrypoint.d/

ENTRYPOINT ["/docker-entrypoint.sh"]
# Setting ENTRYPOINT clears the inherited CMD. Leading flags select the
# flavor's RESTY_ENTRYPOINT_COMMAND, including debug and Valgrind binaries.
CMD ["-g", "daemon off;"]
STOPSIGNAL SIGQUIT
