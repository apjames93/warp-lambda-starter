# aws/Makefile
# Makefile for building and deploying the Rust-based AWS SAM application
# Includes support for building a custom libpq layer for Diesel/PostgreSQL


# =======================================
# AWS SAM Build and Run Targets (Makefile)
# =======================================

# sam-run: runs the API locally via Lambda emulator
sam-run:
	@echo "Starting Local SAM application..."
	sam local start-api \
		--env-vars ./env.json \
		--docker-network sam-local \
		--debug \
		--port 4040


# full local run
sam-build-run:
	make docker-sam-build
	make sam-run

build-sam:
		RUST_LOG=debug sam build

build-HelloWorldFunction:
		cp /app/target/x86_64-unknown-linux-musl/release/backend ${ARTIFACTS_DIR}/bootstrap

# Build the LibpqLayer using the SAM `makefile` build method.
# Copies the static libpq.a and headers into the layer structure.
build-LibpqLayer:
	mkdir -p "$(ARTIFACTS_DIR)/lib"
	mkdir -p "$(ARTIFACTS_DIR)/include/libpq"
	cp libpq_layer/lib/libpq.a "$(ARTIFACTS_DIR)/lib/"
	cp -r libpq_layer/include/libpq/* "$(ARTIFACTS_DIR)/include/libpq/"

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
