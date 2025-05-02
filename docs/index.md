---

title: "Build a Serverless Rust API with Warp, Diesel, and AWS Lambda"
description: "How to deploy and run production-grade Rust APIs on AWS Lambda with PostgreSQL using Warp, Diesel, and SAM. Now featuring custom Docker builds, static linking, and full local dev workflows."
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Build a Serverless Rust API with Warp, Diesel, and AWS Lambda

[![GitHub stars](https://img.shields.io/github/stars/apjames93/warp-lambda-starter?style=social)](https://github.com/apjames93/warp-lambda-starter)

> Learn how to deploy production-ready, statically-linked Rust APIs on AWS Lambda with PostgreSQL, Docker, and AWS SAM. Includes CI/CD, hot reloads for local dev, and cross-compilation using custom Docker images.

---

## 🚀 Overview

This guide shows how to build a modern, production-grade Rust API using:

* **[Warp](https://github.com/seanmonstar/warp)**: A fast, async HTTP server
* **[Diesel](https://diesel.rs)**: A powerful ORM for PostgreSQL
* **[warp\_lambda](https://crates.io/crates/warp_lambda)**: Adapts Warp for AWS Lambda
* **AWS SAM**: For packaging, building, and deploying to Lambda
* **Custom Docker image builds**: For static compilation and linking
* **A Lambda Layer for runtime C dependencies**: Including `libpq`, `libssl`, `libz`, etc.

Unlike most tutorials, we build a **fully statically linked Rust Lambda binary**, integrate PostgreSQL support via Diesel, and leverage a Lambda Layer for required C libraries at runtime.

---

## 🛠️ Getting Started

### Prerequisites

Make sure the following tools are installed:

```bash
brew install rustup awscli docker aws-sam-cli
```

> Optional:

```bash
cargo install cargo-watch  # for hot reloads
brew install act           # for testing GitHub Actions locally
```

---

## 📦 Clone the Starter Project

```bash
git clone https://github.com/apjames93/warp-lambda-starter.git
cd warp-lambda-starter
```

The repo includes:

* Fully working Warp + Diesel backend
* AWS SAM templates
* Dockerfiles for cross-compilation
* Hot-reloading dev server
* `libpq_layer` builder script
* GitHub Actions CI/CD pipeline

---

## 🧱 Project Layout

```text
.
├── backend/                # Rust source (Warp + Diesel)
├── aws/                   # SAM template, layer build, Docker Makefiles
├── aws/libpq_layer/       # Statically built libpq + OpenSSL
├── aws/.aws-sam/          # SAM build output
├── aws/docker/build_libpq_layer_docker.sh  # Layer builder script
├── aws/docker/Dockerfile.build-sam   # Static Rust cross-compilation
├── docker-compose.yaml    # Local Postgres (with pgvector)
├── Makefile               # Orchestrator (build, run, deploy)
└── .github/workflows/     # CI/CD
```


## 🐘 Local PostgreSQL with Docker Compose

We provide a `docker-compose.yaml` file to launch a local Postgres instance for development. It uses the `pgvector`-enabled image and exposes the database on port `5001`.

```yaml
services:
  postgres:
    image: ankane/pgvector:latest
    container_name: test-db
    environment:
      POSTGRES_DB: test
      POSTGRES_USER: root
      POSTGRES_PASSWORD: password
    ports:
      - "5001:5432"
    networks:
      - sam-local
    volumes:
      - test-pg-data:/var/lib/postgresql/data
```

This database can be accessed via:

```text
postgres://root:password@localhost:5001/test
```

When running under AWS SAM, the function is connected to the Docker network `sam-local` and uses this env config (`aws/env.json`):

```json
{
  "HelloWorldFunction": {
    "PQ_LIB_DIR": "/opt/lib",
    "PQ_INCLUDE_DIR": "/opt/include/libpq",
    "LD_LIBRARY_PATH": "/opt/lib",
    "RUST_LOG": "debug",
    "PGSSLMODE": "disable",
    "RUST_BACKTRACE": "1",
    "DATABASE_URL": "postgres://root:password@test-db:5432/test?sslmode=disable"
  }
}
```

> The `test-db` hostname works inside SAM containers due to the shared `sam-local` network.

---

## 🧪 Build the Libpq Layer for Diesel

Diesel requires the native `libpq` C client. We compile it into a portable layer using a shell script:

```bash
make aws-docker-sh-libpq
```

This calls `build_libpq_layer_docker.sh`, which:

* Uses Alpine in Docker to compile `libpq.a`, `libssl.a`, and dependencies
* Places them in `aws/libpq_layer/{lib,include}`
* Cleans up the build after copying artifacts

These files are later used both during **build-time static linking** and **runtime via the Lambda Layer**.

---

## 🧰 Static Linking with Custom Docker Build

We compile the Rust Lambda binary using a dedicated Docker image defined in `Dockerfile.build-sam`. Inside it:

* We install the `musl` toolchain

* Set custom `RUSTFLAGS` to statically link native deps:

  ```
  RUSTFLAGS="-L /aws/libpq_layer/lib \
    -C link-arg=-lpq \
    -C link-arg=-lssl \
    -C link-arg=-lcrypto \
    -C link-arg=-lz \
    -C link-arg=-static"
  ```

* Add build-time env vars `PQ_LIB_DIR`, `OPENSSL_NO_VENDOR=1`, etc.

* Output a statically-linked binary compatible with Lambda

```bash
make aws-build-sam
```

This uses the Docker container to:

* Compile the Lambda binary
* Run `sam build` to package the app

---

## 🧱 Runtime Dependencies via Lambda Layer

Even with static linking, Lambda still expects dynamic dependencies like `libpq.so` to be available at runtime. We solve this with a Lambda Layer:

* Defined in `aws/template.yaml`
* Packaged with the static libs via `build-LibpqLayer`
* Mounted into the function at `/opt`

Lambda is configured with:

```yaml
Environment:
  Variables:
    LD_LIBRARY_PATH: /opt/lib
    PQ_LIB_DIR: /opt/lib
    PQ_INCLUDE_DIR: /opt/include/libpq
```

This makes sure runtime linking works even in the `provided.al2` Lambda environment.

---

## 🌐 Run the API Locally via SAM

To run your Lambda locally:

```bash
make aws-run-sam
```

Then hit:

```
http://localhost:4040/Prod/hello
```

You'll see:

```json
{ "message": "Hello World with DB!" }
```

---

---

## 🔄 Local Development with Hot Reloads

Use the local `cargo-watch` setup to run the Warp API locally with hot reloading:

```bash
make run-backend
```

This spins up your Warp server with auto-recompilation on file changes:

```text
http://localhost:3000/Prod/hello
```

This setup bypasses Lambda entirely for fast development feedback.

---

## ☁️ Deploy to AWS

```bash
make aws-deploy-sam
```

* This calls `sam deploy`
* Uploads the statically linked binary and layer to AWS
* Provisions your API Gateway and Lambda functions

---

## 🧪 CI/CD with GitHub Actions

CI runs `make aws-build-sam` and `make aws-deploy-sam` on push to `main`. It also lints, formats, and tests:

* Caches build artifacts and SAM layers
* Runs inside a clean container
* Validates SAM template
* Builds using Docker to ensure consistency with local flow

Test locally with:

```bash
act push -W .github/workflows/ci.yaml --secret-file .env
```

---

---

If you want to clean up your stack after testing or deployment:

`make aws-delete-sam`

This deletes the deployed stack using sam delete --no-prompts

---

## 📚 Summary

With this setup, you can:

* Develop locally with hot reloads
* Cross-compile statically linked Rust Lambda functions
* Build and package `libpq` layers for Diesel
* Run and test locally via SAM
* Deploy with confidence to AWS Lambda
* Automate it all with CI/CD

No server ops. Just blazing-fast, safe Rust APIs that scale.

🦀 Happy building!
