// rust_app/src/lib.rs

pub mod db;

pub use db::{get_db_conn, init_diesel_pool, run_diesel_query};

use diesel::sql_query;
use diesel::RunQueryDsl;
use serde_json::json;
use std::time::Duration;
use tokio::time::timeout;
use tracing::{error, info};
use warp::http::StatusCode;

/// Health check handler
pub async fn db_healthcheck_handler() -> Result<impl warp::Reply, warp::Rejection> {
    info!("📦 Received /hello request");

    let result = timeout(Duration::from_secs(10), async {
        run_diesel_query(|conn| sql_query("SELECT 1").execute(conn).map(|_| ())).await
    })
    .await;

    let response = match result {
        Ok(Ok(())) => {
            info!("✅ DB check passed.");
            warp::reply::json(&json!({ "message": "Hello World with DB!" }))
        }
        Ok(Err(e)) => {
            let msg = format!("❌ DB error: {:?}", e);
            error!("{}", msg);
            warp::reply::json(&json!({ "error": msg }))
        }
        Err(timeout_err) => {
            let msg = format!("❌ DB check timeout: {}", timeout_err);
            error!("{}", msg);
            warp::reply::json(&json!({ "error": msg }))
        }
    };

    Ok(warp::reply::with_status(response, StatusCode::OK))
}
