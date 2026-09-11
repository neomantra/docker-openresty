#!/bin/bash
# Fast checks without Docker, registries, network access, or credentials.
set -euo pipefail
cd "$(dirname "$0")/.."
matrix=.github/build-matrix.json
jq -e '
  (.base.include + .fat.include) as $rows |
  ($rows | length > 0) and
  (($rows | map([.flavor, .arch]) | unique | length) == ($rows | length)) and
  all($rows[]; .platforms == ("linux/" + .arch)) and
  all(.fat.include[]; . as $fat | any($rows[]; .flavor == $fat.base_flavor and .arch == $fat.arch))
' "$matrix" >/dev/null
while IFS= read -r file; do test -f "$file"; done < <(jq -r '(.base.include + .fat.include)[].dockerfile' "$matrix")
export DRY_RUN=true
export GITHUB_REF_TYPE=tag
series=$(tr -d '[:space:]' < LATEST_SERIES)
export GITHUB_REF_NAME="$series.1.1-999"
primary=ghcr.io/test/openresty mirror=docker.io/test/openresty
for flavor in $(jq -r '[(.base.include + .fat.include)[].flavor] | unique[]' "$matrix"); do
    expected=$(jq -r --arg flavor "$flavor" '[(.base.include + .fat.include)[] | select(.flavor == $flavor) | .arch] | join(" ")' "$matrix")
    for suffix in "" -entrypoint; do
        output=$(bash scripts/create-manifest.sh "$flavor$suffix" "$primary" "$mirror" true)
        [[ "$output" == *"Architectures: $expected)"* ]]
        for arch in $expected; do
            tags=$(bash scripts/image-tags.sh "$primary" "$flavor$suffix" "$arch")
            for prefix in "$GITHUB_REF_NAME-" "$series.1.1-" "$series-"; do
                [[ "$tags" == *"$primary:$prefix$flavor$suffix-$arch"* ]]
                [[ "$output" == *"$primary:$prefix$flavor$suffix-$arch"* ]]
                [[ "$output" == *"$mirror:$prefix$flavor$suffix"* ]]
            done
            [[ $(printf '%s\n' "$tags" | wc -l | tr -d ' ') == 3 ]]
        done
        if [[ "$flavor$suffix" == bookworm ]]; then
            [[ "$output" == *"$primary:latest"* ]]
        else
            [[ "$output" != *':latest'* ]]
        fi
        if [[ "$flavor" == fedora ]]; then [[ "$output" == *"fedora-rpm$suffix"* ]]; fi
    done
done
output=$(RESTY_ARCHS=amd64 bash scripts/create-manifest.sh alma-entrypoint "$primary" "$mirror" false)
[[ "$output" == *'Architectures: amd64)'* && "$output" != *s390x* && "$output" != *"$mirror"* ]]
tags=$(GITHUB_REF_TYPE=branch GITHUB_REF_NAME=master bash scripts/image-tags.sh "$primary" bookworm-entrypoint arm64)
[[ "$tags" == "$primary:bookworm-entrypoint-arm64" ]]
[[ $(bash scripts/fat-base-tag.sh bookworm) == "$GITHUB_REF_NAME-bookworm" ]]
[[ $(GITHUB_REF_TYPE=branch GITHUB_REF_NAME=master bash scripts/fat-base-tag.sh alpine) == alpine ]]
if GITHUB_REF_TYPE=branch GITHUB_REF_NAME=feature bash scripts/image-tags.sh "$primary" bookworm amd64; then
    echo 'Feature branch was allowed to publish production aliases' >&2; exit 1
fi
echo 'CI matrix, tags, manifests, latest, and mirror contracts passed'
