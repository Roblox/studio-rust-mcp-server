
// Necessary imports
use crate::error::Result;
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{extract::State, Json};
// color_eyre is not directly used, McpError handles errors.


use rmcp::model::{

    ServerCapabilities, ServerInfo, ProtocolVersion, Implementation, Content, CallToolResult,

};
use rmcp::schemars;
use rmcp::tool;
use rmcp::{Error as McpError, ServerHandler};


use std::collections::{HashMap, VecDeque};
// use serde_json::Value; // Likely not needed if serde_json::Map and json! macro are used
use std::path::{Path, PathBuf};
use std::fs;
// use std::env; // Removed as unused

use std::sync::Arc;
// oneshot::Receiver for dud_proxy_loop removed as dud_proxy_loop is removed.
// oneshot::channel is used elsewhere, and its types (Sender, Receiver) are inferred or covered by `use tokio::sync::oneshot;`
use tokio::sync::{mpsc, oneshot}; // watch and Mutex removed as they are no longer used.
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
//
// Defines the duration for which the server holds a client's long poll request (/request handler)
// if no tasks are immediately available via the StateManager. This is not for tool execution itself.
const LONG_POLL_DURATION: Duration = Duration::from_secs(15);

// Defines the maximum time generic_tool_run will wait for a response from the plugin
// (via StateManager) after a task has been dispatched. If a tool execution
// in Roblox Studio takes longer than this, the server will consider it timed out.
// This value may need tuning based on typical plugin tool performance.
const TOOL_EXECUTION_TIMEOUT: Duration = Duration::from_secs(20);

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

// NOTE: Relevant tokio::sync imports (mpsc, oneshot, watch) are expected to be at the top of the file.
// Ensure Uuid, HashMap, VecDeque, Duration, tracing macros are also available.
// ToolArguments, McpError are assumed to be defined or imported in this file.

#[derive(Debug)] // Added Debug for logging
pub enum StateManagerCommand {
    AddTask {
        args: ToolArguments, // Ensure ToolArguments is a known type
        response_channel_tx: oneshot::Sender<Result<String, McpError>>, // Ensure McpError is known
    },
    TryGetTask {
        response_tx: oneshot::Sender<Option<ToolArguments>>,
    },
    PostResponse {
        task_id: Uuid,
        result: Result<String, McpError>,
    },
    CleanupTaskOnTimeout {
        task_id: Uuid,
    },
}

pub struct StateManager {
    process_queue: VecDeque<ToolArguments>,
    output_map: HashMap<Uuid, oneshot::Sender<Result<String, McpError>>>,
    task_waiters: VecDeque<oneshot::Sender<Option<ToolArguments>>>,
    // discovered_luau_tools: HashMap<String, DiscoveredTool>, // If needed
}

impl StateManager {
    pub fn new(/* discovered_luau_tools: HashMap<String, DiscoveredTool> */) -> Self {
        Self {
            process_queue: VecDeque::new(),
            output_map: HashMap::new(),
            task_waiters: VecDeque::new(),
            // discovered_luau_tools,
        }
    }

    pub async fn run(mut self, mut command_rx: mpsc::Receiver<StateManagerCommand>) {
        info!("State Manager started.");
        while let Some(command) = command_rx.recv().await {
            debug!(target: "state_manager", "Received command: {:?}", command);
            match command {
                StateManagerCommand::AddTask { args, response_channel_tx } => {
                    self.handle_add_task(args, response_channel_tx);
                }
                StateManagerCommand::TryGetTask { response_tx } => {
                    self.handle_try_get_task(response_tx);
                }
                StateManagerCommand::PostResponse { task_id, result } => {
                    self.handle_post_response(task_id, result);
                }
                StateManagerCommand::CleanupTaskOnTimeout { task_id } => {
                    self.handle_cleanup_task_on_timeout(task_id);
                }
            }
        }
        info!("State Manager stopped.");
    }


