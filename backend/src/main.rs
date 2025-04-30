// rust_app/src/main.rs

use backend::{db_healthcheck_handler, init_diesel_pool};
use tracing::{debug, error, info};
use warp::Filter;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .with_writer(std::io::stderr)
        .without_time()
        .init();

    std::panic::set_hook(Box::new(|info| {
        let thread = std::thread::current();
        let name = thread.name().unwrap_or("unnamed");
        error!("💥 Panic in thread '{}': {:?}", name, info);
    }));

    info!("🚀 Starting warp_lambda runtime...");

    // for var in &[
    //     "LD_LIBRARY_PATH",
    //     "PQ_LIB_DIR",
    //     "PQ_INCLUDE_DIR",
    //     "PGSSLMODE",
    // ] {
    //     match std::env::var(var) {
    //         Ok(value) => info!("🔧 {} = {}", var, value),
    //         Err(_) => debug!("⚠️ {} is not set", var),
    //     }
    // }

    init_diesel_pool();

    let all_routes = warp::path!("Prod" / "hello")
        .and(warp::get())
        .and_then(db_healthcheck_handler);


    #[cfg(feature = "lambda")]
    {
        let warp_service = warp::service(all_routes);
        warp_lambda::run(warp_service)
            .await
            .expect("An error occurred");
    }

    #[cfg(not(feature = "lambda"))]
    {
        info!("Running as a local Warp server...");
        warp::serve(all_routes).run(([0, 0, 0, 0], 3000)).await;
    }

}
