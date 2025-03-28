/// rust_app/src/main.rs

use diesel::pg::PgConnection;
use diesel::r2d2::{ConnectionManager, Pool};
use diesel::sql_query;
use diesel::RunQueryDsl;
use serde_json::json;
use std::error::Error as StdError;
use std::time::Duration;
use tokio::time::timeout;
use tracing::{debug, error, info};
use warp::Filter;

type PgPool = Pool<ConnectionManager<PgConnection>>;

/// Perform a healthcheck by attempting a simple SELECT query on the DB.
/// This is run in a blocking thread since Diesel is synchronous.
async fn db_healthcheck_handler(pool: PgPool) -> Result<impl warp::Reply, warp::Rejection> {
    info!("📦 Received /hello request");

    let result = timeout(Duration::from_secs(10), {
        let pool = pool.clone();
        tokio::task::spawn_blocking(move || {
            // Attempt to get a pooled DB connection
            let mut conn = pool.get().map_err(|e| {
                error!("❌ Failed to get DB connection: {:?}", e);
                Box::<dyn StdError + Send + Sync>::from(e)
            })?;

            // Run a simple test query
            sql_query("SELECT 1").execute(&mut conn).map_err(|e| {
                error!("❌ Query failed: {:?}", e);
                Box::<dyn StdError + Send + Sync>::from(e)
            })?;

            Ok::<(), Box<dyn StdError + Send + Sync>>(())
        })
    })
    .await;

    // Match on all possible timeout/spawned task errors
    let response = match result {
        Ok(Ok(Ok(()))) => {
            info!("✅ DB check passed.");
            warp::reply::json(&json!({ "message": "Hello World with DB!" }))
        }
        Ok(Ok(Err(e))) => {
            let msg = format!("❌ DB error: {}", e);
            error!("{}", msg);
            warp::reply::json(&json!({ "error": msg }))
        }
        Ok(Err(join_err)) => {
            let msg = format!("❌ DB join error: {}", join_err);
            error!("{}", msg);
            warp::reply::json(&json!({ "error": msg }))
        }
        Err(timeout_err) => {
            let msg = format!("❌ DB check timeout: {}", timeout_err);
            error!("{}", msg);
            warp::reply::json(&json!({ "error": msg }))
        }
    };

    Ok(warp::reply::with_status(response, warp::http::StatusCode::OK))
}

#[tokio::main]
async fn main() {
    // Set up structured logging for diagnostics
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .with_writer(std::io::stderr)
        .without_time()
        .init();

    // Log any panics
    std::panic::set_hook(Box::new(|info| {
        let thread = std::thread::current();
        let name = thread.name().unwrap_or("unnamed");
        error!("💥 Panic in thread '{}': {:?}", name, info);
    }));

    info!("🚀 Starting warp_lambda runtime...");

    // Log relevant environment vars
    for var in &["LD_LIBRARY_PATH", "PQ_LIB_DIR", "PQ_INCLUDE_DIR", "PGSSLMODE"] {
        match std::env::var(var) {
            Ok(value) => info!("🔧 {} = {}", var, value),
            Err(_) => debug!("⚠️ {} is not set", var),
        }
    }

    let database_url = std::env::var("DB_URL").expect("DB URL NOT SET");
    // Initialize a global DB connection pool
    let manager = ConnectionManager::<PgConnection>::new(database_url);
    let pool = Pool::builder()
        .max_size(15)
        .build(manager)
        .expect("Failed to create DB pool");

    // Define the GET /Prod/hello route for AWS HTTP API Gateway mapping
    let routes = warp::path!("Prod" / "hello")
        .and(warp::get())
        .and(warp::any().map(move || pool.clone()))
        .and_then(db_healthcheck_handler);

    // Run the Warp service in Lambda
    warp_lambda::run(warp::service(routes))
        .await
        .expect("Failed to start warp_lambda runtime");
}
