use crate::error::Result;
use axum::extract::Query;
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{extract::State, Json};
use color_eyre::eyre::{Error, OptionExt};
use rmcp::{
    handler::server::{router::tool::ToolRouter, wrapper::Parameters},
    model::{
        CallToolResult, Content, Implementation, ProtocolVersion, ServerCapabilities, ServerInfo,
    },
    schemars, tool, tool_handler, tool_router, ErrorData, ServerHandler,
};
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;
use std::collections::{HashMap, VecDeque};
use std::sync::Arc;
use std::time::Instant;
use tokio::sync::oneshot::Receiver;
use tokio::sync::{mpsc, watch, Mutex};
use tokio::time::Duration;
use uuid::Uuid;

pub const STUDIO_PLUGIN_PORT: u16 = 44755;
const LONG_POLL_DURATION: Duration = Duration::from_secs(15);
/// If we haven't seen activity from a client (poll start or loop iteration) for this long, remove them.
const CLIENT_POLL_MAX_GAP: Duration = Duration::from_secs(5);

/// DataModel context for a registered client: Edit (place), Client (play client), Server (play server).
#[derive(Deserialize, Serialize, Clone, Debug, PartialEq, Eq)]
#[serde(rename_all = "PascalCase")]
pub enum DataModelType {
    Edit,
    Client,
    Server,
}

