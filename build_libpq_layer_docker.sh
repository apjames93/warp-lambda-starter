# build_libpq_layer_docker.sh

#!/bin/bash
set -e

LAYER_DIR=libpq_layer
LIB_DIR=${LAYER_DIR}/lib
INCLUDE_DIR=${LAYER_DIR}/include/libpq
PG_VERSION=10.23

# Clean up
rm -rf ${LAYER_DIR} libpq_layer.zip
mkdir -p ${LIB_DIR} ${INCLUDE_DIR}

docker run --rm \
  -v "$PWD":/layerbuild \
  -w /layerbuild \
  amazonlinux:2 bash -c "
  yum install -y gcc make tar gzip wget readline-devel zlib-devel openssl-devel zip &&
  PG_VERSION=${PG_VERSION} && \
  wget https://ftp.postgresql.org/pub/source/v\$PG_VERSION/postgresql-\$PG_VERSION.tar.gz && \
  tar -xzf postgresql-\$PG_VERSION.tar.gz && \
  cd postgresql-\$PG_VERSION && \ 
  ./configure --prefix=/tmp/pg --without-readline --without-zlib && \
  cd src/interfaces/libpq && \
  make && \
  make install && \
  cp /tmp/pg/lib/libpq.so* /layerbuild/${LIB_DIR}/ && \
  cp -r /tmp/pg/include/* /layerbuild/${INCLUDE_DIR}/
"

# Create .so symlink
echo '🔗 Creating .so symlink...'
cd ${LIB_DIR}
ln -sf libpq.so.5 libpq.so
cd - > /dev/null

# Zip the layer
echo '📦 Zipping the layer...'
(cd ${LAYER_DIR} && zip -r ../libpq_layer.zip .)

echo '✅ Layer package built as libpq_layer.zip'
