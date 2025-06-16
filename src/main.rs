use axum::routing::{get, post};
use clap::Parser;
use color_eyre::eyre::Result;
// Duplicate axum::routing import removed
use rbx_studio_server::{StateManager, StateManagerCommand, AxumSharedState, discover_luau_tools, DiscoveredTool, RBXStudioServer, STUDIO_PLUGIN_PORT, request_handler, response_handler}; // Explicit imports
use rmcp::ServiceExt;
use std::io;
use std::net::Ipv4Addr;
use std::sync::Arc;
use tokio::sync::mpsc; // Mutex removed
use tracing_subscriber::{self, EnvFilter};
use std::path::PathBuf;
use std::collections::HashMap; // Added for HashMap type annotation

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
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("warn")) // Default to WARN for other crates if RUST_LOG is not set
        .add_directive("rbx_studio_mcp=info".parse().expect("Failed to parse rbx_studio_mcp directive"))
        .add_directive("mcp_server=info".parse().expect("Failed to parse mcp_server directive")); // For our custom targets

    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_writer(io::stderr) // Keep directing to stderr
        .with_target(true)       // Enable printing of log targets
        .with_thread_ids(true)   // Keep thread IDs if they were there
        .init();

    let args = Args::parse();
    if !args.stdio {
        return install::install().await;
    }

    tracing::debug!("Debug MCP tracing enabled");

    // --- Start New State Initialization ---
    let (sm_command_tx, sm_command_rx) = mpsc::channel::<StateManagerCommand>(100); // Buffer size 100

    let state_manager = StateManager::new(); // Assuming StateManager::new() currently takes no args

    tokio::spawn(state_manager.run(sm_command_rx)); // Spawn the StateManager task

    // Initialize discovered_luau_tools
    // Adjust the path as necessary for your project structure.
    // This path is relative to where the binary is run from.
    let tools_dir = PathBuf::from("./plugin/src/Tools");
    let discovered_luau_tools_map: HashMap<String, DiscoveredTool> = discover_luau_tools(&tools_dir);
    let arc_discovered_luau_tools = Arc::new(discovered_luau_tools_map);

    // Create AxumSharedState
    let axum_shared_state = AxumSharedState { sm_command_tx: sm_command_tx.clone() };
    // --- End New State Initialization ---

    let (close_tx, close_rx) = tokio::sync::oneshot::channel();

    let listener =
        tokio::net::TcpListener::bind((Ipv4Addr::new(127, 0, 0, 1), STUDIO_PLUGIN_PORT)).await;

    // let server_state_clone = Arc::clone(&server_state); // OLD - REMOVED/COMMENTED
    let server_handle = if let Ok(listener) = listener {
        let app = axum::Router::new()
            .route("/request", get(request_handler))
            .route("/response", post(response_handler))
            .with_state(axum_shared_state.clone()); // Use new axum_shared_state
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
        tracing::warn!("Failed to bind to port {}. HTTP server/proxy functionality will be unavailable.", STUDIO_PLUGIN_PORT);
        // Fallback: Spawn a task that does nothing but can be awaited, or handle error appropriately.
        // For now, let server_handle be a task that immediately completes.
        // This else block might need more robust handling depending on desired behavior if port is busy.
        tokio::spawn(async move {
             // close_rx needs to be consumed or handled if this path is taken.
             // If dud_proxy_loop was essential, a replacement or alternative logic is needed here.
             // For now, just await the close signal if no HTTP server is running.
            _ = close_rx.await;
            tracing::info!("HTTP server/proxy was not started (port busy). Fallback path completed.");
        })
    };

    // Create an instance of our counter router
    // RBXStudioServer::new now expects sm_command_tx and arc_discovered_luau_tools
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
