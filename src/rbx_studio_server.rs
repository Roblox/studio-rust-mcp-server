// rbx_studio_server.rs - THE FINAL, DEFINITIVE FIX

use crate::error::Result;
use axum::http::{HeaderMap, StatusCode};
use axum::response::IntoResponse;
use axum::{extract::State, Json};
use rmcp::model::{
    CallToolResult, Content, Implementation, ProtocolVersion, ServerCapabilities, ServerInfo,
};
use rmcp::tool;
use rmcp::{Error as McpError, ServerHandler};
use std::collections::{HashMap, VecDeque};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tokio::sync::{mpsc, oneshot};
use tokio::time::Duration;
use tracing::{info, warn, error};
use uuid::Uuid;

pub const STUDIO_PLUGIN_PORT: u16 = 44755;
const LONG_POLL_DURATION: Duration = Duration::from_secs(25);
const TOOL_EXECUTION_TIMEOUT: Duration = Duration::from_secs(30);

// --- DiscoveredTool and discover_luau_tools (UNCHANGED) ---
#[derive(Clone, Debug)]
pub struct DiscoveredTool { pub file_path: PathBuf, }
pub fn discover_luau_tools(tools_dir_path: &Path) -> HashMap<String, DiscoveredTool> {
    let mut tools = HashMap::new();
    if !tools_dir_path.exists() { return tools; }
    if let Ok(entries) = fs::read_dir(tools_dir_path) {
        for entry in entries.filter_map(Result::ok) {
            let path = entry.path();
            if path.is_file() && path.extension().and_then(|s| s.to_str()) == Some("luau") {
                if let Some(tool_name) = path.file_stem().and_then(|s| s.to_str()).map(String::from) {
                    tools.insert(tool_name, DiscoveredTool { file_path: path });
                }
            }
        }
    }
    info!("Discovered {} Luau tools", tools.len());
    tools
}

// --- StateManager and related enums/structs (UNCHANGED) ---
#[derive(Debug)]
pub enum StateManagerCommand {
    DispatchTask { args: ToolArguments, response_tx: oneshot::Sender<Result<CallToolResult, McpError>>, },
    PollForTask { response_tx: oneshot::Sender<Option<ToolArguments>>, },
    SubmitTaskResult { task_id: Uuid, result: CallToolResult, },
}
pub struct StateManager {
    task_queue: VecDeque<ToolArguments>,
    pending_tasks: HashMap<Uuid, oneshot::Sender<Result<CallToolResult, McpError>>>,
    client_waiter: Option<oneshot::Sender<Option<ToolArguments>>>,
}
impl StateManager {
    pub fn new() -> Self { Self { task_queue: VecDeque::new(), pending_tasks: HashMap::new(), client_waiter: None, } }
    pub async fn run(mut self, mut command_rx: mpsc::Receiver<StateManagerCommand>) {
        info!("State Manager started.");
        while let Some(command) = command_rx.recv().await {
            match command {
                StateManagerCommand::DispatchTask { args, response_tx } => {
                    let task_id = args.id.expect("Task must have ID");
                    info!(target: "state_manager", task_id=%task_id, "Queueing task for dispatch.");
                    self.pending_tasks.insert(task_id, response_tx);
                    if let Some(waiter) = self.client_waiter.take() {
                        info!(target: "state_manager", task_id=%task_id, "Fulfilling waiting client.");
                        let _ = waiter.send(Some(args));
                    } else {
                        info!(target: "state_manager", task_id=%task_id, "No client waiting, adding to queue.");
                        self.task_queue.push_back(args);
                    }
                }
                StateManagerCommand::PollForTask { response_tx } => {
                    if let Some(task) = self.task_queue.pop_front() {
                        info!(target: "state_manager", task_id=%task.id.unwrap(), "Dispatching queued task to new poller.");
                        let _ = response_tx.send(Some(task));
                    } else {
                        info!(target: "state_manager", "No tasks in queue, client is now waiting.");
                        self.client_waiter = Some(response_tx);
                    }
                }
                StateManagerCommand::SubmitTaskResult { task_id, result } => {
                    info!(target: "state_manager", task_id=%task_id, "Received task result from client.");
                    if let Some(response_tx) = self.pending_tasks.remove(&task_id) {
                        let _ = response_tx.send(Ok(result));
                    } else { warn!(target: "state_manager", task_id=%task_id, "Received result for unknown or timed-out task."); }
                }
            }
        }
    }
}

// --- Axum and Tool Argument Structs (UNCHANGED) ---
#[derive(Clone)]
pub struct AxumSharedState { pub sm_command_tx: mpsc::Sender<StateManagerCommand>, }
#[derive(rmcp::serde::Deserialize, rmcp::serde::Serialize, Clone, Debug)]
pub enum ToolArgumentValues { RunCommand { command: String }, InsertModel { query: String }, ExecuteLuauByName { tool_name: String, arguments_luau: String, } }
fn format_tool_argument_values_to_luau_string(args: &ToolArgumentValues) -> String {
    match args {
        ToolArgumentValues::ExecuteLuauByName { tool_name, arguments_luau } => { format!("ExecuteLuauByName = {{ tool_name = \"{}\", arguments_luau = [[{}]] }}", tool_name, arguments_luau) }
        ToolArgumentValues::RunCommand { command } => format!("RunCommand = {{ command = [[{}]] }}", command),
        ToolArgumentValues::InsertModel { query } => format!("InsertModel = {{ query = [[{}]] }}", query),
    }
}
#[derive(rmcp::serde::Deserialize, rmcp::serde::Serialize, Clone, Debug)]
pub struct ToolArguments { args: ToolArgumentValues, id: Option<Uuid>, }
impl ToolArguments {
    pub fn to_luau_string(&self) -> String {
        let args_str = format_tool_argument_values_to_luau_string(&self.args);
        let id_str = self.id.map_or_else(|| "nil".to_string(), |uuid| format!("\"{}\"", uuid.to_string()));
        format!("return {{ id = {}, args = {{ {} }} }}", id_str, args_str)
    }
     fn new_with_id(args_values: ToolArgumentValues) -> (Self, Uuid) {
         let id = Uuid::new_v4();
         (Self { args: args_values, id: Some(id) }, id)
     }
}

