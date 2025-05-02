# Makefile

# =======================================
# Root Makefile: Orchestrator
# =======================================

### Include submodule Makefiles
include backend/Makefile
include aws/Makefile

# =======================================
# Directory-specific Commands
# =======================================

AWS_MAKE = $(MAKE) -C aws
BACKEND_MAKE = $(MAKE) -C backend

# AWS commands delegation
aws-%:
	@echo "Delegating to aws/$*..."
	$(AWS_MAKE) $*

# # Backend commands delegation
be-%:
	@echo "Delegating to backend/$*..."
	$(BACKEND_MAKE) $*

# =======================================
# Utility Commands
# =======================================

# Format all code (including fixing simple style issues)
format:
	@echo "Formatting all code with cargo fmt..."
	cargo fmt --all

# Lint all code with clippy and suggest fixes where possible
lint:
	@echo "Linting all code with cargo clippy..."
	cargo clippy --workspace --all-targets --all-features --fix --allow-dirty --allow-staged -- -D warnings

# Format and lint
pretty: format lint

# =======================================
# Project Orchestration
# =======================================

run-backend:
	cargo watch -p backend -w backend/src -s 'make be-run'

# SAM stuff
# =======================================


docker-sam-build:
	docker build --platform=linux/amd64 -t rust-sam-build -f aws/docker/Dockerfile.build-sam .
	docker run --platform=linux/amd64 --rm \
		-v "$(shell pwd)":/app \
		-v "$(shell pwd)/aws/libpq_layer":/aws/libpq_layer \
		-v "$(shell pwd)/aws/.aws-sam":/app/aws/.aws-sam \
		-w /app \
		rust-sam-build \
		sh -c "\
		RUSTFLAGS='-L /aws/libpq_layer/lib \
			-C link-arg=-lpq \
			-C link-arg=-lssl \
			-C link-arg=-lcrypto \
			-C link-arg=-lz \
			-C link-arg=-static' \
		OPENSSL_NO_VENDOR=1 cargo build --release --target x86_64-unknown-linux-musl --bin backend && \
		sam build --template aws/template.yaml"

		sam local start-api \
		--env-vars ./aws/env.json \
		--docker-network sam-local \
		--debug \
		--port 4040

