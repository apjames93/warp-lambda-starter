# aws/Makefile

# aws/Makefile
# Makefile for building and deploying the Rust-based AWS SAM application
# Includes support for building a custom libpq layer for Diesel/PostgreSQL

include $(dir $(lastword $(MAKEFILE_LIST)))docker/Makefile
DOCKER_MAKE = $(MAKE) -C docker

docker-%:
	@echo "Delegating to docker/$*..."
	$(DOCKER_MAKE) $*

# =======================================
# AWS SAM Build and Run Targets (Makefile)
# =======================================

build-sam:
		make docker-build-sam

# sam-run: runs the API locally via Lambda emulator
run-sam:
	@echo "Starting Local SAM application from aws/..."
	sam local start-api \
		--template .aws-sam/template.yaml \
		--env-vars env.json \
		--docker-network sam-local \
		--debug \
		--port 4040

build-BackendFunction:
		cp /app/target/x86_64-unknown-linux-musl/release/backend ${ARTIFACTS_DIR}/bootstrap

# Build the LibpqLayer using the SAM `makefile` build method.
# Copies the static libpq.a and headers into the layer structure.
build-LibpqLayer:
	mkdir -p "$(ARTIFACTS_DIR)/lib"
	mkdir -p "$(ARTIFACTS_DIR)/include/libpq"
	cp libpq_layer/lib/libpq.a "$(ARTIFACTS_DIR)/lib/"
	cp -r libpq_layer/include/libpq/* "$(ARTIFACTS_DIR)/include/libpq/"

validate-sam:
	sam validate

# Validate, build, and deploy the full SAM stack to AWS.
deploy-sam:
	@echo "Validating SAM template..."
	sam validate

	@echo "Building SAM project..."
	make build-sam || { echo "Build failed"; exit 1; }

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
