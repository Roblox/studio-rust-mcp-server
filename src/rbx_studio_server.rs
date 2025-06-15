
// Necessary imports
use crate::error::Result;
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{extract::State, Json};
// color_eyre is not directly used, McpError handles errors.
use rmcp::model::{
    ServerCapabilities, ServerInfo, ProtocolVersion, Implementation, Content, CallToolResult, ToolsCapability,
};
use rmcp::schemars;
use rmcp::tool;
use rmcp::{Error as McpError, ServerHandler};

use std::collections::{HashMap, VecDeque};
// use serde_json::Value; // Likely not needed if serde_json::Map and json! macro are used
use std::path::{Path, PathBuf};
use std::fs;
use std::env;

use std::sync::Arc;
use tokio::sync::oneshot::Receiver; // If dud_proxy_loop uses it
use tokio::sync::{mpsc, watch, Mutex};
use tokio::time::Duration;
use uuid::Uuid;

use tracing::{debug, error, info, warn};


pub const STUDIO_PLUGIN_PORT: u16 = 44755;
// Defines the duration for which the server holds a client's long poll request (/request handler)
// if no tasks are immediately available in the queue.
// This value should be coordinated with the client's HTTP request timeout.
// If the client times out earlier than this duration, it might lead to frequent reconnections
// and potentially missed task deliveries if the client doesn't implement robust retry logic.
// If this duration is too long, it might hold server resources unnecessarily.
// "Reported timeout issues" could stem from a mismatch between this value and client expectations,
// or from overall task processing taking longer than this poll duration plus client-side timeouts.
const LONG_POLL_DURATION: Duration = Duration::from_secs(15);
// Timeout for HTTP requests made by the dud_proxy_loop to the actual plugin endpoint.
// This is crucial to prevent dud_proxy_loop from hanging indefinitely if a plugin is unresponsive.
// Should be less than LONG_POLL_DURATION, as this is one step within the larger polling cycle.
const DUD_PROXY_REQUEST_TIMEOUT: Duration = Duration::from_secs(10);

// DiscoveredTool struct
#[derive(Clone, Debug)]
pub struct DiscoveredTool {
    pub file_path: PathBuf,
}

// discover_luau_tools function
pub fn discover_luau_tools(tools_dir_path: &Path) -> HashMap<String, DiscoveredTool> {
    let mut tools = HashMap::new();

    info!("Attempting to discover Luau tools in: {:?}", tools_dir_path);
    if !tools_dir_path.exists() {
        warn!("Luau tools directory does not exist: {:?}", tools_dir_path);
        return tools;
    }
    if !tools_dir_path.is_dir() {
        error!("Luau tools path is not a directory: {:?}", tools_dir_path);
        return tools;
    }

    match fs::read_dir(tools_dir_path) {
        Ok(entries) => {
            for entry in entries.filter_map(Result::ok) {
                let path = entry.path();
                if path.is_file() && path.extension().and_then(|s| s.to_str()) == Some("luau") {
                    if let Some(tool_name) = path.file_stem().and_then(|s| s.to_str()).map(String::from) {
                        info!("Discovered Luau tool: {} at {:?}", tool_name, path);
                        tools.insert(tool_name, DiscoveredTool { file_path: path });

                    } else {
                        warn!("Could not convert tool name (file stem) to string for path: {:?}", path);

                    }
                }
            }
        }
        Err(e) => {
            error!("Failed to read Luau tools directory {:?}: {}", tools_dir_path, e);
        }
    }

    if tools.is_empty() {
        info!("No Luau tools discovered or directory was empty: {:?}", tools_dir_path);
    } else {
        info!("Successfully discovered {} Luau tools: [{}]", tools.len(), tools.keys().cloned().collect::<Vec<String>>().join(", "));
    }
    tools
}

// AppState struct and ::new()

pub struct AppState {
    process_queue: VecDeque<ToolArguments>,
    output_map: HashMap<Uuid, mpsc::UnboundedSender<Result<String, McpError>>>,
    waiter: watch::Receiver<()>,
    trigger: watch::Sender<()>,
    discovered_luau_tools: HashMap<String, DiscoveredTool>,
}
pub type PackedState = Arc<Mutex<AppState>>;

