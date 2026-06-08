#!/usr/bin/env bash
set -euo pipefail

PREFIX="${HOME}/opt/gforth-0.7.9"
GFORTH_TAG="0.7.9_20250101"
GNU_TARBALL="https://ftp.gnu.org/gnu/gforth/gforth-0.7.9.tar.gz"
GIT_TARBALL="https://github.com/forthy42/gforth/archive/refs/tags/${GFORTH_TAG}.tar.gz"

if [[ -x "${PREFIX}/bin/gforth" ]]; then
  "${PREFIX}/bin/gforth" --version 2>&1 | grep -q '0.7.9'
  echo "GForth 0.7.9 already installed at ${PREFIX}"
  echo "${PREFIX}/bin" >> "${GITHUB_PATH}"
  exit 0
fi

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  build-essential git wget ca-certificates \
  autoconf automake libtool-bin libltdl-dev libffi-dev flex bison zlib1g-dev \
  gforth texinfo
command -v libtool
libtool --version

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

download() {
  local url="$1"
  local out="$2"
  wget -q --timeout=60 --tries=3 -O "${out}" "${url}"
}

TARBALL="${WORKDIR}/gforth.tar.gz"
if download "${GNU_TARBALL}" "${TARBALL}"; then
  echo "Using GNU gforth-0.7.9.tar.gz"
else
  echo "GNU tarball unavailable, using Git tag ${GFORTH_TAG}"
  download "${GIT_TARBALL}" "${TARBALL}"
fi

tar -C "${WORKDIR}" -xf "${TARBALL}"
SRC="$(find "${WORKDIR}" -maxdepth 1 -type d -name 'gforth*' | head -1)"
if [[ -z "${SRC}" ]]; then
  echo "Could not find gforth source directory after extract" >&2
  exit 1
fi

cd "${SRC}"
if [[ ! -f configure ]]; then
  ./autogen.sh
fi
./configure --prefix="${PREFIX}"
make -j"$(nproc)"
make install

"${PREFIX}/bin/gforth" --version 2>&1 | grep -q '0.7.9'
echo "Installed: $("${PREFIX}/bin/gforth" --version 2>&1 | head -1)"
echo "${PREFIX}/bin" >> "${GITHUB_PATH}"
