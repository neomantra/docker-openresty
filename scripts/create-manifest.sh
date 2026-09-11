#!/bin/bash
# Creates and pushes manifests for flavors
#
# Usage: ./create-manifest.sh <flavor> <registry_image> <mirror_image> <mirror_enable_bool>
# Example: ./create-manifest.sh alpine ghcr.io/owner/repo docker.io/owner/repo true

set -e


FLAVOR="$1"
REGISTRY_IMAGE="$2"
MIRROR_IMAGE="$3"
ENABLE_MIRROR="$4"

# Validate inputs
if [[ -z "$FLAVOR" ]]; then
  echo "Error: Flavor argument is missing."
  exit 1
fi

if [[ -z "$REGISTRY_IMAGE" ]]; then
  echo "Error: Registry image argument is missing."
  exit 1
fi

# Define latest version series to tag as latest
# Can be overridden by env var or file (LATEST_SERIES in current dir)
if [[ -f "LATEST_SERIES" ]]; then
    RESTY_LATEST_SERIES=$(cat LATEST_SERIES | head -n 1 | tr -d '[:space:]')
fi
RESTY_LATEST_SERIES="${RESTY_LATEST_SERIES:-1.29}"

# Keep build, validation, and manifest architectures in one source of truth.
SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
BASE_FLAVOR="${FLAVOR%-entrypoint}"
ARCHS="${RESTY_ARCHS:-}"
if [[ -z "$ARCHS" ]]; then
    ARCHS=$(jq -r --arg flavor "$BASE_FLAVOR" \
        '[((.base.include + .fat.include)[]) | select(.flavor == $flavor) | .arch] | join(" ")' \
        "$SCRIPT_DIR/../.github/build-matrix.json")
    [[ -n "$ARCHS" ]] || { echo "Unknown flavor: $FLAVOR" >&2; exit 1; }
fi

echo "Creating manifest for flavor: $FLAVOR (Architectures: $ARCHS)"

# Construct tag prefixes (handling git tags and aliases)
declare -a PREFIXES=()
prefixes=$(bash "$SCRIPT_DIR/tag-prefixes.sh")
while IFS= read -r prefix; do
    PREFIXES+=("$prefix")
done <<< "$prefixes"

