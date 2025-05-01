#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Script: build_libpq_layer_docker.sh
#
# Builds a static `libpq.a` (PostgreSQL) along with its headers and required
# static dependencies (libssl.a, libcrypto.a, libz.a) inside an Alpine (musl)
# container for use with `x86_64-unknown-linux-musl` Rust cross compilation.
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

echo "📦 Starting static build inside Alpine Linux (musl)..."

docker run --rm \
  -v "$PWD":/layerbuild \
  -w /layerbuild \
  alpine:latest sh -c "
    set -eux

    apk add --no-cache build-base musl-dev openssl-dev zlib-static wget tar

    echo '⬇️ Downloading PostgreSQL source...'
    wget https://ftp.postgresql.org/pub/source/v${PG_VERSION}/${PG_TARBALL}
    tar -xzf ${PG_TARBALL}
    cd ${PG_SRC_DIR}

    echo '⚙️ Configuring with static build options...'
    CFLAGS='-fPIC -O2' ./configure --prefix=/tmp/pg --disable-shared --without-readline --without-zlib

    echo '🔨 Building libpq...'
    cd src/interfaces/libpq
    make
    make install

    echo '📁 Copying outputs...'
    cp /tmp/pg/lib/libpq.a /layerbuild/${LIB_DIR}/
    cp -r /tmp/pg/include/* /layerbuild/${INCLUDE_DIR}/

    echo '📁 Copying static OpenSSL and Zlib dependencies...'
    cp /usr/lib/libssl.a /layerbuild/${LIB_DIR}/ || echo '⚠️ libssl.a not found'
    cp /usr/lib/libcrypto.a /layerbuild/${LIB_DIR}/ || echo '⚠️ libcrypto.a not found'
    cp /usr/lib/libz.a /layerbuild/${LIB_DIR}/ || echo '⚠️ libz.a not found'
  "

echo '📦 Zipping the layer for inspection or manual use...'
(cd ${LAYER_DIR} && zip -r ../libpq_layer.zip .)

# Clean up source tarballs and directories
rm -rf "${PG_TARBALL}" "${PG_SRC_DIR}"

echo "✅ Static libpq layer build complete."
echo "→ Library: ${LIB_DIR}/libpq.a"
echo "→ Dependencies: ${LIB_DIR}/libssl.a, libcrypto.a, libz.a"
echo "→ Headers: ${INCLUDE_DIR}/"
