#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Script: build_libpq_layer_docker.sh
# Builds static libpq.a and dependencies inside Alpine container
# ─────────────────────────────────────────────────────────────────────────────

# Determine the project root dynamically (two levels up from this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/../..")"

AWS_DIR="$REPO_ROOT/aws"
LAYER_DIR="$AWS_DIR/libpq_layer"
LIB_DIR="${LAYER_DIR}/lib"
INCLUDE_DIR="${LAYER_DIR}/include/libpq"
PG_VERSION=10.23
PG_TARBALL=postgresql-${PG_VERSION}.tar.gz
PG_SRC_DIR=postgresql-${PG_VERSION}

# Clean up previous builds
rm -rf "${LAYER_DIR}" "${PG_TARBALL}" "${PG_SRC_DIR}" "$REPO_ROOT/aws/libpq_layer.zip"
mkdir -p "${LIB_DIR}" "${INCLUDE_DIR}"

echo "📦 Starting static build inside Alpine Linux (musl)..."

docker run --rm \
  -v "$REPO_ROOT/aws":/layerbuild \
  -w /layerbuild \
  alpine:latest sh -c "
    set -eux

    apk add --no-cache build-base musl-dev openssl-dev zlib-static wget tar

    echo '⬇️ Downloading PostgreSQL source...'
    wget https://ftp.postgresql.org/pub/source/v${PG_VERSION}/${PG_TARBALL}
    tar -xzf ${PG_TARBALL}
    cd ${PG_SRC_DIR}

    echo '⚙️ Configuring with static build options...'
    CFLAGS='-fPIC -O2' ./configure \
      --prefix=/tmp/pg \
      --disable-shared \
      --without-readline \
      --without-zlib \
      --without-gssapi

    echo '🔨 Building libpq...'
    cd src/interfaces/libpq
    make -j\$(nproc)
    make install

    echo '📁 Copying outputs...'
    cp /tmp/pg/lib/libpq.a /layerbuild/libpq_layer/lib/
    cp -r /tmp/pg/include/* /layerbuild/libpq_layer/include/libpq/

    echo '📁 Copying static OpenSSL and Zlib dependencies...'
    cp /usr/lib/libssl.a /layerbuild/libpq_layer/lib/ || echo '⚠️ libssl.a not found'
    cp /usr/lib/libcrypto.a /layerbuild/libpq_layer/lib/ || echo '⚠️ libcrypto.a not found'
    cp /usr/lib/libz.a /layerbuild/libpq_layer/lib/ || echo '⚠️ libz.a not found'
  "

echo '📦 Zipping the layer for inspection or manual use...'
(cd "$LAYER_DIR" && zip -r "$REPO_ROOT/aws/libpq_layer.zip" .)

# Clean up source tarballs and directories
rm -rf "${AWS_DIR}/${PG_TARBALL}" "${AWS_DIR}/${PG_SRC_DIR}"


echo "✅ Static libpq layer build complete."
echo "→ Library: ${LIB_DIR}/libpq.a"
echo "→ Dependencies: ${LIB_DIR}/libssl.a, libcrypto.a, libz.a"
echo "→ Headers: ${INCLUDE_DIR}/"
