#!/bin/bash
# Shared release aliases for architecture tags and multi-architecture manifests.
set -euo pipefail
if [[ "${GITHUB_REF_TYPE:-branch}" == tag ]]; then
    tag="${GITHUB_REF_NAME:?Missing release tag}"
    printf '%s-\n' "$tag"
    if [[ "$tag" =~ ^(.*)-[0-9]+$ ]]; then
        printf '%s-\n' "${BASH_REMATCH[1]}"
    fi
    if [[ "$tag" =~ ^([0-9]+\.[0-9]+)\..*-[0-9]+$ ]]; then
        printf '%s-\n' "${BASH_REMATCH[1]}"
    fi
elif [[ "${GITHUB_REF_NAME:-master}" == master ]]; then
    printf '\n'
else
    echo 'Publishing requires master or a release tag; use docker-validate for PRs.' >&2
    exit 1
fi
