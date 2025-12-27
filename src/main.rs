use axum::routing::{get, post};
use clap::Parser;
use color_eyre::eyre::Result;
use rbx_studio_server::*;
use rmcp::ServiceExt;
use std::io;
use std::net::Ipv4Addr;
use std::sync::Arc;
use tokio::sync::Mutex;
use tracing_subscriber::{self, EnvFilter};
mod error;
#[cfg(any(target_os = "windows", target_os = "macos"))]
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

    /// Run HTTP server only (no MCP stdio, for use with /proxy endpoint)
    #[arg(long)]
    http_only: bool,
}

#[tokio::main]
async fn main() -> Result<()> {
    color_eyre::install()?;
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .with_writer(io::stderr)
        .with_target(false)
        .with_thread_ids(true)
        .init();

    let args = Args::parse();
    if !args.stdio && !args.http_only {
        #[cfg(any(target_os = "windows", target_os = "macos"))]
        {
            return install::install().await;
        }
        #[cfg(not(any(target_os = "windows", target_os = "macos")))]
        {
            eprintln!("Auto-install not supported on Linux.");
            eprintln!("Use --stdio for MCP mode or --http-only for HTTP server mode.");
            std::process::exit(1);
        }
    }

    tracing::debug!("Debug MCP tracing enabled");

    let server_state = Arc::new(Mutex::new(AppState::new()));

    let listener =
        tokio::net::TcpListener::bind((Ipv4Addr::new(127, 0, 0, 1), STUDIO_PLUGIN_PORT)).await;

    if args.http_only {
        // HTTP-only mode: just run the HTTP server without MCP stdio
        if let Ok(listener) = listener {
            let app = axum::Router::new()
                .route("/request", get(request_handler))
                .route("/response", post(response_handler))
                .route("/proxy", post(proxy_handler))
                .with_state(server_state);
            tracing::info!("HTTP-only server listening on port {STUDIO_PLUGIN_PORT}");
            eprintln!("MCP HTTP server running on http://127.0.0.1:{STUDIO_PLUGIN_PORT}");
            eprintln!("Press Ctrl+C to stop");
            axum::serve(listener, app).await.unwrap();
        } else {
            eprintln!("Error: Port {STUDIO_PLUGIN_PORT} already in use");
            std::process::exit(1);
        }
        return Ok(());
    }

    // Standard MCP mode with stdio
    let (close_tx, close_rx) = tokio::sync::oneshot::channel();

    let server_state_clone = Arc::clone(&server_state);
    let server_handle = if let Ok(listener) = listener {
        let app = axum::Router::new()
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
