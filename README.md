# [Github Pages Warp Lambda Starter](https://apjames93.github.io/warp-lambda-starter/)

# 🚀 SAM Rust + Warp + Diesel on Lambda

This project demonstrates a fully serverless Rust backend architecture running on AWS Lambda, powered by:

- 🌐 [Warp](https://github.com/seanmonstar/warp) — ergonomic, high-performance HTTP server
- 🛢️ [Diesel](https://diesel.rs/) — production-ready ORM for PostgreSQL
- 🔌 [`warp_lambda`](https://crates.io/crates/warp_lambda) — seamlessly adapt Warp filters for Lambda
- 🧱 [AWS SAM](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html) — serverless framework to define and deploy the stack
- 📦 `libpq` Lambda layer — compiled from source to support Diesel's PostgreSQL backend on Lambda

---

## 🔧 Prerequisites

Ensure the following tools are installed:

- [Rust](https://www.rust-lang.org/tools/install)
- [Cargo Lambda](https://github.com/cargo-lambda/cargo-lambda)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)
- [Docker](https://www.docker.com/products/docker-desktop)
- [Docker Compose](https://docs.docker.com/compose/)
- [`act`](https://github.com/nektos/act) (optional, for running GitHub Actions locally)

---

## 📁 Project Structure

```bash
.
├── rust_app/                # Rust source (Cargo.toml, main.rs, handlers, etc.)
├── libpq_layer/            # Compiled libpq.so + headers for Lambda
├── libpq_layer.zip         # Zipped Lambda layer (optional manual upload)
├── build_libpq_layer.sh    # Script to compile the layer inside Amazon Linux 2
├── docker-compose.yaml     # Local PostgreSQL with pgvector extension
├── env.json                # SAM local environment config
├── template.yaml           # AWS SAM template defining function and layer
├── Makefile                # Helper tasks for build, test, deploy
```

---

## ✅ Features

- `GET /Prod/hello`: healthcheck endpoint
- Executes `SELECT 1` on PostgreSQL via Diesel
- Async server using `tokio`, with `spawn_blocking` for Diesel
- Connection pooling with `r2d2`
- Robust tracing logs for full request lifecycle

---

## 🛠️ Setup & Local Development

### 1. Build the libpq Lambda Layer

```bash
./build_libpq_layer.sh
```

This script:
- Uses Docker (Amazon Linux 2) to compile PostgreSQL’s client library (`libpq`)
- Extracts headers and `.so` files
- Produces a ready-to-use Lambda layer structure under `libpq_layer/`
- Zips it as `libpq_layer.zip` (optional)

### 2. Start PostgreSQL Locally

```bash
docker-compose up -d
```

- Exposes `postgres://root:password@test-db:5432/test`
- Includes `pgvector` extension
- Waits for readiness with `pg_isready`

### 3. Build the Lambda Function

```bash
make sam-build
```

This runs `sam build` with the correct Rust target and environment configuration.

### 4. Run Locally

```bash
make sam-run
```

Then visit:

```
http://127.0.0.1:3000/Prod/hello
```

Expected response:

```json
{ "message": "Hello World with DB!" }
```

On failure, a descriptive error is returned with full logs via `tracing`.

---

## 🧪 Testing

The `/Prod/hello` route performs:

- A pooled DB connection
- A `SELECT 1` SQL query
- Full logging of success/failure with `tokio::timeout` handling

---

## 🌐 API Gateway Routing

SAM uses a `/{proxy+}` path in `template.yaml`:

```yaml
Path: /{proxy+}
Method: ANY
```

This allows Warp to handle all routing. Example route in `main.rs`:

```rust
warp::path!("Prod" / "hello")
```

SAM adds the `Prod` stage automatically — always include it in local or deployed endpoints.

---

## 📦 Dependencies

Highlights from [`Cargo.toml`](./rust_app/Cargo.toml):

- `warp` + `warp_lambda` — web + Lambda adapter
- `diesel` + `r2d2` — DB access + connection pooling
- `tokio` — async runtime
- `openssl` — bundled with `vendored` for static compatibility
- `serde`, `serde_json` — JSON serialization
- `tracing`, `tracing-subscriber` — structured logging

---

## 🚀 Deployment

Deploy to AWS with:

```bash
sam deploy --guided
```

Follow prompts to configure the stack name, region, and IAM roles. The Lambda function and the `libpq` layer will be deployed together.

---

## 🧼 Cleanup

To stop local Docker containers:

```bash
docker-compose down
```

---

## ✅ CI/CD

GitHub Actions (`ci.yaml`) supports:

- Caching for Rust + Docker layers
- libpq layer build
- Lambda binary compilation via `cargo lambda`
- `sam build` validation

To test locally:

```bash
act -P ubuntu-22.04=catthehacker/ubuntu:act-22.04
```

See: [`./.github/workflows/ci.yaml`](./.github/workflows/ci.yaml)

---

## ✨ Credits

Special thanks to the maintainers of:

- [`warp`](https://github.com/seanmonstar/warp)
- [`warp_lambda`](https://github.com/aslamplr/warp_lambda)
- [`cargo-lambda`](https://github.com/cargo-lambda/cargo-lambda)
- [`aws-lambda-rust-runtime`](https://github.com/awslabs/aws-lambda-rust-runtime)

---



cargo install cross --git https://github.com/cross-rs/cross --branch main --force
export CROSS_CONTAINER_ENGINE=docker