    fn handle_add_task(&mut self, args: ToolArguments, response_channel_tx: oneshot::Sender<Result<String, McpError>>) {
        let task_id = args.id.expect("TaskArguments must have an ID when added by AddTask");
        info!(target: "state_manager", task_id = %task_id, "Handling AddTask.");

        if self.output_map.insert(task_id, response_channel_tx).is_some() {
            warn!(target: "state_manager", task_id = %task_id, "Task ID already existed in output_map. Overwriting.");
        }

        if let Some(waiter_tx) = self.task_waiters.pop_front() {
            debug!(target: "state_manager", task_id = %task_id, "Fulfilling a waiting client with new task.");
            if waiter_tx.send(Some(args)).is_err() {
                warn!(target: "state_manager", task_id = %task_id, "Client that was waiting for task is gone. Task was not queued as it was consumed by send attempt.");
            }
        } else {
            debug!(target: "state_manager", task_id = %task_id, "No clients waiting. Adding task to process_queue.");
            self.process_queue.push_back(args);
        }
    }

    fn handle_try_get_task(&mut self, response_tx: oneshot::Sender<Option<ToolArguments>>) {
        if let Some(task_args) = self.process_queue.pop_front() {
            let task_id = task_args.id.unwrap_or_default(); // Assuming ID exists
            debug!(target: "state_manager", task_id = %task_id, "Dispatching queued task to client (TryGetTask).");
            if response_tx.send(Some(task_args)).is_err() {
                warn!(target: "state_manager", task_id = %task_id, "Client requesting a task (TryGetTask) disappeared. Task popped from queue and not delivered.");
                // Consider re-queueing at front if this is an issue: self.process_queue.push_front(task_args_clone);
            }
        } else {
            debug!(target: "state_manager", "No task in queue. Adding client to waitlist (TryGetTask).");
            self.task_waiters.push_back(response_tx);
        }
    }

    fn handle_post_response(&mut self, task_id: Uuid, result: Result<String, McpError>) {
        info!(target: "state_manager", task_id = %task_id, "Handling PostResponse.");
        if let Some(response_channel_tx) = self.output_map.remove(&task_id) {
            if response_channel_tx.send(result).is_err() {
                warn!(target: "state_manager", task_id = %task_id, "Failed to send result to original requester; receiver was dropped (likely timed out).");
            }
        } else {
            warn!(target: "state_manager", task_id = %task_id, "Received response for task_id not in output_map (already cleaned up or unknown).");
        }
    }

    fn handle_cleanup_task_on_timeout(&mut self, task_id: Uuid) {
        debug!(target: "state_manager", task_id = %task_id, "Handling CleanupTaskOnTimeout.");
        if self.output_map.remove(&task_id).is_none() {
            warn!(target: "state_manager", task_id = %task_id, "CleanupTaskOnTimeout requested for task_id not in output_map.");

        }
    }
}

#[derive(Clone)]
pub struct AxumSharedState {
    pub sm_command_tx: tokio::sync::mpsc::Sender<StateManagerCommand>,
}


// AppState struct and ::new() - REMOVED
// pub type PackedState = Arc<Mutex<AppState>>; - REMOVED
// impl AppState { ... } - REMOVED

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
#[derive(Clone)] // Axum state needs to be cloneable
pub struct RBXStudioServer {
    sm_command_tx: mpsc::Sender<StateManagerCommand>,
    discovered_luau_tools: Arc<HashMap<String, DiscoveredTool>>,
}

impl RBXStudioServer {
    pub fn new(sm_command_tx: mpsc::Sender<StateManagerCommand>, discovered_luau_tools: Arc<HashMap<String, DiscoveredTool>>) -> Self {
        Self { sm_command_tx, discovered_luau_tools }
    }

    // Helper function to acquire the AppState lock with a timeout.
    // This function abstracts the locking mechanism, including timeout and error handling.

