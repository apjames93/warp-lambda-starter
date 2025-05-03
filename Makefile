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