impl AppState {
    pub fn new() -> Self {
        let (trigger, waiter) = watch::channel(());

        // Corrected path finding logic for AppState::new()
        let base_path = env::current_exe().ok()
            .and_then(|p| p.parent().map(PathBuf::from)) // target/debug or target/release
            .and_then(|p| p.parent().map(PathBuf::from)) // target
            .and_then(|p| p.parent().map(PathBuf::from)) // project root
            .unwrap_or_else(|| PathBuf::from(".")); // Default to current dir if path fails

        // Corrected fallback path for consistency
        let tools_dir_pathbuf = base_path.join("plugin/src/Tools");

        info!("Attempting to discover Luau tools in: {:?}", tools_dir_pathbuf);
        let discovered_tools = discover_luau_tools(&tools_dir_pathbuf); // Pass by reference
        if discovered_tools.is_empty() {
            warn!("No Luau tools discovered in {:?}. Ensure path is correct and .luau files exist.", tools_dir_pathbuf);
        }


        Self {
            process_queue: VecDeque::new(),
            output_map: HashMap::new(),
            waiter,
            trigger,

            discovered_luau_tools: discovered_tools,

        }
    }
}

#[derive(rmcp::serde::Deserialize, rmcp::serde::Serialize, Clone, Debug)]
pub enum ToolArgumentValues {
    RunCommand { command: String },
    InsertModel { query: String },
    ExecuteLuauByName {
        tool_name: String,
        arguments_json: String,
    }
}

#[derive(rmcp::serde::Deserialize, rmcp::serde::Serialize, Clone, Debug)]
pub struct ToolArguments {
    args: ToolArgumentValues,
    id: Option<Uuid>,
}

impl ToolArguments {
     fn new_with_id(args_values: ToolArgumentValues) -> (Self, Uuid) {
         let id = Uuid::new_v4();
         (
             Self {
                 args: args_values,
                 id: Some(id),
             },
             id,
         )
     }
}


// RunCommandResponse struct
#[derive(rmcp::serde::Deserialize, rmcp::serde::Serialize, Clone, Debug)]
pub struct RunCommandResponse {
    response: String,

    id: Uuid,
}

// RBXStudioServer struct and ::new()
#[derive(Clone)]
pub struct RBXStudioServer {
    state: PackedState,
}

impl RBXStudioServer {
    pub fn new(state: PackedState) -> Self {
        Self { state }
    }

