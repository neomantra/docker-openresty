#!/bin/bash
set -euo pipefail
image="${1:?image}" flavor="${2:?flavor}" arch="${3:?architecture}"
prefixes=$(bash "$(dirname "$0")/tag-prefixes.sh")
while IFS= read -r prefix; do
    printf '%s:%s%s-%s\n' "$image" "$prefix" "$flavor" "$arch"
done <<< "$prefixes"
