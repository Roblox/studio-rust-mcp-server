// src/main.rs - FINAL, CORRECTED VERSION

use axum::routing::post; // Changed from get/post to just post
use clap::Parser;
use color_eyre::eyre::Result;
// Corrected imports to use the new unified_handler
use rbx_studio_server::{
    discover_luau_tools, unified_handler, AxumSharedState, DiscoveredTool, RBXStudioServer,
    StateManager, StateManagerCommand, STUDIO_PLUGIN_PORT,
};
use rmcp::ServiceExt;
use std::io;
use std::net::Ipv4Addr;
use std::sync::Arc;
use tokio::sync::mpsc;
use tracing_subscriber::{self, EnvFilter};
use std::path::PathBuf;
use std::collections::HashMap;

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

// You can keep or remove the worker_threads count; the new architecture is robust either way.
// Let's keep it for good measure.
#[tokio::main(worker_threads = 10)] 
async fn main() -> Result<()> {
    color_eyre::install()?;
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("warn"))
        .add_directive("rbx_studio_mcp=info".parse().unwrap())
        .add_directive("mcp_server=info".parse().unwrap())
        .add_directive("state_manager=info".parse().unwrap());

    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_writer(io::stderr)
        .with_target(true)
        .with_thread_ids(true)
        .init();

    let args = Args::parse();
    if !args.stdio {
        return install::install().await;
    }

    tracing::debug!("Debug MCP tracing enabled");

    // --- State Initialization ---
    let (sm_command_tx, sm_command_rx) = mpsc::channel::<StateManagerCommand>(100);
    let state_manager = StateManager::new();
    tokio::spawn(state_manager.run(sm_command_rx));

    let tools_dir = PathBuf::from("./plugin/src/Tools");
    let discovered_luau_tools_map: HashMap<String, DiscoveredTool> =
        discover_luau_tools(&tools_dir);
    let arc_discovered_luau_tools = Arc::new(discovered_luau_tools_map);

    let axum_shared_state = AxumSharedState {
        sm_command_tx: sm_command_tx.clone(),
    };
    
    // --- HTTP Server Setup ---
    let (close_tx, close_rx) = tokio::sync::oneshot::channel();
    let listener =
        tokio::net::TcpListener::bind((Ipv4Addr::new(127, 0, 0, 1), STUDIO_PLUGIN_PORT)).await;

    let server_handle = if let Ok(listener) = listener {
        // ===================================================================
        // THE FIX IS HERE: We now only have one route to the unified_handler
        // ===================================================================
        let app = axum::Router::new()
            .route("/mcp", post(unified_handler)) // Use the single endpoint
            .with_state(axum_shared_state.clone());
        
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
        tracing::warn!("Failed to bind to port {}. HTTP server functionality will be unavailable.", STUDIO_PLUGIN_PORT);
        tokio::spawn(async move {
            _ = close_rx.await;
        })
    };

    // --- Stdio Service Setup ---
    let service = RBXStudioServer::new(sm_command_tx.clone(), arc_discovered_luau_tools.clone())
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