    // Helper function to acquire the AppState lock with a timeout.
    // This function abstracts the locking mechanism, including timeout and error handling.
    async fn acquire_state_lock<'a>(
        state_mutex: &'a Mutex<AppState>,
        request_id: Uuid, // Added for logging context
    ) -> Result<tokio::sync::MutexGuard<'a, AppState>, McpError> {
        info!(target: "mcp_server::acquire_state_lock", request_id = %request_id, "Attempting to acquire state lock");

        const LOCK_TIMEOUT: Duration = Duration::from_secs(5);

        // The 5-second timeout is a relatively long duration for a mutex lock attempt.
        // It serves as a crucial safeguard against potential deadlocks in the AppState handling.
        // If typical lock contention were expected to be high, this value might be too long,
        // potentially masking performance issues. However, for preventing indefinite hangs
        // due to programming errors leading to deadlocks, it's a last resort.
        // Operations holding this lock should ideally be very short.

        match tokio::time::timeout(LOCK_TIMEOUT, state_mutex.lock()).await {
            Ok(Ok(guard)) => { // Timeout did not occur, lock successful
                info!(target: "mcp_server::acquire_state_lock", request_id = %request_id, "Acquired state lock.");
                Ok(guard)
            }
            Ok(Err(poisoned_error)) => { // Timeout did not occur, mutex poisoned
                error!(target: "mcp_server::acquire_state_lock", request_id = %request_id, "AppState mutex is poisoned! Error: {}", poisoned_error.to_string());
                Err(McpError::internal_error(
                    format!("Server state is corrupted (mutex poisoned: {})", poisoned_error.to_string()),
                    None,
                ))
            }
            Err(_timeout_elapsed) => { // Timeout occurred
                error!(target: "mcp_server::acquire_state_lock", request_id = %request_id, "Timeout acquiring AppState lock after {} seconds!", LOCK_TIMEOUT.as_secs());
                Err(McpError::internal_error(
                    format!("Server busy or deadlocked (timeout acquiring AppState lock after {} seconds).", LOCK_TIMEOUT.as_secs()),
                    None,
                ))
            }
        }
    }


    // Helper function to queue a command and prepare for its response.
    // This encapsulates the logic of modifying the shared state (process_queue, output_map).
    async fn queue_command_and_get_trigger(
        state_mutex: &Mutex<AppState>,
        tool_arguments_with_id: ToolArguments, // Renamed for clarity
        request_id: Uuid, // Passed for logging and map key
        response_sender: mpsc::UnboundedSender<Result<String, McpError>>, // Explicitly typed
    ) -> Result<watch::Sender<()>, McpError> {
        let mut state_guard = Self::acquire_state_lock(state_mutex, request_id).await?;

        info!(target: "mcp_server::queue_command", request_id = %request_id, "Pushing command to process_queue");
        state_guard.process_queue.push_back(tool_arguments_with_id);
        info!(target: "mcp_server::queue_command", request_id = %request_id, "Inserting response sender into output_map");
        state_guard.output_map.insert(request_id, response_sender);

        let cloned_trigger = state_guard.trigger.clone();
        info!(target: "mcp_server::queue_command", request_id = %request_id, "Cloned trigger from state");

        Ok(cloned_trigger)
        // state_guard is dropped here, releasing the lock.
    }


    async fn generic_tool_run(&self, args_values: ToolArgumentValues) -> Result<CallToolResult, McpError> {
         let (tool_arguments_with_id, request_id) = ToolArguments::new_with_id(args_values); // Renamed command_with_wrapper_id and id

         info!(target: "mcp_server::generic_tool_run", request_id = %request_id, "Queueing command for plugin");
         debug!(target: "mcp_server::generic_tool_run", request_id = %request_id, args = ?tool_arguments_with_id.args, "Command details");

         let (response_sender, response_receiver) = mpsc::unbounded_channel::<Result<String, McpError>>(); // Renamed tx, rx


         let trigger = Self::queue_command_and_get_trigger(
             &self.state,
             tool_arguments_with_id, // tool_arguments_with_id is moved here
             request_id,
             response_sender,
         )
         .await?;
         info!(target: "mcp_server::generic_tool_run", request_id = %request_id, "Released state lock after queuing operations");


         info!(target: "mcp_server::generic_tool_run", request_id = %request_id, "Attempting to send trigger");
         let send_result = trigger.send(());
         info!(target: "mcp_server::generic_tool_run", request_id = %request_id, send_result = ?send_result, "Trigger send attempt completed");


         send_result.map_err(|e| McpError::internal_error(format!("Unable to trigger send for plugin: {e}"), None))?;

         info!(target: "mcp_server::generic_tool_run", request_id = %request_id, "Trigger successfully sent");



        // Wait for and process the plugin's response.
        Self::wait_for_plugin_response(
            &self.state,
            request_id,
            response_receiver, // response_receiver is moved here
        )
        .await
    }


    // Helper function to wait for, process, and clean up after a plugin response.
    async fn wait_for_plugin_response(
        state_mutex: &Mutex<AppState>,
        request_id: Uuid,
        mut response_receiver: mpsc::UnboundedReceiver<Result<String, McpError>>, // Renamed for clarity
    ) -> Result<CallToolResult, McpError> {
        info!(target: "mcp_server::wait_for_plugin_response", request_id = %request_id, "Waiting for plugin response from channel");

        let plugin_response_result = response_receiver.recv().await
            .ok_or_else(|| {
                error!(target: "mcp_server::wait_for_plugin_response", request_id = %request_id, "Plugin response channel closed unexpectedly.");
                McpError::internal_error("Plugin response channel closed unexpectedly.", None)
            })?;

        match &plugin_response_result {
            Ok(res_str) => info!(target: "mcp_server::wait_for_plugin_response", request_id = %request_id, response_len = res_str.len(), "Received successful response from plugin channel"),
            Err(e) => warn!(target: "mcp_server::wait_for_plugin_response", request_id = %request_id, error = ?e, "Received error from plugin channel"),
        }

        // Clean up the output_map.
        // Using a direct lock here, assuming cleanup is quick and non-contentious.
        // If this section ever causes issues, consider using acquire_state_lock or a variant.
        {
            let mut state_guard = state_mutex.lock().await;
            state_guard.output_map.remove(&request_id);
            info!(target: "mcp_server::wait_for_plugin_response", request_id = %request_id, "Removed request ID from output_map");
        }


        // Process the plugin response and return the MCP CallToolResult.
        match plugin_response_result {
            Ok(response_string) => {
                debug!(target: "mcp_server::wait_for_plugin_response", request_id = %request_id, response = %response_string, "Processing successful plugin response");
                Ok(CallToolResult::success(vec![Content::text(response_string)]))
            }
            Err(mcp_error) => {
                error!(target: "mcp_server::wait_for_plugin_response", request_id = %request_id, error = ?mcp_error, "Processing error response from plugin");
                Ok(CallToolResult::error(vec![Content::text(mcp_error.to_string())]))
            }
        }
    }
}



