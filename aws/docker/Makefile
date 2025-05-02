# Get the absolute path to the project root (two levels up from aws/docker/)
REPO_ROOT := $(realpath $(CURDIR)/../..)

# ================================================================
# 🔧 build-sam: Builds the Rust backend binary and SAM artifacts
# ================================================================
build-sam:
	# 🐳 Build the Docker image used for compiling the Rust Lambda
	docker build --platform=linux/amd64 -t rust-sam-build -f Dockerfile.build-sam .

	# 🐳 Run the Docker container to compile and build the project
	# Mount entire project into /app in the container
	# Mount prebuilt libpq layer for static linking
	# Mount the build output dir for AWS SAM
	# Set working directory to /app/aws (where template.yaml lives)
	docker run --platform=linux/amd64 --rm \
		-v "$(REPO_ROOT)":/app \
		-v "$(REPO_ROOT)/aws/libpq_layer":/aws/libpq_layer \
		-v "$(REPO_ROOT)/aws/.aws-sam":/app/aws/.aws-sam \
		-w /app/aws \
		rust-sam-build \
		sh -c "\
		cd /app && \
		RUSTFLAGS='-L /aws/libpq_layer/lib \
			-C link-arg=-lpq \
			-C link-arg=-lssl \
			-C link-arg=-lcrypto \
			-C link-arg=-lz \
			-C link-arg=-static' \
		OPENSSL_NO_VENDOR=1 cargo build --release --target x86_64-unknown-linux-musl --bin backend && \
		sam build --template aws/template.yaml \
			--build-dir aws/.aws-sam \
			--cache-dir aws/.aws-sam/cache"

# ================================================================
# 🧱 sh-libpq: Builds a static libpq + OpenSSL layer inside Alpine
# ================================================================
# This builds the PostgreSQL C client library (libpq.a), along with
# static OpenSSL and zlib, for linking in musl-based Rust Lambda builds.
# Output is saved in: aws/libpq_layer/{lib/, include/}
sh-libpq:
	sh ./build_libpq_layer_docker.sh
