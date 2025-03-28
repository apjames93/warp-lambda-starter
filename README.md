# 🚀 SAM Rust + Warp + Diesel on Lambda

This project demonstrates a full Rust backend stack deployed to AWS Lambda, featuring:

- [Warp](https://github.com/seanmonstar/warp): for high-performance async HTTP routing  
- [Diesel](https://diesel.rs/): for PostgreSQL database interactions  
- [`warp_lambda`](https://crates.io/crates/warp_lambda): for adapting Warp filters into AWS Lambda-compatible handlers  
- [AWS SAM](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html): to build and deploy the Lambda function and its supporting layers  
- ✅ A compiled PostgreSQL `libpq` dynamic library as a Lambda layer

---

## 📆 Project Structure

```bash
.
├── rust_app/                # Contains Rust source code (main.rs, Cargo.toml)
├── libpq_layer/            # Contains compiled libpq binaries and headers
├── libpq_layer.zip         # Zipped version of the layer for SAM
├── build_libpq_layer.sh    # Script to build the libpq layer in Docker
├── docker-compose.yaml     # Starts local PostgreSQL instance for development
├── env.json                # Env vars used by SAM for local runs
├── template.yaml           # AWS SAM template for Lambda and Layer definitions
├── Makefile                # Convenience commands for local build/test/deploy
```

---

## ✅ Features

- **`GET /Prod/hello`**: Basic healthcheck endpoint that connects to a local PostgreSQL container and runs `SELECT 1`.
- Logs the full lifecycle of request → DB connection → query → response.
- Uses `r2d2` pool with `diesel::PgConnection`.
- Fully async using `tokio`, with blocking operations wrapped safely in `spawn_blocking`.

---

## 🛠️ Setup Instructions

### 1. Clone & Build libpq Layer

```bash
./build_libpq_layer.sh
```

This script:
- Runs a Docker container to build and extract PostgreSQL `libpq` dynamic libraries
- Creates symlinks and zips the result into `libpq_layer.zip`

### 2. Start PostgreSQL

```bash
docker-compose up -d
```

This will start a Postgres container with:
- `DB: test`
- `User: root`
- `Password: password`
- Accessible at `postgres://root:password@test-db:5432/test`

### 3. Build the Lambda Function

```bash
make sam-build
```

This runs the `sam build` command with proper `RUSTFLAGS` and `libpq` layer setup.

### 4. Run Locally

```bash
make sam-run
```

Then visit:

```
http://127.0.0.1:3000/Prod/hello
```

---

## 🔪 Testing

The endpoint performs a database health check:

```json
{
  "message": "Hello World with DB!"
}
```

On failure, it logs and returns a descriptive error JSON.

---

## 🧹 API Gateway Routing

In `template.yaml`:

```yaml
Path: /{proxy+}
Method: ANY
```

This allows routing anything through the Warp router.

In `main.rs`:

```rust
let routes = warp::path!("Prod" / "hello")
    .and(warp::get())
    .and_then(db_healthcheck_handler);
```

Note: You must hit `/Prod/hello` due to SAM’s implicit stage naming convention (`Prod` by default).

---

## 📦 Dependencies

See [`Cargo.toml`](./rust_app/Cargo.toml), highlights include:

- `warp`
- `warp_lambda`
- `diesel`
- `sqlx`
- `tracing`
- `pgvector`

---

## 🛄 Deployment

Deploy to AWS with:

```bash
sam deploy --guided
```

---

## 🪟 Cleanup

Stop Docker services:

```bash
docker-compose down
```

---

## ✨ Acknowledgments

Thanks to the maintainers of:
- [`warp`](https://github.com/seanmonstar/warp)
- [`warp_lambda`](https://github.com/aslamplr/warp_lambda)
- [`cargo-lambda`](https://github.com/cargo-lambda/cargo-lambda)
- [`aws-lambda-rust-runtime`](https://github.com/awslabs/aws-lambda-rust-runtime)