#[tool(tool_box)]
impl ServerHandler for RBXStudioServer {
    fn get_info(&self) -> ServerInfo {
        let mut base_capabilities = ServerCapabilities::builder().enable_tools().build();
        if let Some(tools_caps) = base_capabilities.tools.as_mut() {
            tools_caps.list_changed = Some(true); // Explicitly set list_changed
        } else {
            // This case should ideally not happen if enable_tools() guarantees Some(ToolsCapability::default())
            base_capabilities.tools = Some(ToolsCapability { list_changed: Some(true) });
        }

        // Luau tool discovery and processing is simplified to just logging.
        // No `tools_map` or `rmcp::model::Tool` construction needed here anymore.
        if let Ok(app_state) = self.state.try_lock() {
            for (tool_name, _) in &app_state.discovered_luau_tools { // Changed _discovered_tool to _
                tracing::info!("Discovered Luau tool (not added to capabilities.tools due to API limitations): {}", tool_name);
            }
        } else {
            tracing::warn!("Could not lock AppState in get_info to add Luau tools to capabilities. Proceeding with macro-defined tools only.");
        }

        // base_capabilities.tools will remain as initialized by ServerCapabilities::builder().enable_tools().build();
        // and potentially modified by setting list_changed.
        // Luau tools are not merged back.

        ServerInfo {
            protocol_version: ProtocolVersion::V_2025_03_26,

            server_info: Implementation::from_build_env(),
            instructions: Some(
                "Use 'execute_discovered_luau_tool' to run Luau scripts by name (e.g., CreateInstance, RunCode). Also available: run_command (direct Luau string), insert_model.".to_string()
            ),
            capabilities: base_capabilities, // Return the modified base_capabilities
        }
    }
}


#[tool(tool_box)]
impl RBXStudioServer {
    #[tool(description = "Runs a raw Luau command string in Roblox Studio.")]

    async fn run_command(
        &self,
        #[tool(param)] #[schemars(description = "The Luau code to execute.")] command: String,
    ) -> Result<CallToolResult, McpError> {

        self.generic_tool_run(ToolArgumentValues::RunCommand { command }).await

    }

    #[tool(description = "Inserts a model from the Roblox marketplace into the workspace.")]
    async fn insert_model(
        &self,
        #[tool(param)] #[schemars(description = "Query to search for the model.")] query: String,
    ) -> Result<CallToolResult, McpError> {
        self.generic_tool_run(ToolArgumentValues::InsertModel { query }).await
    }

