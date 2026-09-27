#!/bin/bash
# Shared by production Actions and disposable-registry tests. No tag is moved
# until the exact candidate digest has passed the complete runtime suite.
set -euo pipefail
SOURCE="${1:?Usage: test-and-publish.sh IMAGE@DIGEST FLAVOR KIND}"
FLAVOR="${2:?flavor}"
KIND="${3:?standard or entrypoint}"
: "${PRIMARY_IMAGE:?}" "${TAGS:?}" "${SMOKE_PLATFORM:?}"
[[ "$SOURCE" == "$PRIMARY_IMAGE"@sha256:* ]] || { echo 'Candidate must be a primary-registry digest' >&2; exit 1; }
while IFS= read -r tag; do
    [[ -n "$tag" ]] || continue
    [[ "$tag" == "$PRIMARY_IMAGE":* ]] || { echo "Unexpected tag destination: $tag" >&2; exit 1; }
done <<< "$TAGS"
if [[ "${MIRROR_ENABLED:-false}" == true ]]; then : "${MIRROR_IMAGE:?}"; fi
SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
docker pull --platform "$SMOKE_PLATFORM" "$SOURCE"
bash "$SCRIPT_DIR/smoke-test-image.sh" "$SOURCE" "$FLAVOR" "$KIND"
if [[ "$KIND" == entrypoint ]]; then
    bash "$SCRIPT_DIR/smoke-test-entrypoint.sh" "$SOURCE"
fi
while IFS= read -r tag; do
    [[ -n "$tag" ]] || continue
    docker buildx imagetools create -t "$tag" "$SOURCE"
    if [[ "${MIRROR_ENABLED:-false}" == true ]]; then
        docker buildx imagetools create -t "${MIRROR_IMAGE}${tag#"$PRIMARY_IMAGE"}" "$SOURCE"
    fi
done <<< "$TAGS"
