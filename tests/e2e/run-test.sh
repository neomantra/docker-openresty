#!/bin/bash
# No production writes/credentials. Owns two random loopback registries and a
# dedicated builder; removes only those resources on exit.
# Usage: bash tests/e2e/run-test.sh [flavor ...] (default: bookworm alpine-apk)
# E2E_ARCHS selects architectures; the PR workflow runs one flavor/architecture
# row per job and sets it to that row's architecture.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$ROOT"
TEST_DIR=$(mktemp -d)
NAME="openresty-e2e-${TEST_DIR##*.}-$$"
PRIMARY_CID="" MIRROR_CID="" BUILDER_CREATED=false
cleanup() {
    if [[ "$BUILDER_CREATED" == true ]]; then docker buildx rm "$NAME" >/dev/null || true; fi
    if [[ -n "$MIRROR_CID" ]]; then docker rm -f "$MIRROR_CID" >/dev/null || true; fi
    if [[ -n "$PRIMARY_CID" ]]; then docker rm -f "$PRIMARY_CID" >/dev/null || true; fi
    rm -rf -- "$TEST_DIR"
}
trap cleanup EXIT
[[ $# -gt 0 ]] || set -- bookworm alpine-apk
MATRIX=.github/build-matrix.json
for flavor in "$@"; do
    jq -e --arg flavor "$flavor" 'any((.base.include + .fat.include)[]; .flavor == $flavor)' "$MATRIX" >/dev/null
done
if [[ -n "${E2E_BASE_IMAGE:-}" && $# != 1 ]]; then
    echo 'E2E_BASE_IMAGE requires exactly one flavor' >&2; exit 1
fi
# Share a disposable network namespace, not the host network. Matching inner
# and outer ports makes loopback image references work in both BuildKit and the
# host CLI, including Docker Desktop with host networking disabled.
for ((attempt=0; attempt<20; attempt++)); do
    primary_port=$((20000 + RANDOM))
    mirror_port=$((20000 + RANDOM))
    [[ "$primary_port" != "$mirror_port" ]] || continue
    PRIMARY_CID=$(docker create -p "127.0.0.1:$primary_port:$primary_port" \
        -p "127.0.0.1:$mirror_port:$mirror_port" \
        -e "REGISTRY_HTTP_ADDR=:$primary_port" registry:2)
    if docker start "$PRIMARY_CID" >/dev/null; then break; fi
    docker rm "$PRIMARY_CID" >/dev/null
    PRIMARY_CID=""
done
[[ -n "$PRIMARY_CID" ]] || { echo 'Could not allocate registry ports' >&2; exit 1; }
MIRROR_CID=$(docker run -d --network "container:$PRIMARY_CID" \
    -e "REGISTRY_HTTP_ADDR=:$mirror_port" registry:2)
PRIMARY_REGISTRY="127.0.0.1:$primary_port"
MIRROR_REGISTRY="127.0.0.1:$mirror_port"
for registry in "$PRIMARY_REGISTRY" "$MIRROR_REGISTRY"; do
    curl --retry 20 --retry-connrefused --retry-delay 1 --max-time 3 -fsS "http://$registry/v2/"
done
export PRIMARY_IMAGE="$PRIMARY_REGISTRY/openresty/test"
export MIRROR_IMAGE="$MIRROR_REGISTRY/openresty/test"
cat > "$TEST_DIR/buildkitd.toml" <<EOF
[registry."$PRIMARY_REGISTRY"]
  http = true
[registry."$MIRROR_REGISTRY"]
  http = true
EOF
docker buildx create --name "$NAME" --driver docker-container \
    --driver-opt "network=container:$PRIMARY_CID" --buildkitd-config "$TEST_DIR/buildkitd.toml"
BUILDER_CREATED=true
export BUILDX_BUILDER="$NAME"
docker buildx inspect --bootstrap
export GITHUB_REF_TYPE=tag
series=$(tr -d '[:space:]' < LATEST_SERIES)
export GITHUB_REF_NAME="$series.1.1-999" MIRROR_ENABLED=true
build_candidate() {
    local file="$1"; shift
    docker buildx build --platform "$SMOKE_PLATFORM" --file "$file" \
        --output "type=image,name=$PRIMARY_IMAGE,push-by-digest=true,name-canonical=true,push=true" \
        --metadata-file "$TEST_DIR/build.json" "$@" .
    DIGEST=$(jq -er '.["containerimage.digest"]' "$TEST_DIR/build.json")
}
build_row() {
    local row="$1" file arg
    file=$(jq -r '.dockerfile' <<< "$row")
    local args=()
    while IFS= read -r arg; do
        [[ -z "$arg" ]] || args+=(--build-arg "$arg")
    done <<< "$(jq -r '.["build-args"] // ""' <<< "$row")"
    build_candidate "$file" ${args[@]+"${args[@]}"}
}
publish() {
    local flavor="$1" kind="$2" suffix=""
    [[ "$kind" == standard ]] || suffix=-entrypoint
    TAGS=$(bash scripts/image-tags.sh "$PRIMARY_IMAGE" "$flavor$suffix" "$arch")
    TAGS="$TAGS
$(GITHUB_REF_TYPE=branch GITHUB_REF_NAME=master bash scripts/image-tags.sh "$PRIMARY_IMAGE" "$flavor$suffix" "$arch")"
    export TAGS
    bash scripts/test-and-publish.sh "$PRIMARY_IMAGE@$DIGEST" "$flavor" "$kind"
}
assert_absent() {
    local registry="$1" tag="$2" code
    code=$(curl -sS -o /dev/null -w '%{http_code}' "http://$registry/v2/openresty/test/manifests/$tag")
    [[ "$code" == 404 ]] || { echo "Unexpected tag $registry:$tag (HTTP $code)" >&2; exit 1; }
}
manifest_hash() { docker buildx imagetools inspect --raw "$1" | shasum -a 256; }
for flavor in "$@"; do
    rows=$(jq -c --arg flavor "$flavor" '(.base.include + .fat.include)[] | select(.flavor == $flavor)' "$MATRIX")
    arches=()
    tested_failure=false
    while IFS= read -r row; do
        arch=$(jq -r '.arch' <<< "$row")
        if [[ -n "${E2E_ARCHS:-}" && " $E2E_ARCHS " != *" $arch "* ]]; then continue; fi
        arches+=("$arch")
        export SMOKE_PLATFORM="linux/$arch"
        echo "Testing $flavor / $SMOKE_PLATFORM (host: $(uname -m); foreign architectures use emulation)"
        parent=$(jq -r '.base_flavor // ""' <<< "$row")
        if [[ -n "${E2E_BASE_IMAGE:-}" ]]; then
            echo "LOCAL RUNTIME INVESTIGATION: importing $E2E_BASE_IMAGE instead of building $flavor's Dockerfile"
            build_candidate tests/fixtures/Dockerfile.base --build-arg "BASE=$E2E_BASE_IMAGE"
        elif [[ -n "$parent" ]]; then
            parent_row=$(jq -ec --arg flavor "$parent" --arg arch "$arch" '.base.include[] | select(.flavor == $flavor and .arch == $arch)' "$MATRIX")
            build_row "$parent_row"
            publish "$parent" standard
            build_candidate "$(jq -r '.dockerfile' <<< "$row")" \
                --build-arg "RESTY_FAT_IMAGE_BASE=$PRIMARY_IMAGE" \
                --build-arg "RESTY_FAT_IMAGE_TAG=$parent-$arch@$DIGEST"
        else
            build_row "$row"
        fi
        publish "$flavor" standard
        base_digest="$DIGEST"
        variant=""
        case "$flavor" in bookworm-debug) variant=-debug ;; bookworm-valgrind) variant=-valgrind ;; esac
        build_candidate entrypoint/Dockerfile \
            --build-arg "RESTY_ENTRYPOINT_BASE=$PRIMARY_IMAGE@$base_digest" \
            --build-arg "RESTY_ENTRYPOINT_COMMAND=openresty$variant" \
            --build-arg "RESTY_PREFIX=/usr/local/openresty$variant"
        publish "$flavor" entrypoint
        derived_digest="$DIGEST"
        actual_base=$(docker image inspect -f '{{index .Config.Labels "resty_entrypoint_base"}}' "$PRIMARY_IMAGE@$DIGEST")
        [[ "$actual_base" == "$PRIMARY_IMAGE@$base_digest" ]]
        base_layers=$(docker image inspect -f '{{json .RootFS.Layers}}' "$PRIMARY_IMAGE@$base_digest")
        derived_layers=$(docker image inspect -f '{{json .RootFS.Layers}}' "$PRIMARY_IMAGE@$derived_digest")
        jq -en --argjson base "$base_layers" --argjson derived "$derived_layers" '$derived[0:($base|length)] == $base' >/dev/null
        if [[ "$tested_failure" == false ]]; then
            TAGS="$PRIMARY_IMAGE:mirror-disabled-$flavor-$arch" MIRROR_ENABLED=false \
                bash scripts/test-and-publish.sh "$PRIMARY_IMAGE@$derived_digest" "$flavor" entrypoint
            assert_absent "$MIRROR_REGISTRY" "mirror-disabled-$flavor-$arch"
            # A broken hook must neither create new tags nor overwrite tested
            # tags in either registry. Exercise the production gate itself.
            existing="$flavor-entrypoint-$arch"
            primary_before=$(manifest_hash "$PRIMARY_IMAGE:$existing")
            mirror_before=$(manifest_hash "$MIRROR_IMAGE:$existing")
            build_candidate tests/fixtures/Dockerfile.broken --build-arg "BASE=$PRIMARY_IMAGE@$derived_digest"
            if TAGS="$PRIMARY_IMAGE:rejected-$flavor-$arch
$PRIMARY_IMAGE:$existing" bash scripts/test-and-publish.sh "$PRIMARY_IMAGE@$DIGEST" "$flavor" entrypoint > "$TEST_DIR/rejected.log" 2>&1; then
                echo 'Broken candidate was published' >&2; exit 1
            fi
            if ! grep -q 'Intentional E2E startup failure' "$TEST_DIR/rejected.log"; then
                cat "$TEST_DIR/rejected.log" >&2
                echo 'Candidate failed for an unexpected reason' >&2; exit 1
            fi
            assert_absent "$PRIMARY_REGISTRY" "rejected-$flavor-$arch"
            assert_absent "$MIRROR_REGISTRY" "rejected-$flavor-$arch"
            [[ $(manifest_hash "$PRIMARY_IMAGE:$existing") == "$primary_before" ]]
            [[ $(manifest_hash "$MIRROR_IMAGE:$existing") == "$mirror_before" ]]
            tested_failure=true
        fi
    done <<< "$rows"
    [[ ${#arches[@]} -gt 0 ]] || { echo "No selected architectures for $flavor" >&2; exit 1; }
    export RESTY_ARCHS="${arches[*]}"
    expected_arches=$(printf '%s\n' "${arches[@]}" | jq -Rsc 'split("\n") | map(select(length > 0)) | sort')
    for ref_type in tag branch; do
        release_name="$GITHUB_REF_NAME"
        export GITHUB_REF_TYPE="$ref_type"
        if [[ "$ref_type" == branch ]]; then export GITHUB_REF_NAME=master; fi
        for suffix in "" -entrypoint; do
            bash scripts/create-manifest.sh "$flavor$suffix" "$PRIMARY_IMAGE" "$MIRROR_IMAGE" true
            prefixes=$(bash scripts/tag-prefixes.sh)
            while IFS= read -r prefix; do
                [[ $(manifest_hash "$PRIMARY_IMAGE:$prefix$flavor$suffix") == "$(manifest_hash "$MIRROR_IMAGE:$prefix$flavor$suffix")" ]]
                for image in "$PRIMARY_IMAGE" "$MIRROR_IMAGE"; do
                    actual=$(docker buildx imagetools inspect --raw "$image:$prefix$flavor$suffix" | \
                        jq -c '[.manifests[] | select(.platform.os == "linux") | .platform.architecture] | sort')
                    [[ "$actual" == "$expected_arches" ]] || { echo "Wrong manifest platforms: $actual != $expected_arches" >&2; exit 1; }
                    for platform_arch in "${arches[@]}"; do
                        docker pull --platform "linux/$platform_arch" "$image:$prefix$flavor$suffix" >/dev/null
                    done
                done
            done <<< "$prefixes"
        done
        if [[ "$flavor" == bookworm && "$ref_type" == tag ]]; then
            for image in "$PRIMARY_IMAGE" "$MIRROR_IMAGE"; do
                [[ $(manifest_hash "$image:latest") == "$(manifest_hash "$image:$GITHUB_REF_NAME-bookworm")" ]]
            done
        fi
        export GITHUB_REF_NAME="$release_name"
    done
    export GITHUB_REF_TYPE=tag
done
echo "Registry E2E passed: $*"