    async fn generic_tool_run(&self, args_values: ToolArgumentValues) -> Result<CallToolResult, McpError> {
        let (tool_arguments_with_id, request_id) = ToolArguments::new_with_id(args_values.clone()); // Clone args_values if needed by new_with_id

        info!(target: "mcp_server::generic_tool_run", request_id = %request_id, "Preparing to send AddTask to StateManager.");
        debug!(target: "mcp_server::generic_tool_run", request_id = %request_id, args = ?tool_arguments_with_id.args, "Command details");

        let (response_tx, response_rx) = oneshot::channel::<Result<String, McpError>>();

        let command = StateManagerCommand::AddTask {
            args: tool_arguments_with_id,
            response_channel_tx: response_tx,
        };


        if self.sm_command_tx.send(command).await.is_err() {
            error!(target: "mcp_server::generic_tool_run", request_id = %request_id, "Failed to send AddTask to StateManager. It might have stopped.");
            return Err(McpError::internal_error("StateManager unavailable.", None));
        }

        info!(target: "mcp_server::generic_tool_run", request_id = %request_id, "AddTask sent. Waiting for plugin response via StateManager.");

        // Apply tool execution timeout waiting for the plugin's response via StateManager.
        match tokio::time::timeout(TOOL_EXECUTION_TIMEOUT, response_rx).await {
            Ok(Ok(Ok(response_string))) => { // Timeout didn't occur, oneshot received, Result is Ok(String)
                debug!(target: "mcp_server::generic_tool_run", request_id = %request_id, "Received successful response string from plugin: {}", response_string);
                // Attempt to deserialize response_string into a CallToolResult
                match rmcp::serde_json::from_str::<CallToolResult>(&response_string) {
                    Ok(call_tool_result) => {
                        info!(target: "mcp_server::generic_tool_run", request_id = %request_id, "Successfully deserialized plugin response into CallToolResult.");
                        Ok(call_tool_result) // Return the deserialized CallToolResult
                    }
                    Err(e) => {
                        error!(target: "mcp_server::generic_tool_run", request_id = %request_id, error = %e, "Failed to deserialize plugin response string into CallToolResult: {}", response_string);
                        // Construct an error CallToolResult indicating parsing failure
                        Err(McpError::new(
                            rmcp::model::ErrorCode::PARSE_ERROR, // Or INTERNAL_ERROR if more appropriate
                            format!("Failed to parse plugin response JSON: {}. Raw response: {}", e, response_string),
                            None
                        ))
                    }
                }
            }
            Ok(Ok(Err(mcp_error_from_plugin))) => { // Timeout didn't occur, oneshot received, Result is Err(McpError)
                error!(target: "mcp_server::generic_tool_run", request_id = %request_id, error = ?mcp_error_from_plugin, "Received error response from plugin.");
                // Ok(CallToolResult::error(vec![Content::text(mcp_error_from_plugin.to_string())])) // Original
                Err(mcp_error_from_plugin) // Propagate the McpError directly
            }

            Ok(Err(_oneshot_recv_err)) => { // Timeout didn't occur, but oneshot channel was dropped (StateManager issue)
                error!(target: "mcp_server::generic_tool_run", request_id = %request_id, "Oneshot channel for response dropped by StateManager.");
                Err(McpError::internal_error("StateManager failed to provide response.", None))
            }
            Err(_timeout_elapsed) => { // Timeout occurred waiting for response_rx
                warn!(target: "mcp_server::generic_tool_run", request_id = %request_id, "Timeout waiting for plugin response from StateManager.");
                // Inform StateManager to cleanup
                let cleanup_cmd = StateManagerCommand::CleanupTaskOnTimeout { task_id: request_id };
                if self.sm_command_tx.send(cleanup_cmd).await.is_err() {
                    error!(target: "mcp_server::generic_tool_run", request_id = %request_id, "Failed to send CleanupTaskOnTimeout to StateManager during tool execution timeout handling.");
                }


                Err(McpError::new(rmcp::model::ErrorCode::INTERNAL_ERROR, format!("Tool execution timed out after {}s.", TOOL_EXECUTION_TIMEOUT.as_secs()), None))


            }
        }
    }
}



