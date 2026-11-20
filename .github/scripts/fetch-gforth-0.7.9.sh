#!/usr/bin/env bash
# CI helper: prefer prebuilt GForth from GHCR; fall back to source build.
#
# The image is built with --prefix=/opt/gforth-0.7.9; the engine hard-codes
# that path for gforth.fi, so we must install to the same absolute prefix
# (not ~/opt/...).
set -euo pipefail

PREFIX="/opt/gforth-0.7.9"
IMAGE="${GFORTH_IMAGE:-ghcr.io/vitasound/gforth:0.7.9}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

add_path() {
  if [[ -n "${GITHUB_PATH:-}" ]]; then
    echo "${PREFIX}/bin" >> "${GITHUB_PATH}"
  fi
  export PATH="${PREFIX}/bin:${PATH}"
}

if [[ -x "${PREFIX}/bin/gforth" ]] \
  && "${PREFIX}/bin/gforth" --version 2>&1 | grep -q '0.7.9'; then
  # Quick check that the image file is reachable (relocation break).
  if "${PREFIX}/bin/gforth" -e 'bye' </dev/null >/dev/null 2>&1; then
    echo "GForth 0.7.9 already present at ${PREFIX}"
    add_path
    exit 0
  fi
fi

if command -v docker >/dev/null 2>&1; then
  echo "Trying GHCR image ${IMAGE} ..."
  if docker pull "${IMAGE}"; then
    cid="$(docker create "${IMAGE}")"
    cleanup() { docker rm -f "${cid}" >/dev/null 2>&1 || true; }
    trap cleanup EXIT
    sudo mkdir -p /opt
    sudo rm -rf "${PREFIX}"
    sudo docker cp "${cid}:/opt/gforth-0.7.9" "${PREFIX}"
    trap - EXIT
    cleanup
    "${PREFIX}/bin/gforth" --version 2>&1 | grep -q '0.7.9'
    "${PREFIX}/bin/gforth" -e 'bye' </dev/null >/dev/null
    echo "Installed from GHCR: $("${PREFIX}/bin/gforth" --version 2>&1 | head -1)"
    add_path
    exit 0
  fi
  echo "GHCR pull failed; falling back to source build"
fi

# Source build also targets /opt so the engine path matches.
export GFORTH_PREFIX="${PREFIX}"
bash "${ROOT}/.github/scripts/build-gforth-0.7.9.sh"