    #[tool(description = "Executes a specific Luau tool script by its name with given arguments.")]
    async fn execute_discovered_luau_tool(
        &self,
        #[tool(param)] #[schemars(description = "Name of the Luau tool file (without .luau extension) to execute.")] tool_name: String,
        #[tool(param)] #[schemars(description = "A JSON string representing arguments for the Luau tool.")] tool_arguments_str: String,
    ) -> Result<CallToolResult, McpError> {
        info!(target: "mcp_server::execute_luau", tool_name = %tool_name, args_json = %tool_arguments_str, "Executing Luau tool by name");
        let app_state = self.state.lock().await;
        if !app_state.discovered_luau_tools.contains_key(&tool_name) {
            warn!("Attempted to execute unknown Luau tool: {}", tool_name);
            return Ok(CallToolResult::error(vec![Content::text(format!("Luau tool '{}' not found by server.", tool_name))]));
        }
        if let Some(discovered_tool_info) = app_state.discovered_luau_tools.get(&tool_name) {
            info!(target: "mcp_server::execute_luau", tool_name = %tool_name, script_path = ?discovered_tool_info.file_path, "Found Luau script path");
        }

        self.generic_tool_run(ToolArgumentValues::ExecuteLuauByName {
            tool_name,
            arguments_json: tool_arguments_str,
        }).await
    }
}

pub async fn response_handler(
     State(state): State<PackedState>,
     Json(payload): Json<RunCommandResponse>,
 ) -> Result<impl IntoResponse, StatusCode> {
    // Log the reception of the reply, associating it with the specific request ID.
    debug!(target: "mcp_server::response_handler", request_id = %payload.id, "Received reply from studio plugin");

    // Note: state.lock().await can panic if the mutex is poisoned.
    // In a high-reliability scenario, consider using a helper like acquire_state_lock
    // and converting the McpError to an appropriate StatusCode if locking fails.
    // For now, allowing panic on poisoned mutex to signal critical state.
    let mut app_state = state.lock().await;

    if let Some(tx) = app_state.output_map.remove(&payload.id) {
        // Attempt to send the received response to the corresponding internal channel.
        if let Err(e) = tx.send(Ok(payload.response)) {
            // This error typically means the receiver (e.g., in generic_tool_run or proxy_handler)
            // is no longer waiting, possibly due to timeout or client disconnect.
            error!(target: "mcp_server::response_handler", request_id = %payload.id, error = ?e, "Failed to send plugin response to internal channel. Receiver likely dropped.");
        }
    } else {
        // This indicates the server received a response for a request ID it no longer tracks.
        // Could be due to a timeout that already cleared the ID, or a spurious/late response.
        warn!(target: "mcp_server::response_handler", request_id = %payload.id, "Received response for unknown or already handled request ID. It might have timed out or been processed.");
    }
    Ok(StatusCode::OK)
 }

 pub async fn request_handler(State(state): State<PackedState>) -> Result<impl IntoResponse, StatusCode> {
    debug!(target: "mcp_server::request_handler", "Polling for new task for client.");
    let timeout_result = tokio::time::timeout(LONG_POLL_DURATION, async {
        loop {
            let mut waiter = {
                // Note: state.lock().await can panic if the mutex is poisoned.
                let mut app_state_locked = state.lock().await;
                if let Some(task_with_id) = app_state_locked.process_queue.pop_front() {
                    debug!(target: "mcp_server::request_handler", task_id = ?task_with_id.id, "Dequeued task for client");
                    return Ok::<_, McpError>(Json(task_with_id));
                }
                app_state_locked.waiter.clone()
            };


            // Wait for a signal that the process_queue might have new items, or that the server is shutting down.
            if waiter.changed().await.is_err() {
                // This error means the watch channel sender (trigger) has been dropped,
                // which typically indicates the AppState (and thus the server) is shutting down.
                error!(target: "mcp_server::request_handler", "Waiter channel closed, server likely shutting down. Poll aborted.");
                // Return an McpError, which will be converted to a 500 response by the match block below.
                return Err(McpError::internal_error(
                    "Server is shutting down; request polling has been aborted.",
                    None,
                ));
            }
            debug!(target: "mcp_server::request_handler", "Waiter channel triggered, re-checking queue.");
        }
    })
    .await;

    match timeout_result {
        Ok(Ok(json_response)) => Ok(json_response.into_response()),
        Ok(Err(mcp_err)) => {
            // An McpError occurred within the request polling loop (e.g., waiter channel closed as handled above).
            warn!(target: "mcp_server::request_handler", error = ?mcp_err, "Request handler loop encountered an internal error.");
            // Respond with a structured JSON error, consistent with McpError's intent.
            let error_response = rmcp::serde_json::json!({
                "type": "internal_server_error",
                "message": mcp_err.to_string(), // Provides a full description of the error
            });
            Ok((StatusCode::INTERNAL_SERVER_ERROR, Json(error_response)).into_response())
        }
        Err(_timeout_elapsed) => {
            // This is the standard long-poll timeout: no task was available within the LONG_POLL_DURATION.
            debug!(target: "mcp_server::request_handler", "Long poll timed out. No new tasks available for client.");
            Ok((StatusCode::NO_CONTENT).into_response())
        }
    }

 }