impl std::fmt::Display for DataModelType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DataModelType::Edit => write!(f, "Edit"),
            DataModelType::Client => write!(f, "Client"),
            DataModelType::Server => write!(f, "Server"),
        }
    }
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct ToolArguments {
    args: ToolArgumentValues,
    id: Option<Uuid>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct RunCommandResponse {
    pub response: String,
    pub id: Uuid,
    /// Required when sending from Lua (/response). Omitted in server-to-server proxy responses.
    #[serde(default)]
    pub client_id: Option<Uuid>,
}

/// Event delivered to a client on long poll: either a tool call (Edit only) or a Roblox event bridge message.
#[derive(Clone, Debug)]
pub enum ClientEvent {
    ToolCall(ToolArguments),
    RobloxEventBridge(JsonValue),
}

/// Per-client state: queue of events, notifier for long poll, and pending tool response channels.
pub struct ClientState {
    pub datamodel_type: DataModelType,
    pub queue: VecDeque<ClientEvent>,
    pub trigger: watch::Sender<()>,
    /// tool call id -> response sender for tool calls delivered to this client
    pub output_map: HashMap<Uuid, mpsc::UnboundedSender<Result<String>>>,
    /// Last time this client's long poll ended (we returned a response or 423). Used for stale pruning.
    pub last_poll_at: Instant,
    /// True while this client has an active long poll (we are inside request_handler for them). Never prune while true.
    pub in_poll: bool,
}

/// Global state: registered clients. Lua sends client_id on /response so we route to the correct client's output_map.
/// When no Edit client is available, proxy_queue + proxy_output_map are used (dud mode).
pub struct AppState {
    /// client_id -> client state
    clients: HashMap<Uuid, ClientState>,
    /// When we're the dud: queue of tool calls to POST to the other server's /proxy
    pub proxy_queue: VecDeque<ToolArguments>,
    /// Notify dud_proxy_loop when proxy_queue has work
    pub proxy_trigger: watch::Sender<()>,
    /// Dud mode only: tool call id -> response sender (when no Edit client)
    pub proxy_output_map: HashMap<Uuid, mpsc::UnboundedSender<Result<String>>>,
}

pub type PackedState = Arc<Mutex<AppState>>;

impl AppState {
    pub fn new() -> Self {
        let (proxy_trigger, _) = watch::channel(());
        Self {
            clients: HashMap::new(),
            proxy_queue: VecDeque::new(),
            proxy_trigger,
            proxy_output_map: HashMap::new(),
        }
    }

    /// Remove clients that have not had a long poll end within CLIENT_POLL_MAX_GAP. Never remove a client whose long poll is still pending (in_poll).
    fn prune_stale_clients(&mut self) {
        let now = Instant::now();
        self.clients.retain(|_, c| {
            c.in_poll || now.duration_since(c.last_poll_at) <= CLIENT_POLL_MAX_GAP
        });
    }

    /// Returns the first registered Edit client (after pruning stale clients). Used to send tool calls.
    fn get_edit_client_id(&mut self) -> Option<Uuid> {
        self.prune_stale_clients();
        self.clients
            .iter()
            .find(|(_, c)| c.datamodel_type == DataModelType::Edit)
            .map(|(id, _)| *id)
    }

    /// Register a client; returns its client_id.
    pub fn register(&mut self, datamodel_type: DataModelType) -> Uuid {
        let client_id = Uuid::new_v4();
        let (trigger, _waiter) = watch::channel(());
        self.clients.insert(
            client_id,
            ClientState {
                datamodel_type,
                queue: VecDeque::new(),
                trigger,
                output_map: HashMap::new(),
                last_poll_at: Instant::now(),
                in_poll: false,
            },
        );
        client_id
    }

    /// Remove client and clear its state.
    pub fn unregister(&mut self, client_id: Uuid) -> bool {
        self.clients.remove(&client_id).is_some()
    }

    /// Push a tool call: to Edit client's queue if we have one (by datamodel_type), else to proxy_queue (dud mode).
    pub fn push_tool_call(
        &mut self,
        command: ToolArguments,
        tx: mpsc::UnboundedSender<Result<String>>,
    ) -> Result<(), Error> {
        let id = command.id.ok_or_eyre("Tool call must have id")?;
        if let Some(edit_id) = self.get_edit_client_id() {
            if let Some(client) = self.clients.get_mut(&edit_id) {
                client.queue.push_back(ClientEvent::ToolCall(command));
                client.output_map.insert(id, tx);
                let _ = client.trigger.send(());
                return Ok(());
            }
        }
        // Dud mode: no Edit client; queue for proxy loop
        self.proxy_queue.push_back(command);
        self.proxy_output_map.insert(id, tx);
        let _ = self.proxy_trigger.send(());
        Ok(())
    }

    /// Broadcast an event to all connected clients (including sender). Prunes stale clients first.
    pub fn broadcast(&mut self, event: JsonValue) {
        self.prune_stale_clients();
        for client in self.clients.values_mut() {
            client.queue.push_back(ClientEvent::RobloxEventBridge(event.clone()));
            let _ = client.trigger.send(());
        }
    }
}

impl ToolArguments {
    fn new(args: ToolArgumentValues) -> (Self, Uuid) {
        Self { args, id: None }.with_id()
    }
    fn with_id(self) -> (Self, Uuid) {
        let id = Uuid::new_v4();
        (
            Self {
                args: self.args,
                id: Some(id),
            },
            id,
        )
    }
}

/// Response body for long poll: either a tool call (same shape as before) or a Roblox event bridge message.
#[derive(Serialize)]
#[serde(untagged)]
pub enum LongPollResponse {
    ToolCall(ToolArguments),
    RobloxEventBridge {
        #[serde(rename = "type")]
        typ: &'static str,
        event: JsonValue,
    },
}

impl From<ClientEvent> for LongPollResponse {
    fn from(e: ClientEvent) -> Self {
        match e {
            ClientEvent::ToolCall(args) => LongPollResponse::ToolCall(args),
            ClientEvent::RobloxEventBridge(event) => LongPollResponse::RobloxEventBridge {
                typ: "roblox_event_bridge",
                event,
            },
        }
    }
}
#[derive(Clone)]
pub struct RBXStudioServer {
    state: PackedState,
    tool_router: ToolRouter<Self>,
}

#[tool_handler]
impl ServerHandler for RBXStudioServer {
    fn get_info(&self) -> ServerInfo {
        ServerInfo {
            protocol_version: ProtocolVersion::LATEST,
            capabilities: ServerCapabilities::builder().enable_tools().build(),
            server_info: Implementation {
                name: "Roblox_Studio".to_string(),
                version: env!("CARGO_PKG_VERSION").to_string(),
                title: Some("Roblox Studio MCP Server".to_string()),
                icons: None,
                website_url: None,
            },
            instructions: Some(
                "User run_command to query data from Roblox Studio place or to change it"
                    .to_string(),
            ),
        }
    }
}

#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
struct RunCode {
    #[schemars(description = "Code to run")]
    command: String,
}
#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
struct InsertModel {
    #[schemars(description = "Query to search for the model")]
    query: String,
}

#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
struct GetConsoleOutput {}

#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
struct GetStudioMode {}

#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
struct StartStopPlay {
    #[schemars(description = "Mode to start or stop, must be start_play, stop, or run_server")]
    mode: String,
}

#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
struct RunScriptInPlayMode {
    #[schemars(description = "Code to run")]
    code: String,
    #[schemars(description = "Timeout in seconds, defaults to 100 seconds")]
    timeout: Option<u32>,
    #[schemars(description = "Mode to run in, must be start_play or run_server")]
    mode: String,
}

#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
enum ToolArgumentValues {
    RunCode(RunCode),
    InsertModel(InsertModel),
    GetConsoleOutput(GetConsoleOutput),
    StartStopPlay(StartStopPlay),
    RunScriptInPlayMode(RunScriptInPlayMode),
    GetStudioMode(GetStudioMode),
}
#[tool_router]
impl RBXStudioServer {
    pub fn new(state: PackedState) -> Self {
        Self {
            state,
            tool_router: Self::tool_router(),
        }
    }

    #[tool(
        description = "Runs a command in Roblox Studio and returns the printed output. Can be used to both make changes and retrieve information"
    )]
    async fn run_code(
        &self,
        Parameters(args): Parameters<RunCode>,
    ) -> Result<CallToolResult, ErrorData> {
        self.generic_tool_run(ToolArgumentValues::RunCode(args))
            .await
    }

    #[tool(
        description = "Inserts a model from the Roblox marketplace into the workspace. Returns the inserted model name."
    )]
    async fn insert_model(
        &self,
        Parameters(args): Parameters<InsertModel>,
    ) -> Result<CallToolResult, ErrorData> {
        self.generic_tool_run(ToolArgumentValues::InsertModel(args))
            .await
    }

    #[tool(description = "Get the console output from Roblox Studio.")]
    async fn get_console_output(
        &self,
        Parameters(args): Parameters<GetConsoleOutput>,
    ) -> Result<CallToolResult, ErrorData> {
        self.generic_tool_run(ToolArgumentValues::GetConsoleOutput(args))
            .await
    }

    #[tool(description = "Start or stop play mode or run the server.")]
    async fn start_stop_play(
        &self,
        Parameters(args): Parameters<StartStopPlay>,
    ) -> Result<CallToolResult, ErrorData> {
        self.generic_tool_run(ToolArgumentValues::StartStopPlay(args))
            .await
    }

    #[tool(
        description = "Run a script in play mode and automatically stop play after script finishes or timeout. Returns the output of the script.
        Result format: { success: boolean, value: string, error: string, logs: { level: string, message: string, ts: number }[], errors: { level: string, message: string, ts: number }[], duration: number, isTimeout: boolean }"
    )]
    async fn run_script_in_play_mode(
        &self,
        Parameters(args): Parameters<RunScriptInPlayMode>,
    ) -> Result<CallToolResult, ErrorData> {
        self.generic_tool_run(ToolArgumentValues::RunScriptInPlayMode(args))
            .await
    }

    #[tool(
        description = "Get the current studio mode. Returns the studio mode. The result will be one of start_play, run_server, or stop."
    )]
    async fn get_studio_mode(
        &self,
        Parameters(args): Parameters<GetStudioMode>,
    ) -> Result<CallToolResult, ErrorData> {
        self.generic_tool_run(ToolArgumentValues::GetStudioMode(args))
            .await
    }

    async fn generic_tool_run(
        &self,
        args: ToolArgumentValues,
    ) -> Result<CallToolResult, ErrorData> {
        let (command, _id) = ToolArguments::new(args);
        tracing::debug!("Running command: {:?}", command);
        let (tx, mut rx) = mpsc::unbounded_channel::<Result<String>>();
        {
            let mut state = self.state.lock().await;
            state
                .push_tool_call(command, tx)
                .map_err(|e| ErrorData::internal_error(e.to_string(), None))?;
        }
        let result = rx
            .recv()
            .await
            .ok_or(ErrorData::internal_error("Couldn't receive response", None))?;
        tracing::debug!("Sending to MCP: {result:?}");
        match result {
            Ok(result) => Ok(CallToolResult::success(vec![Content::text(result)])),
            Err(err) => Ok(CallToolResult::error(vec![Content::text(err.to_string())])),
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct RequestQuery {
    pub client_id: Uuid,
}

pub async fn request_handler(
    State(state): State<PackedState>,
    Query(query): Query<RequestQuery>,
) -> Result<impl IntoResponse> {
    let client_id = query.client_id;
    let mut waiter = {
        let mut guard = state.lock().await;
        guard.prune_stale_clients();
        let client = guard.clients.get_mut(&client_id);
        match client {
            Some(c) => {
                c.in_poll = true;
                c.trigger.subscribe()
            }
            None => {
                return Ok((
                    StatusCode::NOT_FOUND,
                    format!("Unknown client_id {}", client_id),
                )
                    .into_response())
            }
        }
    };
    let timeout = tokio::time::timeout(LONG_POLL_DURATION, async {
        loop {
            {
                let mut guard = state.lock().await;
                if let Some(client) = guard.clients.get_mut(&client_id) {
                    if let Some(event) = client.queue.pop_front() {
                        return Ok::<LongPollResponse, Error>(event.into());
                    }
                } else {
                    return Err(Error::msg("Client unregistered during poll"));
                }
            }
            waiter.changed().await?;
        }
    })
    .await;

    // Mark this client's long poll as ended (so we only consider the gap from poll end, not while pending).
    let mut guard = state.lock().await;
    if let Some(c) = guard.clients.get_mut(&client_id) {
        c.in_poll = false;
        c.last_poll_at = Instant::now();
    }
    match timeout {
        Ok(Ok(response)) => Ok(Json(response).into_response()),
        Ok(Err(e)) => Ok((
            StatusCode::GONE,
            format!("Client gone or error: {}", e),
        )
            .into_response()),
        _ => Ok((StatusCode::LOCKED, String::new()).into_response()),
    }
}

#[derive(Debug, Deserialize)]
pub struct RegisterBody {
    pub datamodel_type: DataModelType,
}

#[derive(Debug, Serialize)]
pub struct RegisterResponse {
    pub client_id: Uuid,
}

pub async fn register_handler(
    State(state): State<PackedState>,
    Json(body): Json<RegisterBody>,
) -> Result<impl IntoResponse> {
    let client_id = {
        let mut guard = state.lock().await;
        guard.register(body.datamodel_type)
    };
    Ok(Json(RegisterResponse { client_id }))
}

#[derive(Debug, Deserialize)]
pub struct UnregisterBody {
    pub client_id: Uuid,
}

pub async fn unregister_handler(
    State(state): State<PackedState>,
    Json(body): Json<UnregisterBody>,
) -> Result<impl IntoResponse> {
    let removed = {
        let mut guard = state.lock().await;
        guard.unregister(body.client_id)
    };
    if removed {
        Ok(StatusCode::OK.into_response())
    } else {
        Ok((StatusCode::NOT_FOUND, "Unknown client_id").into_response())
    }
}

/// Unified body for POST /response: either a tool call return or a broadcast.
#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ResponseBody {
    /// Tool call result from the plugin.
    ToolCallResponse {
        client_id: Uuid,
        id: Uuid,
        response: String,
    },
    /// Roblox event bridge: broadcast event to all connected clients (including sender).
    RobloxEventBridge {
        client_id: Uuid,
        event: JsonValue,
    },
}

pub async fn response_handler(
    State(state): State<PackedState>,
    Json(body): Json<ResponseBody>,
) -> Result<impl IntoResponse> {
    match body {
        ResponseBody::ToolCallResponse {
            client_id,
            id,
            response,
        } => {
            tracing::debug!("Received reply from studio client_id={client_id} id={id}");
            let mut guard = state.lock().await;
            guard.prune_stale_clients();
            let tx = guard
                .clients
                .get_mut(&client_id)
                .and_then(|c| c.output_map.remove(&id))
                .ok_or_eyre("Unknown client_id or tool id")?;
            tx.send(Ok(response))?;
            Ok(StatusCode::OK.into_response())
        }
        ResponseBody::RobloxEventBridge { client_id, event } => {
            let mut guard = state.lock().await;
            guard.prune_stale_clients();
            if !guard.clients.contains_key(&client_id) {
                return Ok((StatusCode::NOT_FOUND, "Unknown client_id").into_response());
            }
            guard.broadcast(event);
            Ok(StatusCode::OK.into_response())
        }
    }
}

pub async fn proxy_handler(
    State(state): State<PackedState>,
    Json(command): Json<ToolArguments>,
) -> Result<impl IntoResponse> {
    let id = command.id.ok_or_eyre("Got proxy command with no id")?;
    tracing::debug!("Received request to proxy {command:?}");
    let (tx, mut rx) = mpsc::unbounded_channel();
    {
        let mut guard = state.lock().await;
        if let Err(e) = guard.push_tool_call(command, tx) {
            return Ok((
                StatusCode::SERVICE_UNAVAILABLE,
                e.to_string(),
            )
                .into_response());
        }
    }
    let response = rx.recv().await.ok_or_eyre("Couldn't receive response")??;
    tracing::debug!("Sending back to proxy client: {response:?}");
    Ok(Json(RunCommandResponse {
        response,
        id,
        client_id: None,
    })
    .into_response())
}

pub async fn dud_proxy_loop(state: PackedState, exit: Receiver<()>) {
    let client = reqwest::Client::new();

    let mut waiter = { state.lock().await.proxy_trigger.subscribe() };
    while exit.is_empty() {
        let entry = { state.lock().await.proxy_queue.pop_front() };
        if let Some(entry) = entry {
            let res = client
                .post(format!("http://127.0.0.1:{STUDIO_PLUGIN_PORT}/proxy"))
                .json(&entry)
                .send()
                .await;
            if let Ok(res) = res {
                let tx = {
                    state
                        .lock()
                        .await
                        .proxy_output_map
                        .remove(&entry.id.unwrap())
                        .unwrap()
                };
                let res = res
                    .json::<RunCommandResponse>()
                    .await
                    .map(|r| r.response)
                    .map_err(Into::into);
                tx.send(res).unwrap();
            } else {
                tracing::error!("Failed to proxy: {res:?}");
            };
        } else {
            waiter.changed().await.unwrap();
        }
    }
}
