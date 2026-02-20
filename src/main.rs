use axum::routing::{get, post};
use clap::Parser;
use color_eyre::eyre::Result;
use rbx_studio_server::*;
use rmcp::ServiceExt;
use std::fs::File;
use std::net::Ipv4Addr;
use std::sync::Arc;
use tokio::sync::Mutex;
use tracing_subscriber::{self, EnvFilter};
mod error;
mod install;
mod rbx_studio_server;

/// Simple MCP proxy for Roblox Studio
/// Run without arguments to install the plugin
#[derive(Parser)]
#[command(version, about, long_about = None)]
struct Args {
    /// Run as MCP server on stdio
    #[arg(short, long)]
    stdio: bool,
}

#[tokio::main]
async fn main() -> Result<()> {
    color_eyre::install()?;
    let log_file =
        File::create("/Users/sai/Roblox/Projects/studio-rust-mcp-server/rbx-studio-mcp.log")?;
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("debug")),
        )
        .with_writer(std::sync::Mutex::new(log_file))
        .with_target(false)
        .with_thread_ids(true)
        .init();

    let args = Args::parse();
    if !args.stdio {
        return install::install().await;
    }

    tracing::debug!("Debug MCP tracing enabled");

    let server_state = Arc::new(Mutex::new(AppState::new()));

    let (close_tx, close_rx) = tokio::sync::oneshot::channel();

    let listener =
        tokio::net::TcpListener::bind((Ipv4Addr::new(127, 0, 0, 1), STUDIO_PLUGIN_PORT)).await;

    let server_state_clone = Arc::clone(&server_state);
    let server_handle = if let Ok(listener) = listener {
        let app = axum::Router::new()
            .route("/register", post(rbx_studio_server::register_handler))
            .route("/unregister", post(rbx_studio_server::unregister_handler))
            .route("/request", get(request_handler))
            .route("/response", post(response_handler))
            .route("/proxy", post(proxy_handler))
            .with_state(server_state_clone);
        tracing::info!("This MCP instance is HTTP server listening on {STUDIO_PLUGIN_PORT}");
        tokio::spawn(async {
            axum::serve(listener, app)
                .with_graceful_shutdown(async move {
                    _ = close_rx.await;
                })
                .await
                .unwrap();
        })
    } else {
        tracing::info!("This MCP instance will use proxy since port is busy");
        tokio::spawn(async move {
            dud_proxy_loop(server_state_clone, close_rx).await;
        })
    };

    // Create an instance of our counter router
    let service = RBXStudioServer::new(Arc::clone(&server_state))
        .serve(rmcp::transport::stdio())
        .await
        .inspect_err(|e| {
            tracing::error!("serving error: {:?}", e);
        })?;
    service.waiting().await?;

    close_tx.send(()).ok();
    tracing::info!("Waiting for web server to gracefully shutdown");
    server_handle.await.ok();
    tracing::info!("Bye!");
    Ok(())
}
