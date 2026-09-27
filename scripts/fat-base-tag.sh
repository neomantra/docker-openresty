#!/bin/bash
# The tag a fat image is built FROM: the release prefix (none on master) plus
# the base flavor, i.e. the multi-architecture manifest create-manifest.sh
# assembles for that base. Shared by docker-publish.yml and the E2E harness.
set -euo pipefail
base_flavor="${1:?Usage: fat-base-tag.sh BASE_FLAVOR}"
prefixes=$(bash "$(dirname "$0")/tag-prefixes.sh")
printf '%s%s\n' "${prefixes%%$'\n'*}" "$base_flavor"
