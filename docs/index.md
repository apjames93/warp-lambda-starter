---
title: "Build a Serverless Rust API with Warp, Diesel, and AWS Lambda"
description: "How to deploy and run production-grade Rust APIs on AWS Lambda with PostgreSQL using Warp, Diesel, and SAM. Complete guide with CI/CD, Docker, and local testing."
---

# Build a Serverless Rust API with Warp, Diesel, and AWS Lambda

[![GitHub stars](https://img.shields.io/github/stars/apjames93/warp-lambda-starter?style=social)](https://github.com/apjames93/warp-lambda-starter)


> Run production-grade Rust APIs on AWS Lambda with PostgreSQL using Warp, Diesel, and AWS SAM—with full CI/CD and local testing support.


# Serverless Rust on AWS Lambda with Warp + Diesel

Learn how to build a serverless Rust API with Warp, Diesel, and AWS Lambda — complete with PostgreSQL support, CI/CD, Docker, and AWS SAM. This guide walks you through deploying a production-ready, async Rust backend that runs serverlessly on Lambda while connecting to a Postgres database using Diesel. Until recently, writing performant, native serverless APIs in Rust required heavy lifting. With the right tools, you can now deploy production-ready, async Rust backends to AWS Lambda—with PostgreSQL access and blazing-fast HTTP routing.

In this guide, we'll walk through a complete implementation of a serverless Rust backend using:

- **[Warp](https://github.com/seanmonstar/warp)**: a high-performance async HTTP server
- **[Diesel](https://diesel.rs)**: a safe, reliable ORM for PostgreSQL
- **[warp_lambda](https://crates.io/crates/warp_lambda)**: to adapt Warp to AWS Lambda
- **[AWS SAM](https://docs.aws.amazon.com/serverless-application-model/)**: to define and deploy your serverless stack
- **A custom `libpq` Lambda Layer**: to link Diesel with PostgreSQL in the Lambda environment

By the end, you’ll have a fully operational Rust API running on AWS Lambda, backed by PostgreSQL, with everything tested locally and deployable to the cloud.

---

## 💡 Why This Stack?

Rust’s safety and performance make it ideal for backend APIs. But Diesel (like many native crates) depends on C libraries like `libpq`, which aren't available by default in Lambda. This setup bridges that gap:

- Warp gives you a clean and async API layer
- Diesel handles safe and performant SQL access
- AWS SAM + Lambda offers serverless scale without server ops
- A Docker-built `libpq` layer satisfies native runtime/linking needs

Let’s build it.

---

## 📆 Getting Started

### Prerequisites
Make sure the following tools are installed:

```bash
brew install rustup awscli docker aws-sam-cli
cargo install cargo-lambda
```

Optional but recommended:
```bash
brew install act
```

> `act` lets you test GitHub Actions locally

---

## 🛠️ Clone the Starter Project

Everything in this guide is available in the open-source GitHub repo:

```bash
git clone https://github.com/apjames93/warp-lambda-starter.git
cd warp-lambda-starter
```

This starter includes:

- A working Warp + Diesel Rust app
- Custom `libpq` Lambda Layer for PostgreSQL support
- `Makefile` for local builds, testing, and deployment
- GitHub Actions CI pipeline
- AWS SAM config for infrastructure as code
- Local Postgres with Docker

👉 [View the repo on GitHub](https://github.com/apjames93/warp-lambda-starter)

---

## 🧱 Project Structure

```text
.
├── rust_app/                # Rust source code (Cargo.toml, main.rs, modules)
├── libpq_layer/            # Compiled libpq binaries and headers
├── build_libpq_layer_docker.sh    # Dockerized script to compile libpq
├── docker-compose.yaml     # Local Postgres (with pgvector)
├── Makefile                # Commands: build, lint, test, deploy
├── template.yaml           # AWS SAM function & layer definition
├── .github/workflows/ci.yml # Continuous integration tests & format checks
```

---

## 📏 Step-by-Step Implementation

Before diving in, it's helpful to understand how the included `Makefile` abstracts away some of the complexity of SAM builds—particularly with native dependencies like `libpq`.

### 1. Build the PostgreSQL Lambda Layer

Diesel requires `libpq` (the C Postgres client library). We'll compile it into a Lambda-compatible format:

```bash
./build_libpq_layer_docker.sh
```

> This uses an Amazon Linux 2 Docker image to match the Lambda runtime and produces `.so` and header files in `libpq_layer/`.

#### 🔍 What’s Going on with `LibpqLayer`

To support Diesel's `postgres` backend, we must compile the native `libpq` library into a Lambda-compatible shared object and make it available to the Lambda function. This is done through a custom Lambda Layer defined in `template.yaml`:

```yaml
LibpqLayer:
  Type: AWS::Serverless::LayerVersion
  Metadata:
    BuildMethod: makefile
    BuildArchitecture: x86_64
  Properties:
    ContentUri: .
    Description: PG deps for diesel
    CompatibleRuntimes:
      - provided.al2
    RetentionPolicy: Delete
```
This layer is built using the Makefile’s `build-LibpqLayer` target, which copies the compiled `.so` and header files into `.aws-sam/build/LibpqLayer/opt/lib` and `opt/include/libpq`, making them available to your Lambda function at runtime.

We mount this layer in our main function using:

```yaml
Layers:
  - !Ref LibpqLayer
```

And configure the required environment variables so that both `pq-sys` (at compile time) and Lambda (at runtime) can locate and link `libpq.so`:

```yaml
Environment:
  Variables:
    PQ_LIB_DIR: /opt/lib
    PQ_INCLUDE_DIR: /opt/include/libpq
    LD_LIBRARY_PATH: /opt/lib
```

At build time, `pq-sys` uses `PQ_LIB_DIR` and `PQ_INCLUDE_DIR`. At runtime, `LD_LIBRARY_PATH` ensures `libpq.so` can be dynamically loaded.

Also note: our `Cargo.toml` includes the following to map the SAM config:

```toml
[package]
default-run = "bootstrap"

[[bin]]
name = "bootstrap"
path = "src/main.rs"
```

This aligns with `cargo.toml`:

```yaml
artifact_executable_name: bootstrap
Handler: bootstrap
```

#### 🔧 What's in `build_libpq_layer_docker.sh`

The `build_libpq_layer_docker.sh` script automates the creation of this layer. Here's what it does:

1. Launches an `amazonlinux:2` Docker container
2. Installs build dependencies (`gcc`, `make`, `openssl-devel`, etc.)
3. Downloads PostgreSQL source (v10.23)
4. Builds just the `libpq` client library
5. Copies the resulting `.so` and headers into `libpq_layer/lib` and `libpq_layer/include/libpq`
6. Creates a symlink for `libpq.so`
7. Optionally zips the result for manual upload. AWS SAM will handle this when we deploy

This ensures that everything inside the `libpq_layer` folder is Lambda-compatible and can be reused across builds.

---

## 2. Start a Local Postgres DB (with pgvector)

This runs a local Postgres instance, ideal for dev + testing:

```bash
docker-compose up -d
```

Accessible at:

```
postgres://root:password@test-db:5001/test
```

---

## 3. Build the Rust Lambda Binary

```bash
make sam-build
```

What it does:

- **Sets environment variables** like `PQ_LIB_DIR` and `PQ_INCLUDE_DIR` so that Diesel’s `pq-sys` crate knows where to find the native PostgreSQL client libraries and headers
- **Adds a custom `RUSTFLAGS` setting** to embed a runtime linker path (`-rpath=/opt/lib`) that ensures Lambda can locate `libpq.so` during execution
- **Runs `sam build --beta-features`**, which compiles the Rust Lambda using `cargo lambda` and integrates the `libpq` layer into the build output structure
- **Fails early** if `libpq_layer/lib/libpq.so` is missing, prompting you to run `make sh-libpq` to generate the layer

This enables a seamless local and remote build experience, whether running locally via Docker or deploying to AWS.

---

## 4. Run Locally via SAM

```bash
make sam-run
```

Test your endpoint:

```
http://localhost:3000/Prod/hello
```

You'll see:

```json
{ "message": "Hello World with DB!" }
```

---

## 🔍 Inside the Rust App

### `main.rs`
Initializes the logger, logs environment setup, runs `init_diesel_pool()`, and starts the Warp server with Lambda support:

```rust
#[tokio::main]
async fn main() {
    // Setup tracing
    // Set panic hook
    // Log env vars like PQ_LIB_DIR
    init_diesel_pool();

    let routes = warp::path!("Prod" / "hello")
        .and(warp::get())
        .and_then(db_healthcheck_handler);

    warp_lambda::run(warp::service(routes)).await.expect("Failed to start");
}
```

### `lib.rs`
Exports core logic:

```rust
pub mod db;

pub use db::{get_db_conn, init_diesel_pool, run_diesel_query};
```

Also contains `db_healthcheck_handler()`:

```rust
pub async fn db_healthcheck_handler() -> Result<impl warp::Reply, warp::Rejection> {
    let result = timeout(Duration::from_secs(10), async {
        run_diesel_query(|conn| sql_query("SELECT 1").execute(conn).map(|_| ())).await
    })
    .await;
    // ... more code
}
```

### `db.rs`
Configures a global `PgPool` with `once_cell` and `r2d2`:

```rust
pub fn init_diesel_pool() {
    let manager = ConnectionManager::<PgConnection>::new(db_url);
    let pool = r2d2::Pool::builder().build(manager).unwrap();
    POOL.set(pool).unwrap();
}
```

### `healthcheck.rs`
Contains `test_hello_db_healthcheck`:

```rust
#[tokio::test]
async fn test_hello_db_healthcheck() {
    let _ = std::panic::catch_unwind(|| init_diesel_pool());

    let api = warp::path!("Prod" / "hello")
        .and(warp::get())
        .and_then(db_healthcheck_handler);

    let res = warp::test::request()
        .method("GET")
        .path("/Prod/hello")
        .reply(&api)
        .await;

    assert_eq!(res.status(), StatusCode::OK);
}
```

---

## 🧪 CI: Format, Lint, Test

Your `Makefile` supports:

```bash
make format     # rustfmt check
make lint       # clippy
make test       # run unit + integration tests
```

### GitHub Actions
Our `.github/workflows/ci.yml` GitHub Actions workflow runs automatically on push and pull requests to `main`. It:

- Spins up a Postgres 14 service
- Installs system dependencies (e.g., OpenSSL headers)
- Runs format and lint checks via `make pretty`
- Runs tests against a live database
- Installs and validates the AWS SAM CLI
- Caches dependencies and toolchains (Cargo, Zig)
- Builds the Lambda function using `make sam-build`

This provides confidence the project works before deploying, with consistent feedback during development.

---

## 📦 Dependencies Overview

```toml
[dependencies]
tokio = { version = "1", features = ["macros"] }
diesel = { version = "2.2.7", features = ["postgres", "r2d2"] }
warp = "0.3"
warp_lambda = "0.1.4"
tracing = { version = "0.1", features = ["log"] }
tracing-subscriber = { version = "0.3", default-features = false, features = ["fmt"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
openssl = { version = "0.10", features = ["vendored"] }
r2d2 = "0.8"
once_cell = "1"
```

---

## 🚀 Deploying to AWS

```bash
sam deploy --guided
```

Configure your stack, region, and IAM roles. Once complete, your endpoint will look like:

```
https://<gateway>.amazonaws.com/Prod/hello
```

---

## ✅ Final Thoughts

This pattern unlocks scalable, cost-effective Rust APIs with:

- No infrastructure to manage
- Native PostgreSQL support via Diesel
- High performance from Rust and Warp
- Full local dev/test + CI workflow

If this helped, consider sharing it or contributing. Happy shipping 🦀💨

---

---

## 🙌 Like this project?

If you found this guide helpful, please consider [⭐️ starring the repo on GitHub](https://github.com/apjames93/warp-lambda-starter) or [sharing it with your team](https://github.com/apjames93/warp-lambda-starter). Every star helps!

[![GitHub stars](https://img.shields.io/github/stars/apjames93/warp-lambda-starter?style=social)](https://github.com/apjames93/warp-lambda-starter)
