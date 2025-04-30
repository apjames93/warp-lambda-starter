# aws/Makefile
# Makefile for building and deploying the Rust-based AWS SAM application
# Includes support for building a custom libpq layer for Diesel/PostgreSQL

BACKEND_STACK_NAME ?= warp-lambda-starter-stack


build-sam:
		RUST_LOG=debug sam build


build-HelloWorldFunction:
	cp ${PWD}/../target/x86_64-unknown-linux-musl/release/backend ${ARTIFACTS_DIR}/bootstrap


# Build the LibpqLayer using the SAM `makefile` build method.
# Copies the static libpq.a and headers into the layer structure.
build-LibpqLayer:
	mkdir -p "$(ARTIFACTS_DIR)/lib"
	mkdir -p "$(ARTIFACTS_DIR)/include/libpq"
	cp libpq_layer/lib/libpq.a "$(ARTIFACTS_DIR)/lib/"
	cp -r libpq_layer/include/libpq/* "$(ARTIFACTS_DIR)/include/libpq/"

# Build the full SAM application, including all Lambda functions and layers.
# Uses statically linked libpq.a
sam-build:
	@echo "🔧 Building with libpq.a from project-local layer..."

	@test -f libpq_layer/lib/libpq.a || { echo "❌ libpq.a not found. Run 'make sh-libpq'"; exit 1; }

	PQ_LIB_DIR=$(realpath libpq_layer/lib) \
	PQ_INCLUDE_DIR=$(realpath libpq_layer/include/libpq) \
	RUSTFLAGS="-L $(realpath libpq_layer/lib) -lpq -static" \
	RUST_LOG=debug \
	sam build

# Build the SAM project and run it locally via the SAM CLI.
sam-run:
	@echo "Building SAM application..."
	make sam-build
	sam local start-api --docker-network sam-local --debug --env-vars env.json

# Build the libpq static archive and headers inside an Amazon Linux 2 container.
sh-libpq:
	sh ./build_libpq_layer_docker.sh

validate-sam:
	sam validate

# Validate, build, and deploy the full SAM stack to AWS.
deploy-sam:
	@echo "Validating SAM template..."
	sam validate

	@echo "Building SAM project..."
	make sam-build || { echo "Build failed"; exit 1; }

	@echo "Deploying SAM stack: $(BACKEND_STACK_NAME)..."
	sam deploy --stack-name $(BACKEND_STACK_NAME) \
		--force-upload \
		--no-confirm-changeset --no-fail-on-empty-changeset \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--resolve-s3 \
		--debug || { echo "Deployment failed."; exit 1; }

	@echo "Deployment completed successfully for stack: $(BACKEND_STACK_NAME)."

# Delete the deployed SAM stack from AWS without prompting.
delete-sam:
	sam delete --no-prompts --stack-name $(BACKEND_STACK_NAME)

# =======================================
# Utility Commands
# =======================================

format:
	@echo "Formatting all code..."
	(cd rust_app && cargo fmt --all)

lint:
	@echo "Linting all code..."
	(cd rust_app && cargo clippy --tests --all-features -- -D warnings)

pretty: format lint

test:
	(cd rust_app && DATABASE_URL=$${DATABASE_URL:-postgres://root:password@localhost:5001/test} cargo test --all --all-features -- --nocapture)

help:
	@echo "Available commands:"
	@echo "  make format     - Run rustfmt on all code"
	@echo "  make lint       - Run clippy and fail on warnings"
	@echo "  make test       - Run unit and integration tests"
	@echo "  make sam-build  - Build Lambda function using SAM"
	@echo "  make sam-run    - Run API locally via SAM"
	@echo "  make deploy-sam - Deploy to AWS"