#[tool(tool_box)]
impl ServerHandler for RBXStudioServer {
    fn get_info(&self) -> ServerInfo {
        let mut tools_list = Vec::new();

        // Define execute_discovered_luau_tool
        let exec_tool_params_props = {
            let mut props = rmcp::serde_json::Map::new();
            props.insert("tool_name".to_string(), rmcp::serde_json::json!({"type": "string", "description": "Name of the Luau tool file (without .luau extension) to execute."}));
            props.insert("tool_arguments_str".to_string(), rmcp::serde_json::json!({"type": "string", "description": "A JSON string representing arguments for the Luau tool."}));
            props
        };

        let mut exec_tool_input_schema_map = rmcp::serde_json::Map::new();
        exec_tool_input_schema_map.insert("type".to_string(), rmcp::serde_json::json!("object"));
        exec_tool_input_schema_map.insert("properties".to_string(), rmcp::serde_json::Value::Object(exec_tool_params_props));
        exec_tool_input_schema_map.insert("required".to_string(), rmcp::serde_json::json!(["tool_name".to_string(), "tool_arguments_str".to_string()]));


        let exec_tool = rmcp::model::Tool {
            name: "execute_discovered_luau_tool".to_string().into(),
            description: Some(format!(
                "Executes a specific Luau tool script by its name. Available Luau tools: [{}]",
                self.discovered_luau_tools.keys().cloned().collect::<Vec<String>>().join(", ")
            ).into()),

            input_schema: std::sync::Arc::new(exec_tool_input_schema_map),
            annotations: None,

        };
        tools_list.push(exec_tool);

        // Define run_command
        let run_cmd_params_props = {
            let mut props = rmcp::serde_json::Map::new();
            props.insert("command".to_string(), rmcp::serde_json::json!({"type": "string", "description": "The Luau code to execute."}));
            props
        };

        let mut run_cmd_input_schema_map = rmcp::serde_json::Map::new();
        run_cmd_input_schema_map.insert("type".to_string(), rmcp::serde_json::json!("object"));
        run_cmd_input_schema_map.insert("properties".to_string(), rmcp::serde_json::Value::Object(run_cmd_params_props));
        run_cmd_input_schema_map.insert("required".to_string(), rmcp::serde_json::json!(["command".to_string()]));

        let run_cmd_tool = rmcp::model::Tool {
            name: "run_command".to_string().into(),
            description: Some("Runs a raw Luau command string in Roblox Studio.".to_string().into()),

            input_schema: std::sync::Arc::new(run_cmd_input_schema_map),
            annotations: None,

        };
        tools_list.push(run_cmd_tool);

        // Define insert_model
        let insert_model_params_props = {
            let mut props = rmcp::serde_json::Map::new();
            props.insert("query".to_string(), rmcp::serde_json::json!({"type": "string", "description": "Query to search for the model."}));
            props
        };

        let mut insert_model_input_schema_map = rmcp::serde_json::Map::new();
        insert_model_input_schema_map.insert("type".to_string(), rmcp::serde_json::json!("object"));
        insert_model_input_schema_map.insert("properties".to_string(), rmcp::serde_json::Value::Object(insert_model_params_props));
        insert_model_input_schema_map.insert("required".to_string(), rmcp::serde_json::json!(["query".to_string()]));

        let insert_model_tool = rmcp::model::Tool {
            name: "insert_model".to_string().into(),
            description: Some("Inserts a model from the Roblox marketplace into the workspace.".to_string().into()),

            input_schema: std::sync::Arc::new(insert_model_input_schema_map),
            annotations: None,

        };
        tools_list.push(insert_model_tool);

        let mut capabilities = ServerCapabilities::default();

        capabilities.tools = Some(rmcp::model::ToolsCapability {
            list_changed: Some(true),
        });


        if self.discovered_luau_tools.is_empty() {
            tracing::warn!("No Luau tools found in RBXStudioServer state during get_info. 'execute_discovered_luau_tool' might not list any specific scripts.");
        }

        ServerInfo {
            protocol_version: ProtocolVersion::V_2025_03_26, // Ensure ProtocolVersion is in scope
            server_info: Implementation::from_build_env(),   // Ensure Implementation is in scope
            instructions: Some(
                format!("Use 'execute_discovered_luau_tool' to run discovered Luau scripts by name. Discovered Luau tools: [{}]. Also available: run_command (direct Luau string), insert_model.",
                    self.discovered_luau_tools.keys().cloned().collect::<Vec<String>>().join(", ")
                ).into()
            ),
            capabilities,
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

        // Access discovered_luau_tools from self (Arc<HashMap<...>>)
        if !self.discovered_luau_tools.contains_key(&tool_name) {
            warn!("Attempted to execute unknown Luau tool: {}", tool_name);
            return Ok(CallToolResult::error(vec![Content::text(format!("Luau tool '{}' not found by server.", tool_name))]));
        }
        // Optional: Log path if needed, from self.discovered_luau_tools.get(&tool_name)
        if let Some(discovered_tool_info) = self.discovered_luau_tools.get(&tool_name) {
             info!(target: "mcp_server::execute_luau", tool_name = %tool_name, script_path = ?discovered_tool_info.file_path, "Found Luau script path from RBXStudioServer state");
        }

        self.generic_tool_run(ToolArgumentValues::ExecuteLuauByName {
            tool_name,
            arguments_json: tool_arguments_str,
        }).await
    }
}

// pub async fn response_handler(State(state): State<PackedState>, Json(payload): Json<RunCommandResponse>) -> Result<impl IntoResponse, StatusCode> { // OLD

pub async fn response_handler(State(axum_state): State<AxumSharedState>, Json(payload): Json<RunCommandResponse>) -> impl IntoResponse { // NEW

    debug!(target: "mcp_server::response_handler", request_id = %payload.id, "Received reply from studio plugin via /response");

    let command = StateManagerCommand::PostResponse {
        task_id: payload.id,
        result: Ok(payload.response), // Assuming success from plugin means Ok here
    };

    if axum_state.sm_command_tx.send(command).await.is_err() {
        error!(target: "mcp_server::response_handler", request_id = %payload.id, "Failed to send PostResponse command to StateManager. StateManager might have stopped.");
        // Return an error response to the plugin, as its response cannot be processed.

        return (StatusCode::INTERNAL_SERVER_ERROR, Json(rmcp::serde_json::json!({
            "type": "internal_server_error",
            "message": "Server failed to process response: StateManager unavailable.",
        }))).into_response();
    }

    // If the command was sent successfully to the StateManager,
    // it's now the StateManager's job to route it.
    // response_handler's job is done for this HTTP request.
    (StatusCode::OK, Json(rmcp::serde_json::json!({"status": "success"}))).into_response()
}

// pub async fn request_handler(State(state): State<PackedState>) -> Result<impl IntoResponse, StatusCode> { // OLD
pub async fn request_handler(State(axum_state): State<AxumSharedState>) -> Result<impl IntoResponse, StatusCode> { // NEW
    debug!(target: "mcp_server::request_handler", "Polling for new task for client.");

    let (response_tx, response_rx) = oneshot::channel::<Option<ToolArguments>>();

    if axum_state.sm_command_tx.send(StateManagerCommand::TryGetTask { response_tx }).await.is_err() {
        error!(target: "mcp_server::request_handler", "Failed to send TryGetTask command to StateManager. StateManager might have stopped.");
        return Ok((StatusCode::INTERNAL_SERVER_ERROR, Json(rmcp::serde_json::json!({
            "type": "internal_server_error",
            "message": "Failed to communicate with StateManager.",
        }))).into_response());
    }


    // Wait for LONG_POLL_DURATION for the StateManager to give us a task
    // Apply long poll timeout waiting for StateManager to provide a task.
    match tokio::time::timeout(LONG_POLL_DURATION, response_rx).await {
        Ok(Ok(Some(task_with_id))) => { // Successfully received a task from StateManager
            debug!(target: "mcp_server::request_handler", task_id = ?task_with_id.id, "Dequeued task for client from StateManager.");
            Ok(Json(task_with_id).into_response())
        }
        Ok(Ok(None)) => {
            // This case should ideally not happen if StateManager sends Some(task) or lets the channel drop on its side if it's shutting down.
            // Or if TryGetTask can explicitly mean "no task right now, but I registered you".
            // For now, treat as no content.
            warn!(target: "mcp_server::request_handler", "Received None task from StateManager, treating as no content.");
            Ok(StatusCode::NO_CONTENT.into_response())
        }
        Ok(Err(_oneshot_recv_err)) => { // Oneshot channel was dropped by StateManager without sending
            error!(target: "mcp_server::request_handler", "StateManager dropped channel while waiting for task. Likely shutting down.");
            Ok((StatusCode::INTERNAL_SERVER_ERROR, Json(rmcp::serde_json::json!({
                "type": "internal_server_error",
                "message": "StateManager shut down or communication failed.",
            }))).into_response())
        }
        Err(_timeout_elapsed) => { // Timeout waiting for response_rx
            debug!(target: "mcp_server::request_handler", "Long poll timed out waiting for task from StateManager.");
            // It's important that StateManager knows this client is no longer waiting.
            // This requires StateManager to handle oneshot channels being dropped by receivers.
            // StateManager's task_waiters VecDeque<oneshot::Sender<Option<ToolArguments>>>: if a sender is dropped,
            // the next time StateManager tries to use it, it will fail. It should then remove it.
            // This timeout is client-side (request_handler timed out). StateManager might still have the waiter_tx.
            // This is tricky. A robust way is for request_handler to send another message "ImNoLongerWaiting"
            // or for StateManager to periodically clean up dropped senders from task_waiters.
            // For now, we rely on oneshot channel drop detection on StateManager's side when it tries to send.
            Ok(StatusCode::NO_CONTENT.into_response())
        }
    }
}
