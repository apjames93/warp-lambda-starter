# aws/Makefile
# ------------------------------------------------------------------------------
# Makefile for building and deploying the Rust-based AWS SAM application.
# This file provides targets for:
#   - Building the Lambda binary using Docker with static linking
#   - Compiling and packaging the libpq Lambda layer for Diesel
#   - Running the Lambda API locally via SAM CLI
#   - Deploying and deleting the AWS SAM stack
# ------------------------------------------------------------------------------

# Include Makefile from the docker/ subdirectory relative to this file
include $(dir $(lastword $(MAKEFILE_LIST)))docker/Makefile
DOCKER_MAKE = $(MAKE) -C docker

# Forward docker-* targets to the docker/Makefile
docker-%:
	@echo "Delegating to docker/$*..."
	$(DOCKER_MAKE) $*

# =======================================
# AWS SAM Build and Run Targets
# =======================================

# Build the Lambda binary using a Docker image
build-sam:
	@echo "Building SAM project..."
	rm -rf .aws-sam
	mkdir -p .aws-sam
	make docker-build-sam

# Run the Lambda locally using SAM CLI and the provided env.json config
run-sam:
	@echo "Starting Local SAM application from aws/..."
	sam local start-api \
		--template .aws-sam/template.yaml \
		--env-vars env.json \
		--docker-network sam-local \
		--debug \
		--port 4040

# Validate the SAM template syntax and structure
validate-sam:
	@echo "Validating SAM template..."
	sam validate

# =======================================
# Deploy & Cleanup Targets
# =======================================

# Name of the AWS CloudFormation stack to create/update
BACKEND_STACK_NAME ?= warp-lambda-starter-stack

# Validate, build, and deploy the Lambda stack to AWS
deploy-sam: validate-sam build-sam
	@echo "Deploying SAM stack: $(BACKEND_STACK_NAME)..."
	sam deploy --stack-name $(BACKEND_STACK_NAME) \
		--force-upload \
		--no-confirm-changeset --no-fail-on-empty-changeset \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--resolve-s3 \
		--debug || { echo "Deployment failed."; exit 1; }

	@echo "Deployment completed successfully for stack: $(BACKEND_STACK_NAME)."

# Delete the deployed AWS stack without any confirmation prompts
delete-sam:
	sam delete --no-prompts --stack-name $(BACKEND_STACK_NAME)

# =======================================
# Layer & Build Method Targets
# =======================================

# Copy the compiled backend binary into the Lambda-compatible bootstrap file
# Used by SAM's makefile-based build method
build-BackendFunction:
	cp /app/target/x86_64-unknown-linux-musl/release/backend ${ARTIFACTS_DIR}/bootstrap

# Copy libpq static libraries and headers into the appropriate layer directories
# Used by SAM to package and attach the PostgreSQL C client libraries as a Lambda Layer
build-LibpqLayer:
	mkdir -p "$(ARTIFACTS_DIR)/lib"
	mkdir -p "$(ARTIFACTS_DIR)/include/libpq"
	cp libpq_layer/lib/libpq.a "$(ARTIFACTS_DIR)/lib/"
	cp -r libpq_layer/include/libpq/* "$(ARTIFACTS_DIR)/include/libpq/"