# Loop through each calculated tag prefix and create manifests
for TAG_PREFIX in "${PREFIXES[@]}"; do
    SOURCES=""
    MIRROR_SOURCES=""
    
    # Collect source images for all architectures
    for ARCH in $ARCHS; do
        SRC_IMG="${REGISTRY_IMAGE}:${TAG_PREFIX}${FLAVOR}-${ARCH}"
        SOURCES="$SOURCES ${SRC_IMG}"
        if [[ "$ENABLE_MIRROR" == "true" ]]; then
            # Use GHCR (SRC_IMG) as source for mirror manifest to ensure multi-arch consistency
            MIRROR_SOURCES="$MIRROR_SOURCES ${SRC_IMG}"
        fi
    done
  
    # Target Manifest Tag
    TARGET_TAG="${TAG_PREFIX}${FLAVOR}"
    
    # 1. Create GHCR Manifest
    echo "Creating manifest ${REGISTRY_IMAGE}:$TARGET_TAG"
    # Note: docker buildx imagetools create automatically pushes the manifest to the registry.
    if [[ "$DRY_RUN" != "true" ]]; then
        docker buildx imagetools create -t "${REGISTRY_IMAGE}:$TARGET_TAG" $SOURCES
    else
        echo "DRY RUN: docker buildx imagetools create -t \"${REGISTRY_IMAGE}:$TARGET_TAG\" $SOURCES"
    fi
    
    # 2. Create Mirror Manifest (if enabled)
    if [[ "$ENABLE_MIRROR" == "true" ]]; then
       echo "Creating mirror manifest ${MIRROR_IMAGE}:$TARGET_TAG"
       if [[ "$DRY_RUN" != "true" ]]; then
           docker buildx imagetools create -t "${MIRROR_IMAGE}:$TARGET_TAG" $MIRROR_SOURCES
       else
           echo "DRY RUN: docker buildx imagetools create -t \"${MIRROR_IMAGE}:$TARGET_TAG\" $MIRROR_SOURCES"
       fi
    fi
    
    # 3. Handle specific "latest" tag logic for bookworm
    # Point latest to the tagged release of the current primary version series
    if [[ "$FLAVOR" == "bookworm" && "$GITHUB_REF_TYPE" == "tag" ]]; then
       if [[ "$GITHUB_REF_NAME" == "${RESTY_LATEST_SERIES}."* && "$TAG_PREFIX" == "${GITHUB_REF_NAME}-" ]]; then
           echo "Tagging $GITHUB_REF_NAME bookworm as latest"
           if [[ "$DRY_RUN" != "true" ]]; then
               docker buildx imagetools create -t "${REGISTRY_IMAGE}:latest" $SOURCES
               if [[ "$ENABLE_MIRROR" == "true" ]]; then
                  docker buildx imagetools create -t "${MIRROR_IMAGE}:latest" $MIRROR_SOURCES
               fi
           else 
               echo "DRY RUN: docker buildx imagetools create -t \"${REGISTRY_IMAGE}:latest\" $SOURCES"
               if [[ "$ENABLE_MIRROR" == "true" ]]; then
                  echo "DRY RUN: docker buildx imagetools create -t \"${MIRROR_IMAGE}:latest\" $MIRROR_SOURCES"
               fi
           fi
       fi
    fi
    
    # 4. Create compatibility aliases (centos-rpm -> centos, etc.)
    # Note: Logic slightly adjusted from YAML to be generic if needed, 
    # but sticking to specific requested aliases for now.
    
    if [[ "$FLAVOR" == "centos" ]]; then
       ALIAS_TAG="${TAG_PREFIX}centos-rpm"
       echo "Creating alias $ALIAS_TAG -> $TARGET_TAG"
       if [[ "$DRY_RUN" != "true" ]]; then
           docker buildx imagetools create -t "${REGISTRY_IMAGE}:$ALIAS_TAG" "${REGISTRY_IMAGE}:$TARGET_TAG"
           if [[ "$ENABLE_MIRROR" == "true" ]]; then
              docker buildx imagetools create -t "${MIRROR_IMAGE}:$ALIAS_TAG" "${MIRROR_IMAGE}:$TARGET_TAG"
           fi
       else
           echo "DRY RUN: docker buildx imagetools create -t \"${REGISTRY_IMAGE}:$ALIAS_TAG\" \"${REGISTRY_IMAGE}:$TARGET_TAG\""
           if [[ "$ENABLE_MIRROR" == "true" ]]; then
              echo "DRY RUN: docker buildx imagetools create -t \"${MIRROR_IMAGE}:$ALIAS_TAG\" \"${MIRROR_IMAGE}:$TARGET_TAG\""
           fi
        fi
    fi

    if [[ "$BASE_FLAVOR" == "fedora" ]]; then
       ALIAS_TAG="${TAG_PREFIX}fedora-rpm${FLAVOR#"$BASE_FLAVOR"}"
       echo "Creating alias $ALIAS_TAG -> $TARGET_TAG"
       if [[ "$DRY_RUN" != "true" ]]; then
           docker buildx imagetools create -t "${REGISTRY_IMAGE}:$ALIAS_TAG" "${REGISTRY_IMAGE}:$TARGET_TAG"
           if [[ "$ENABLE_MIRROR" == "true" ]]; then
              docker buildx imagetools create -t "${MIRROR_IMAGE}:$ALIAS_TAG" "${MIRROR_IMAGE}:$TARGET_TAG"
           fi
       else
           echo "DRY RUN: docker buildx imagetools create -t \"${REGISTRY_IMAGE}:$ALIAS_TAG\" \"${REGISTRY_IMAGE}:$TARGET_TAG\""
           if [[ "$ENABLE_MIRROR" == "true" ]]; then
              echo "DRY RUN: docker buildx imagetools create -t \"${MIRROR_IMAGE}:$ALIAS_TAG\" \"${MIRROR_IMAGE}:$TARGET_TAG\""
           fi
       fi
    fi
done

echo "Manifest creation complete for $FLAVOR"
