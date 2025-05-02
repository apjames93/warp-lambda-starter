REPO_ROOT := $(realpath $(CURDIR)/../..)

build-sam:
	docker build --platform=linux/amd64 -t rust-sam-build -f Dockerfile.build-sam .
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



sh-libpq:
	sh ./build_libpq_layer_docker.sh
