#  Makefile

BACKEND_STACK_NAME ?= warp-lambda-starter-stack

build-LibpqLayer:
	mkdir -p "$(ARTIFACTS_DIR)/lib"
	mkdir -p "$(ARTIFACTS_DIR)/include/libpq"
	cp -r libpq_layer/lib/* "$(ARTIFACTS_DIR)/lib/"
	cp -r libpq_layer/include/libpq/* "$(ARTIFACTS_DIR)/include/libpq/"

sam-build:
	@echo "🔧 Building with libpq from layer build output..."
	PQ_LIB_DIR=$(PWD)/.aws-sam/build/LibpqLayer/opt/lib \
	PQ_INCLUDE_DIR=$(PWD)/.aws-sam/build/LibpqLayer/opt/include/postgresql \
	RUSTFLAGS="-C link-args=-Wl,-rpath=/opt/lib" \
	RUST_LOG=debug \
	sam build --beta-features


# Build and Run SAM Locally
sam-run:
	@echo "Building SAM application..."
	make sam-build
	sam local start-api --docker-network sam-local --debug --env-vars env.json

	
sh-libpq:
	sh ./build_libpq_layer_docker.sh

# Deploy SAM Stack
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

# Delete SAM Stack
delete-sam:
	sam delete --no-prompts --stack-name $(BACKEND_STACK_NAME)