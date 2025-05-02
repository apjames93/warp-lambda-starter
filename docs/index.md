---

title: "Build a Serverless Rust API with Warp, Diesel, and AWS Lambda"
description: "How to deploy and run production-grade Rust APIs on AWS Lambda with PostgreSQL using Warp, Diesel, and SAM. Now featuring custom Docker builds, static linking, and full local dev workflows."
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Build a Serverless Rust API with Warp, Diesel, and AWS Lambda

[![GitHub stars](https://img.shields.io/github/stars/apjames93/warp-lambda-starter?style=social)](https://github.com/apjames93/warp-lambda-starter)

> A production-grade setup to deploy Rust APIs to AWS Lambda using Warp, Diesel, Docker, and AWS SAM.

---

## 🚀 Overview

This guide covers:

* **Warp**: Fast async web server
* **Diesel**: Battle-tested ORM for PostgreSQL
* **warp\_lambda**: Runs Warp on AWS Lambda
* **AWS SAM**: Infrastructure-as-code for Lambda + API Gateway
* **Custom Docker builds**: For cross-compilation and static linking
* **Lambda Layer**: Ships runtime C deps like `libpq`

---

## 🛠️ Prerequisites

Install these tools:

```bash
brew install rustup awscli docker aws-sam-cli
cargo install cargo-watch       # for hot reloads
brew install act                # optional: test CI locally
```

---

## 📦 Clone the Starter

```bash
git clone https://github.com/apjames93/warp-lambda-starter.git
cd warp-lambda-starter
```

You'll get:

* Warp + Diesel backend
* Docker-based builds
* AWS SAM template + Lambda Layer
* CI/CD via GitHub Actions
* Local dev with hot reloads

---

## 🧱 Project Structure

```text
.
├── backend/                # Rust source
├── aws/                   # SAM template, Docker builds
├── aws/libpq_layer/       # Prebuilt libpq + OpenSSL
├── docker-compose.yaml    # Local Postgres
├── Makefile               # Build/run shortcuts
└── .github/workflows/     # CI pipeline
```

---

## 🐘 Local Postgres with Docker Compose

Run PostgreSQL (pgvector-enabled) locally:

```bash
docker-compose up
```

Access it via:

```
postgres://root:password@localhost:5001/test
```

Inside SAM (Docker network `sam-local`):

```json
"DATABASE_URL": "postgres://root:password@test-db:5432/test?sslmode=disable"
```

---

## 🧪 Build the libpq Lambda Layer

> **Quick start:** The `aws/libpq_layer/` directory is pre-committed so you can start building and deploying immediately.
>
> **Advanced:** If you want to regenerate the layer (e.g. for a different PostgreSQL version, security updates, or reduced size), run:

```bash
make aws-docker-sh-libpq
```

This command:

* Builds `libpq.a`, `libssl.a`, and headers using Alpine + musl
* Outputs everything to `aws/libpq_layer/{lib, include}`
* Packages the layer as `libpq_layer.zip` for AWS Lambda use

You’re free to customize or rebuild the layer anytime—just modify `aws/docker/build_libpq_layer_docker.sh`.

Rebuild if:

* You need a newer PostgreSQL version
* You want smaller artifacts
* You hit Lambda runtime linking errors

---

## 🧰 Build the Statically Linked Rust Binary

Compile for Lambda using a dedicated Dockerfile:

```bash
make aws-build-sam
```

* Uses `musl` toolchain
* Statically links `libpq`, `libssl`, `zlib`
* Outputs `bootstrap` binary
* Runs `sam build` to package it

Set in Docker:

```bash
RUSTFLAGS="-L /aws/libpq_layer/lib \
  -C link-arg=-lpq -C link-arg=-lssl -C link-arg=-lcrypto \
  -C link-arg=-lz -C link-arg=-static"
```

---

## 🔧 Local Dev vs Lambda Mode

Your `main.rs` supports both:

```rust
#[cfg(feature = "lambda")]
warp_lambda::run(service).await?;

#[cfg(not(feature = "lambda"))]
warp::serve(routes).run(([0, 0, 0, 0], 3000)).await;
```

In `Cargo.toml`:

```toml
[features]
default = ["lambda"]
lambda = ["lambda_http", "lambda_runtime"]
```

So you can:

* Run locally with `cargo run`
* Deploy with `make aws-build-sam`

---

## 🔗 Why the Lambda Layer Is Still Needed

Even with static linking, Lambda may expect `.so` files at runtime:

* Diesel sometimes loads symbols dynamically
* Musl quirks can cause fallback dynamic linking

To ensure compatibility, we attach the same static artifacts as a Lambda Layer:

```yaml
Layers:
  - !Ref LibpqLayer
Environment:
  Variables:
    LD_LIBRARY_PATH: /opt/lib
    PQ_LIB_DIR: /opt/lib
    PQ_INCLUDE_DIR: /opt/include/libpq
```

🧠 **Lightbulb moment**: Build-time and runtime use the exact same files. No duplication. No surprises.

---

## 🔄 Local Dev with Hot Reloads

Run the API locally with:

```bash
make run-backend
```

This:

* Starts Warp on `localhost:3000`
* Watches files via `cargo-watch`

Great for development without SAM overhead.

---

## 🌐 Test Locally with SAM

Test your Lambda function locally via Docker:

```bash
make aws-run-sam
```

Visit:

```
http://localhost:4040/Prod/hello
```

---

## ☁️ Deploy to AWS

Deploy your app with:

```bash
make aws-deploy-sam
```

This runs `sam deploy` and provisions:

* Lambda function (with `Handler: bootstrap`)
* API Gateway endpoint
* Attached Lambda Layer

---

## 🔄 CI/CD Pipeline

GitHub Actions CI runs on push to `main`:

* Builds with `make aws-build-sam`
* Runs `make aws-deploy-sam`
* Validates SAM templates

Test locally with:

```bash
act push \
  -W .github/workflows/ci.yaml \
  --secret-file .env \
  -P ubuntu-22.04=catthehacker/ubuntu:act-22.04
```

---

## ✅ Summary

* ⌨️ Local dev with hot reloads using `cargo-watch`
* 🐳 Cross-compiled builds with musl in Docker
* 📦 Precompiled `libpq` layer for Diesel and OpenSSL
* 🔁 Shared artifacts for build and runtime environments
* 🚀 Seamless deployment to AWS Lambda via SAM

**Why this setup works:**

* **🔁 Reuse is power** – the same `.a` and `.h` files power both phases
* **🦀 Native performance** – statically linked with `musl`, optimized for cold starts
* **🌐 Local-first DX** – develop like a normal Warp app, deploy serverlessly

---

## 🧭 Next Steps (Coming Soon)

* Set up full AWS infrastructure via CloudFormation (VPC, RDS, subnets, security groups)
* Add RDS Proxy for pooled DB connections from Lambda
* Support custom domains via API Gateway and Certbot in SAM
* Use AWS Secrets Manager for storing credentials like `DATABASE_URL`
* Add test flows for `/hello` route with `curl`/Postman examples

---

🦀 A solid foundation for production-ready, serverless Rust APIs.

**Happy building!**
