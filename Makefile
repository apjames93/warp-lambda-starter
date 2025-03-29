# Makefile for building and deploying the Rust-based AWS SAM application
# Includes support for building a custom libpq layer for Diesel/PostgreSQL

BACKEND_STACK_NAME ?= warp-lambda-starter-stack

# Build the LibpqLayer using the SAM `makefile` build method.
# This is invoked by SAM when building the LibpqLayer defined in template.yaml.
# It copies prebuilt libpq shared objects and headers from our local `libpq_layer/` folder
# into the correct layer output directory (defined by $ARTIFACTS_DIR),
# where they will be placed in `/opt` at runtime in the Lambda environment.
build-LibpqLayer:
	mkdir -p "$(ARTIFACTS_DIR)/lib"
	mkdir -p "$(ARTIFACTS_DIR)/include/libpq"
	cp -r libpq_layer/lib/* "$(ARTIFACTS_DIR)/lib/"
	cp -r libpq_layer/include/libpq/* "$(ARTIFACTS_DIR)/include/libpq/"

# Build the full SAM application, including all Lambda functions and layers.
# This sets the required environment variables so `pq-sys` can link against the local libpq shared library.
# The paths are resolved to absolute paths to ensure the build works regardless of working directory.
sam-build:
	@echo "🔧 Building with libpq from project-local layer..."

	@test -f libpq_layer/lib/libpq.so || { echo "❌ libpq.so not found. Run 'make sh-libpq'"; exit 1; }

	PQ_LIB_DIR=$(realpath libpq_layer/lib) \
	PQ_INCLUDE_DIR=$(realpath libpq_layer/include/libpq) \
	RUSTFLAGS="-C link-args=-Wl,-rpath=/opt/lib" \
	RUST_LOG=debug \
	sam build --beta-features

# Build the SAM project and run it locally via the SAM CLI.
# This allows you to test the Lambda functions using Docker on your machine.
sam-run:
	@echo "Building SAM application..."
	make sam-build
	sam local start-api --docker-network sam-local --debug --env-vars env.json

# Build the libpq shared libraries and headers inside an Amazon Linux 2 container.
# This mimics the Lambda environment and ensures binary compatibility.
# Output is placed in `libpq_layer/lib` and `libpq_layer/include/libpq`.
sh-libpq:
	sh ./build_libpq_layer_docker.sh

# Validate, build, and deploy the full SAM stack to AWS.
# This will upload the Lambda functions and layers, create/update resources,
# and deploy the API Gateway with no manual confirmations.
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

# Format all code
format:
	@echo "Formatting all code..."
	(cd rust_app && cargo fmt --all)

# Lint all code
lint:
	@echo "Linting all code..."
	(cd rust_app && cargo clippy --tests --all-features -- -D warnings)

# Format and lint code
pretty: format lint