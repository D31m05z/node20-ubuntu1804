#!/usr/bin/env bash
# =============================================================================
# build-local.sh — build a glibc-2.27-compatible Node.js binary locally
#                  using Docker (works on macOS / Apple Silicon via emulation).
#
# Usage:
#   ./build-local.sh node20            # build the pinned Node 20 (gcc 10)
#   ./build-local.sh node24            # build the pinned Node 24 (gcc 13)
#   ./build-local.sh both              # build both
#   ./build-local.sh v22.14.0 12       # build any version with a chosen gcc
#
# Output (host): ./dist/<target>/
#   node-<version>-linux-x64.tar.gz   full Node distribution
#   node                              standalone node binary
# =============================================================================
set -euo pipefail

# ---- defaults (override on the command line) --------------------------------
NODE20_VERSION="${NODE20_VERSION:-v20.19.0}"
NODE24_VERSION="${NODE24_VERSION:-v24.11.1}"
PLATFORM="${PLATFORM:-linux/amd64}"          # bionic + GitHub runners are x64
IMAGE_PREFIX="node-bionic-builder"
DIST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dist"

# -----------------------------------------------------------------------------
build_one() {
    local node_version="$1" gcc_version="$2" label="$3"
    local image="${IMAGE_PREFIX}:${label}"
    local out_dir="${DIST_ROOT}/${label}"

    echo "==> Building ${label}: Node ${node_version} with gcc-${gcc_version} (${PLATFORM})"
    docker buildx build \
        --platform "${PLATFORM}" \
        --build-arg "NODE_VERSION=${node_version}" \
        --build-arg "GCC_VERSION=${gcc_version}" \
        --load \
        -t "${image}" \
        .

    echo "==> Extracting artifacts to ${out_dir}"
    rm -rf "${out_dir}"
    mkdir -p "${out_dir}"
    local cid
    cid="$(docker create --platform "${PLATFORM}" "${image}")"
    docker cp "${cid}:/dist/." "${out_dir}/"
    docker rm -f "${cid}" >/dev/null

    echo "==> Done: ${label}"
    ls -la "${out_dir}"
}

case "${1:-}" in
    node20) build_one "${NODE20_VERSION}" 10 "node20" ;;
    node24) build_one "${NODE24_VERSION}" 13 "node24" ;;
    both)
        build_one "${NODE20_VERSION}" 10 "node20"
        build_one "${NODE24_VERSION}" 13 "node24"
        ;;
    v*)
        # custom: ./build-local.sh <vX.Y.Z> [gcc_version]
        build_one "$1" "${2:-13}" "node-${1}"
        ;;
    *)
        echo "Usage: $0 {node20|node24|both|<vX.Y.Z> [gcc_version]}" >&2
        exit 2
        ;;
esac
