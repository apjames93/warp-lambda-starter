# build_libpq_layer_docker.sh

#!/bin/bash
set -e

# ─────────────────────────────────────────────────────────────────────────────
# Script: build_libpq_layer_docker.sh
#
# Builds the PostgreSQL `libpq.so` shared library and headers inside an
# Amazon Linux 2 container (Lambda-compatible). Outputs them to a `libpq_layer`
# directory structure compatible with AWS Lambda Layers.
#
# The resulting files will be used in:
#  - Lambda Layer at runtime (/opt/lib/libpq.so)
#  - Diesel's `pq-sys` crate at build time via PQ_LIB_DIR/PQ_INCLUDE_DIR
# ─────────────────────────────────────────────────────────────────────────────

LAYER_DIR=libpq_layer
LIB_DIR=${LAYER_DIR}/lib
INCLUDE_DIR=${LAYER_DIR}/include/libpq
PG_VERSION=10.23
PG_TARBALL=postgresql-${PG_VERSION}.tar.gz
PG_SRC_DIR=postgresql-${PG_VERSION}

# Clean up previous builds
rm -rf ${LAYER_DIR} ${PG_TARBALL} ${PG_SRC_DIR} libpq_layer.zip
mkdir -p ${LIB_DIR} ${INCLUDE_DIR}

docker run --rm \
  -v "$PWD":/layerbuild \
  -w /layerbuild \
  amazonlinux:2 bash -c "
  # Install build dependencies
  yum install -y gcc make tar gzip wget readline-devel zlib-devel openssl-devel zip &&
  
  # Download and extract PostgreSQL source
  wget https://ftp.postgresql.org/pub/source/v${PG_VERSION}/${PG_TARBALL} &&
  tar -xzf ${PG_TARBALL} &&

  # Configure and build only the libpq client library
  cd ${PG_SRC_DIR} &&
  ./configure --prefix=/tmp/pg --without-readline --without-zlib &&
  cd src/interfaces/libpq &&
  make &&
  make install &&

  # Copy output artifacts to host-mounted build directory
  cp /tmp/pg/lib/libpq.so* /layerbuild/${LIB_DIR}/ &&
  cp -r /tmp/pg/include/* /layerbuild/${INCLUDE_DIR}/
"

# Create symlink: libpq.so → libpq.so.5
echo '🔗 Creating .so symlink...'
cd ${LIB_DIR}
ln -sf libpq.so.5 libpq.so
cd - > /dev/null

# Optional: zip the layer for manual upload (not used by SAM builds)
echo '📦 Zipping the layer...'
(cd ${LAYER_DIR} && zip -r ../libpq_layer.zip .)

# Clean up downloaded and extracted PostgreSQL files
rm -rf ${PG_TARBALL} ${PG_SRC_DIR}

echo '✅ Layer build complete: `libpq_layer` directory is ready'