pub async fn proxy_handler(
    State(state): State<PackedState>,
    Json(command_with_id): Json<ToolArguments>,
) -> Result<impl IntoResponse, StatusCode> {
    let id = command_with_id.id.ok_or_else(|| {
        error!(target: "mcp_server::proxy_handler", args = ?command_with_id.args, "Proxy command received with no ID. Request is malformed.");
        StatusCode::BAD_REQUEST
    })?;
    debug!(target: "mcp_server::proxy_handler", request_id = %id, args = ?command_with_id.args, "Received valid request to proxy.");

   // Channel for this specific request's response
    let (tx, mut rx) = mpsc::unbounded_channel();
    {
       // Note: state.lock().await can panic if the mutex is poisoned.
       // Consider acquire_state_lock and error conversion if this becomes an issue.
        let mut app_state = state.lock().await;
        app_state.process_queue.push_back(command_with_id);
        app_state.output_map.insert(id, tx);
        if let Err(e) = app_state.trigger.send(()) {
           // This implies the receiver of the trigger (e.g., request_handler or dud_proxy_loop) has been dropped.
           // This is a significant server state issue, suggesting the core polling loops are not running.
           error!(target: "mcp_server::proxy_handler", request_id = %id, error = ?e, "Critical: Failed to send trigger to notify polling loops. The task is queued but might not be processed if polling mechanisms are down.");
           // It's a server-side issue, but the client's request is queued.
           // Proceeding, but this server instance might be unhealthy.
        }
    }

   // Wait for the result from the internal task processing logic (e.g., generic_tool_run via dud_proxy_loop)
   // The timeout here is crucial to prevent holding client connections indefinitely.
    match tokio::time::timeout(LONG_POLL_DURATION + Duration::from_secs(5), rx.recv()).await {
        Ok(Some(Ok(response_str))) => {
           // Successfully received a response string from the internal channel.
           debug!(target: "mcp_server::proxy_handler", request_id = %id, "Successfully received response from internal channel for proxy request.");
           Ok(Json(RunCommandResponse { response: response_str, id }).into_response())
       }
       Ok(Some(Err(mcp_err))) => {
           // An McpError was explicitly sent through the channel, indicating a handled error during tool execution.
           error!(target: "mcp_server::proxy_handler", request_id = %id, error = ?mcp_err, "Error result successfully proxied from tool execution.");
           // Return a structured error to the client.
           let error_response = rmcp::serde_json::json!({
               "type": "proxied_tool_error", // Specific type for errors originating from the tool itself
               "message": mcp_err.to_string(), // Full error string from McpError
           });
           Ok((StatusCode::INTERNAL_SERVER_ERROR, Json(error_response)).into_response())
       }
       Ok(None) => {
            // The MPSC sender `tx` was dropped without a message being sent.
           // This usually indicates an unexpected panic or unhandled error within the task processing logic
           // before it could send either Ok(response_str) or Err(mcp_err).
           error!(target: "mcp_server::proxy_handler", request_id = %id, "Response channel closed prematurely for proxy request. This suggests an unhandled error or panic in the task processing flow.");
           // It's important to attempt cleanup, though the task might have already been removed if a panic unwind did so.
           state.lock().await.output_map.remove(&id);
           let error_response = rmcp::serde_json::json!({
               "type": "internal_server_error",
               "message": "The server encountered an unexpected issue while processing the tool command (response channel closed prematurely).",
           });
           // Using INTERNAL_SERVER_ERROR as this is an unexpected server-side failure.
           // Note: Axum requires the error type for Ok(...) to implement IntoResponse.
           // So we wrap the Json into Ok.
           Ok((StatusCode::INTERNAL_SERVER_ERROR, Json(error_response)).into_response())
       }
       Err(_timeout_err) => {
            // The client's request timed out waiting for the internal processing to complete.
           warn!(target: "mcp_server::proxy_handler", request_id = %id, "Timeout waiting for response from internal channel for proxy request. The tool execution may be too long or stuck.");
           // Crucially, remove the ID from the output_map to prevent a late response from causing issues.
            state.lock().await.output_map.remove(&id);
           let error_response = rmcp::serde_json::json!({
               "type": "gateway_timeout",
               "message": "The request timed out while waiting for the tool execution to complete on the server.",
           });
            // GATEWAY_TIMEOUT is appropriate as this server is acting as a gateway to the tool execution logic.
           Ok((StatusCode::GATEWAY_TIMEOUT, Json(error_response)).into_response())
       }
    }
}

