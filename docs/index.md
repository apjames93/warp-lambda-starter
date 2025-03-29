# Serverless Rust on AWS Lambda with Warp + Diesel

Serverless computing is transforming backend development—cutting costs, scaling on demand, and eliminating infrastructure management. But until recently, writing performant, native serverless APIs in Rust required heavy lifting. With the right tools, you can now deploy production-ready, async Rust backends to AWS Lambda—with PostgreSQL access and blazing-fast HTTP routing.

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

## 🧱 Project Structure

```text
.
├── rust_app/                # Rust source code (Cargo.toml, main.rs)
├── libpq_layer/            # Compiled libpq binaries and headers
├── build_libpq_layer.sh    # Dockerized script to compile libpq
├── docker-compose.yaml     # Local Postgres (with pgvector)
├── Makefile                # Commands: build, test, deploy
├── template.yaml           # AWS SAM function & layer definition
```

---

## 📏 Step-by-Step Implementation

Before diving in, it's helpful to understand how the included `Makefile` abstracts away some of the complexity of SAM builds—particularly with native dependencies like `libpq`.

### 1. Build the PostgreSQL Lambda Layer

Diesel requires `libpq` (the C Postgres client library). We'll compile it into a Lambda-compatible format:

```bash
./build_libpq_layer.sh
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

At build time, `pq-sys` uses `PQ_LIB_DIR` and `PQ_INCLUDE_DIR`.
At runtime, `LD_LIBRARY_PATH` ensures `libpq.so` can be dynamically loaded.

#### 🔧 What's in `build_libpq_layer.sh`

The `build_libpq_layer.sh` script automates the creation of this layer. Here's what it does:

1. Launches an `amazonlinux:2` Docker container
2. Installs build dependencies (`gcc`, `make`, `openssl-devel`, etc.)
3. Downloads PostgreSQL source (v10.23)
4. Builds just the `libpq` client library
5. Copies the resulting `.so` and headers into `libpq_layer/lib` and `libpq_layer/include/libpq`
6. Creates a symlink for `libpq.so`
7. Optionally zips the result for manual upload

This ensures that everything inside the `libpq_layer` folder is Lambda-compatible and can be reused across builds.

---

## 2. Start a Local Postgres DB (with pgvector)

This runs a local Postgres instance, ideal for dev + testing:

```bash
docker-compose up -d
```

The DB will be accessible at:

```
postgres://root:password@test-db:5432/test
```

---

## 3. Build the Rust Lambda Binary

```bash
make sam-build
```

This command performs several important steps under the hood:

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

Then open:

```
http://localhost:3000/Prod/hello
```

You'll see:

```json
{ "message": "Hello World with DB!" }
```

If something fails, the API returns structured error JSON. Logs are printed with `tracing`.

---

## 🔍 Inside `main.rs`

The entire app is defined in `rust_app/src/main.rs`. Here's a breakdown:

### Route Definition

```rust
let routes = warp::path!("Prod" / "hello")
    .and(warp::get())
    .and(warp::any().map(move || pool.clone()))
    .and_then(db_healthcheck_handler);
```

This sets up a GET endpoint at `/Prod/hello` and passes the database pool to the handler.

### Healthcheck Handler

```rust
async fn db_healthcheck_handler(pool: PgPool) -> Result<impl warp::Reply, warp::Rejection> {
    let result = timeout(Duration::from_secs(10), {
        let pool = pool.clone();
        tokio::task::spawn_blocking(move || {
            let mut conn = pool.get()?;
            sql_query("SELECT 1").execute(&mut conn)?;
            Ok(())
        })
    }).await;

    match result {
        Ok(Ok(_)) => Ok(warp::reply::json(&json!({ "message": "Hello World with DB!" }))),
        _ => Ok(warp::reply::json(&json!({ "error": "DB query failed" })))
    }
}
```

- Diesel is blocking, so we run it inside `spawn_blocking`
- Wrapped in `tokio::timeout` to avoid long Lambda runtimes
- Clean structured error handling with `tracing` logs

---

## 🚣 Routing with SAM + API Gateway

From `template.yaml`:

```yaml
Events:
  HelloWorld:
    Type: Api
    Properties:
      Path: /{proxy+}
      Method: ANY
```

This catch-all route passes every request to Warp. Because SAM adds a `Prod` stage prefix by default, the deployed URL will look like:

```
https://<gateway>.amazonaws.com/Prod/hello
```

---

## ⚙️ Environment & Layer Configuration

Key environment variables in `template.yaml`:

```yaml
Environment:
  Variables:
    PQ_LIB_DIR: /opt/lib
    PQ_INCLUDE_DIR: /opt/include/libpq
    LD_LIBRARY_PATH: /opt/lib
    DB_URL: postgres://root:password@test-db:5432/test?sslmode=disable
```

These ensure that Diesel’s `pq-sys` links correctly during build and that `libpq.so` is found during runtime inside Lambda.

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
```

---

## 🚀 Deploying to AWS

Once tested locally, deploy with:

```bash
sam deploy --guided
```

Follow the prompts to configure your stack, IAM roles, and region. The `template.yaml` and `samconfig.toml` will ensure reproducible deployments.

---

## ✅ Final Thoughts

This pattern unlocks scalable, cost-effective Rust APIs with:

- No infrastructure to manage
- Native PostgreSQL support via Diesel
- High performance from Rust and Warp
- Full local development + testing loop

Want to go further? Add authentication with JWT, integrate SQS or S3, or wrap more Warp routes with Lambda. If you've got feedback or questions, open a GitHub issue—we'd love to hear from you.

Happy shipping 🦀💨

