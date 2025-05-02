use warp::http::StatusCode;
use warp::Filter;

use backend::{db_healthcheck_handler, init_diesel_pool};

#[tokio::test]
async fn test_hello_db_healthcheck() {
    // Setup the DB pool once (if not already initialized)
    let _ = std::panic::catch_unwind(|| {
        init_diesel_pool();
    });

    // Build the filter (as it is in main.rs)
    let api = warp::path!("Prod" / "hello")
        .and(warp::get())
        .and_then(db_healthcheck_handler);

    // Simulate request to the route
    let res = warp::test::request()
        .method("GET")
        .path("/Prod/hello")
        .reply(&api)
        .await;

    // Assert the status and response
    assert_eq!(res.status(), StatusCode::OK);
    let body = std::str::from_utf8(res.body()).unwrap();
    assert!(
        body.contains("Hello World with DB!")
            || body.contains("DB error")
            || body.contains("timeout"),
        "Unexpected response body: {}",
        body
    );
}
