// rust_app/src/db.rs

use diesel::pg::PgConnection;
use diesel::r2d2::{ConnectionManager, Pool, PooledConnection};
use once_cell::sync::OnceCell;
use std::sync::Arc;
use tokio::task;

pub type DbPool = Pool<ConnectionManager<PgConnection>>;
pub static DB_POOL: OnceCell<Arc<DbPool>> = OnceCell::new();

pub fn init_diesel_pool() -> Arc<DbPool> {
    println!("🔍 DATABASE_URL: {:?}", std::env::var("DATABASE_URL"));
    let database_url = std::env::var("DATABASE_URL").unwrap_or_else(|_| {
        eprintln!("❌ DATABASE_URL is not set");
        std::process::exit(1);
    });

    let manager = ConnectionManager::<PgConnection>::new(database_url);
    let pool = Pool::builder()
        .max_size(15)
        .build(manager)
        .expect("Failed to create Diesel connection pool");

    let arc_pool = Arc::new(pool);
    DB_POOL
        .set(arc_pool.clone())
        .expect("Failed to set the Diesel DB pool");

    arc_pool
}

pub fn get_diesel_pool() -> Arc<DbPool> {
    DB_POOL.get().expect("DB_POOL must be initialized").clone()
}

pub fn get_db_conn() -> PooledConnection<ConnectionManager<PgConnection>> {
    get_diesel_pool()
        .get()
        .expect("Failed to get a Diesel DB connection from the pool")
}

pub async fn run_diesel_query<T, E, F>(query_fn: F) -> Result<T, E>
where
    T: Send + 'static,
    E: Send + 'static,
    F: FnOnce(&mut PgConnection) -> Result<T, E> + Send + 'static,
{
    task::spawn_blocking(move || {
        let mut conn = get_db_conn();
        query_fn(&mut conn)
    })
    .await
    .expect("Failed to execute Diesel query in spawn_blocking")
}