// Helper function to wait for the next task from the queue or an exit signal.
// Returns Option<ToolArguments>, where None signifies an exit condition.
async fn wait_for_next_task_or_exit(
    state: &PackedState,
    exit_rx: &mut Receiver<()>,
) -> Option<ToolArguments> {
    tokio::select! {
        biased; // Process exit signal with higher priority
        _ = exit_rx => {
            info!(target: "mcp_server::dud_proxy_loop::wait_for_task", "Received exit signal.");
            None // Will break the main loop
        }
        // Wait for a new task to be available
        wait_result = async {
            let mut waiter = state.lock().await.waiter.clone();
            waiter.changed().await
        } => {
            match wait_result {
                Ok(_) => { // Notification received, try to pop a task
                    let mut app_state_locked = state.lock().await;
                    app_state_locked.process_queue.pop_front()
                }
                Err(e) => { // Waiter channel closed
                    error!(target: "mcp_server::dud_proxy_loop::wait_for_task", error = ?e, "Waiter channel closed. Exiting.");
                    None // Break the main loop
                }
            }
        }
    }
}

pub async fn dud_proxy_loop(state: PackedState, mut exit_rx: Receiver<()>) {
    let client = reqwest::Client::new();
    info!(target: "mcp_server::dud_proxy_loop", "Dud proxy loop started. Polling for tasks.");

    loop {
        let task_to_proxy = wait_for_next_task_or_exit(&state, &mut exit_rx).await;

        if let Some(ref task_with_id) = task_to_proxy {
            // Ensure task_id is available for all logging and operations
            let task_id = match task_with_id.id {
                Some(id) => id,
                None => {
                    error!(target: "mcp_server::dud_proxy_loop", args = ?task_with_id.args, "Task missing ID in dud_proxy_loop. Skipping.");
                    continue; // Skip this task
                }
            };
            info!(target: "mcp_server::dud_proxy_loop", task_id = %task_id, args = ?task_with_id.args, "Dequeued task for proxying");
            debug!(target: "mcp_server::dud_proxy_loop", task_id = %task_id, args = ?task_with_id.args, "Preparing to send task to /proxy endpoint");

            // Perform the HTTP request and get status/text
            let http_result = send_task_to_plugin(
                &client,
                task_with_id, // task_with_id is passed by reference
                task_id,
            )
            .await;

            match http_result {
                Ok((response_status, response_text)) => {
                    debug!(target: "mcp_server::dud_proxy_loop", task_id = %task_id, response_body = %response_text, "Response body from plugin");
                    process_plugin_response(
                        &state,
                        task_id,
                        response_status,
                        &response_text,
                    )
                    .await;
                }
                Err(request_error) => {
                    // This case covers network errors for the request itself, failure to read the response body, or a timeout.
                    // Error is already logged by send_task_to_plugin.
                    // We need to ensure the task is cleaned up from output_map and an error is sent.
                    let error_message = if request_error.is_timeout() {
                        format!("Dud proxy request to plugin timed out after {}s for task ID {}", DUD_PROXY_REQUEST_TIMEOUT.as_secs(), task_id)
                    } else {
                        format!("Dud proxy failed to send HTTP request or read response body for task ID {}: {}", task_id, request_error)
                    };
                    error!(target: "mcp_server::dud_proxy_loop", task_id = %task_id, error = ?request_error, "{}", error_message);

                    if let Some(response_sender) = state.lock().await.output_map.remove(&task_id) {
                        _ = response_sender.send(Err(McpError::internal_error(error_message, None)));
                    }
                    // Continue to the next task.
                }
            }
        } else {
            // task_to_proxy is None, meaning either exit signal or waiter error.
            info!(target: "mcp_server::dud_proxy_loop", "No task obtained from wait_for_next_task_or_exit. Exiting loop.");
            break;
        }
        // Optional: Sleep can be removed if select/wait provides sufficient backpressure/timing.
        // tokio::time::sleep(Duration::from_millis(10)).await;
     }
     info!(target: "mcp_server::dud_proxy_loop", "Dud proxy loop finished.");
 }

