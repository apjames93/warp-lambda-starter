#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Script: build_libpq_layer_docker.sh
#
# Builds the PostgreSQL static libpq.a library and headers inside an
# Alpine Linux (musl) container for use with x86_64-unknown-linux-musl Rust targets.
# Outputs are written to `libpq_layer/lib` and `libpq_layer/include/libpq`.
# ─────────────────────────────────────────────────────────────────────────────

LAYER_DIR=libpq_layer
LIB_DIR=${LAYER_DIR}/lib
INCLUDE_DIR=${LAYER_DIR}/include/libpq
PG_VERSION=10.23
PG_TARBALL=postgresql-${PG_VERSION}.tar.gz
PG_SRC_DIR=postgresql-${PG_VERSION}

# Clean up previous builds
rm -rf "${LAYER_DIR}" "${PG_TARBALL}" "${PG_SRC_DIR}" libpq_layer.zip
mkdir -p "${LIB_DIR}" "${INCLUDE_DIR}"

echo "📦 Starting build inside Alpine Linux (musl)..."
docker run --rm \
  -v "$PWD":/layerbuild \
  -w /layerbuild \
  alpine:latest sh -c "
    set -e
    apk add --no-cache build-base musl-dev openssl-dev zlib-dev wget tar &&
    wget https://ftp.postgresql.org/pub/source/v${PG_VERSION}/${PG_TARBALL} &&
    tar -xzf ${PG_TARBALL} &&
    cd ${PG_SRC_DIR} &&
    ./configure --prefix=/tmp/pg --disable-shared --without-readline --without-zlib &&
    cd src/interfaces/libpq &&
    make &&
    make install &&
    cp /tmp/pg/lib/libpq.a /layerbuild/${LIB_DIR}/ &&
    cp -r /tmp/pg/include/* /layerbuild/${INCLUDE_DIR}/
  "

# Optional: zip the layer for manual upload or inspection
echo '📦 Zipping the layer for inspection or manual use...'
(cd ${LAYER_DIR} && zip -r ../libpq_layer.zip .)

# Clean up downloaded source
rm -rf "${PG_TARBALL}" "${PG_SRC_DIR}"

echo "✅ Static libpq layer build complete."
echo "→ Library: ${LIB_DIR}/libpq.a"
echo "→ Headers: ${INCLUDE_DIR}/"