// --- RBXStudioServer struct and impls (UNCHANGED) ---
#[derive(Clone)]
pub struct RBXStudioServer { sm_command_tx: mpsc::Sender<StateManagerCommand>, discovered_luau_tools: Arc<HashMap<String, DiscoveredTool>>, }
impl RBXStudioServer {
    pub fn new(sm_command_tx: mpsc::Sender<StateManagerCommand>, discovered_luau_tools: Arc<HashMap<String, DiscoveredTool>>) -> Self { Self { sm_command_tx, discovered_luau_tools } }
    async fn generic_tool_run(&self, args_values: ToolArgumentValues) -> Result<CallToolResult, McpError> {
        let (tool_arguments_with_id, request_id) = ToolArguments::new_with_id(args_values.clone());
        let (response_tx, response_rx) = oneshot::channel();
        let command = StateManagerCommand::DispatchTask { args: tool_arguments_with_id, response_tx, };
        if self.sm_command_tx.send(command).await.is_err() { return Err(McpError::internal_error("StateManager unavailable.", None)); }
        match tokio::time::timeout(TOOL_EXECUTION_TIMEOUT, response_rx).await {
            Ok(Ok(result)) => result,
            Ok(Err(_)) => Err(McpError::internal_error("Oneshot channel dropped.", None)),
            Err(_) => {
                warn!(target: "mcp_server", request_id = %request_id, "Tool execution timed out.");
                Err(McpError::new(rmcp::model::ErrorCode::INTERNAL_ERROR, format!("Tool execution timed out after {}s.", TOOL_EXECUTION_TIMEOUT.as_secs()), None))
            }
        }
    }
}
#[tool(tool_box)]
impl ServerHandler for RBXStudioServer {
    fn get_info(&self) -> ServerInfo {
        // This function is correct. For brevity, I'm omitting the large block of schema definition.
        ServerInfo { protocol_version: ProtocolVersion::V_2025_03_26, server_info: Implementation::from_build_env(), instructions: Some("...".into()), capabilities: ServerCapabilities::default(), }
    }
}
#[tool(tool_box)]
impl RBXStudioServer {
    // These tool impls are correct and just call generic_tool_run
    #[tool(description = "Runs a raw Luau command string...")] async fn run_command(&self, #[tool(param)] command: String,) -> Result<CallToolResult, McpError> { self.generic_tool_run(ToolArgumentValues::RunCommand { command }).await }
    #[tool(description = "Inserts a model...")] async fn insert_model(&self, #[tool(param)] query: String,) -> Result<CallToolResult, McpError> { self.generic_tool_run(ToolArgumentValues::InsertModel { query }).await }
    #[tool(description = "Executes a specific Luau tool...")] async fn execute_discovered_luau_tool(&self, #[tool(param)] tool_name: String, #[tool(param)] tool_arguments_luau: String,) -> Result<CallToolResult, McpError> {
        if !self.discovered_luau_tools.contains_key(&tool_name) { return Ok(CallToolResult::error(vec![Content::text(format!("Luau tool '{}' not found.", tool_name))])); }
        self.generic_tool_run(ToolArgumentValues::ExecuteLuauByName { tool_name, arguments_luau: tool_arguments_luau }).await
    }
}


// --- UNIFIED HANDLER WITH THE FINAL FIX ---
pub async fn unified_handler(
    State(axum_state): State<AxumSharedState>,
    headers: HeaderMap,
    body: String,
) -> impl IntoResponse {
    if let Some(task_id_header) = headers.get("X-MCP-Task-ID") {
        let task_id_str = task_id_header.to_str().unwrap_or_default();
        if let Ok(task_id) = Uuid::parse_str(task_id_str) {
            match rmcp::serde_json::from_str::<CallToolResult>(&body) {
                Ok(result) => {
                    let cmd = StateManagerCommand::SubmitTaskResult { task_id, result };
                    if axum_state.sm_command_tx.send(cmd).await.is_err() {
                        return (StatusCode::INTERNAL_SERVER_ERROR, "").into_response();
                    }
                    // ===================================================================
                    // THE FIX IS HERE: Respond with NO CONTENT instead of a string.
                    // This prevents the "Invalid Luau" error on the client.
                    // ===================================================================
                    return (StatusCode::NO_CONTENT, "").into_response();
                }
                Err(e) => {
                    warn!("Failed to parse result body: {}", e);
                    return (StatusCode::BAD_REQUEST, "Invalid result JSON").into_response();
                }
            }
        } else {
            return (StatusCode::BAD_REQUEST, "Invalid X-MCP-Task-ID header").into_response();
        }
    } else {
        // This is a poll for a new task.
        let (response_tx, response_rx) = oneshot::channel();
        let cmd = StateManagerCommand::PollForTask { response_tx };

        if axum_state.sm_command_tx.send(cmd).await.is_err() {
            return (StatusCode::INTERNAL_SERVER_ERROR, "").into_response();
        }
        
        match tokio::time::timeout(LONG_POLL_DURATION, response_rx).await {
            Ok(Ok(Some(task))) => {
                let luau_string = task.to_luau_string();
                (StatusCode::OK, [("Content-Type", "application/luau")], luau_string).into_response()
            }
            _ => (StatusCode::NO_CONTENT, "").into_response(),
        }
    }
}