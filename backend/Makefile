# Backend-specific Makefile

build:
	@echo "Building Rust backend (server + job_runner)..."
	cargo build --release --manifest-path ./Cargo.toml

run:
	@echo "Running Warp server..."
	cd ../ && export $$(cat .env | xargs) && RUST_LOG=debug cargo run --manifest-path backend/Cargo.toml --no-default-features