// Helper function to send a task to the plugin via HTTP.
// Returns Ok((status_code, response_body_text)) or Err(reqwest::Error) if the request itself failed.
async fn send_task_to_plugin(
    client: &reqwest::Client,
    task_to_send: &ToolArguments, // Changed from task_with_id for clarity
    task_id: Uuid,                // Passed for logging
) -> std::result::Result<(reqwest::StatusCode, String), reqwest::Error> {
    let request_url = format!("http://127.0.0.1:{}/proxy", STUDIO_PLUGIN_PORT);
    info!(target: "mcp_server::dud_proxy_loop::send_task", task_id = %task_id, url = %request_url, args = ?task_to_send.args, "Sending HTTP POST to plugin");

    let response = client
        .post(&request_url)
        .json(task_to_send)
        .timeout(DUD_PROXY_REQUEST_TIMEOUT) // Apply the request timeout here
        .send()
        .await;

    match response {
        Ok(resp) => {
            let status = resp.status();
            info!(target: "mcp_server::dud_proxy_loop::send_task", task_id = %task_id, status = %status, "Received HTTP response status from plugin");
            match resp.text().await {
                Ok(text) => Ok((status, text)),
                Err(e) => {
                    error!(target: "mcp_server::dud_proxy_loop::send_task", task_id = %task_id, error = ?e, status = %status, "Failed to read response text from plugin");
                    // This error is about reading the body, not the request failing itself.
                    // We'll propagate this as a reqwest::Error for now.
                    Err(e)
                }
            }
        }
        Err(e) => { // HTTP send error
            error!(target: "mcp_server::dud_proxy_loop::send_task", task_id = %task_id, error = ?e, "Failed to send HTTP request to /proxy endpoint");
            Err(e)
        }
    }
}

// Helper function to process the plugin's HTTP response.
async fn process_plugin_response(
    state: &PackedState,
    task_id: Uuid,
    response_status: reqwest::StatusCode,
    response_text: &str,
) {
    if response_status.is_success() {
        match rmcp::serde_json::from_str::<RunCommandResponse>(response_text) {
            Ok(run_command_response) => {
                info!(target: "mcp_server::dud_proxy_loop::process_response", task_id = %task_id, "Successfully decoded response from plugin.");
                if let Some(response_sender) = state.lock().await.output_map.remove(&task_id) {
                    if response_sender.send(Ok(run_command_response.response)).is_err() {
                        error!(target: "mcp_server::dud_proxy_loop::process_response", task_id = %task_id, "Failed to send proxied response to internal channel (channel closed or full)");
                    }
                } else {
                    warn!(target: "mcp_server::dud_proxy_loop::process_response", task_id = %task_id, "No sender found in output_map for proxied task ID.");
                }
            }
            Err(e) => {
                error!(target: "mcp_server::dud_proxy_loop::process_response", task_id = %task_id, error = ?e, status = %response_status, body = %response_text, "Failed to decode RunCommandResponse from /proxy endpoint");
                if let Some(response_sender) = state.lock().await.output_map.remove(&task_id) {
                    _ = response_sender.send(Err(McpError::internal_error(format!("Dud proxy failed to decode plugin response: {}", e), None)));
                }
            }
        }
    } else {
        error!(target: "mcp_server::dud_proxy_loop::process_response", task_id = %task_id, status = %response_status, body = %response_text, "Request to /proxy endpoint failed");
        if let Some(response_sender) = state.lock().await.output_map.remove(&task_id) {
             _ = response_sender.send(Err(McpError::internal_error(format!("Plugin HTTP request failed with status {}", response_status), None)));
        }
    }
}
