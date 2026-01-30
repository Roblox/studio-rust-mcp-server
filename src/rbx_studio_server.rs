use crate::error::Result;
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
use std::collections::{HashMap, VecDeque};
use std::sync::Arc;
use tokio::sync::oneshot::Receiver;
use tokio::sync::{mpsc, watch, Mutex};
use tokio::time::Duration;
use uuid::Uuid;

pub const STUDIO_PLUGIN_PORT: u16 = 44755;
const LONG_POLL_DURATION: Duration = Duration::from_secs(15);

// Script source for auto-installation
const MCP_INPUT_POLLER_SOURCE: &str = r#"-- Auto-installed by MCP Server for input simulation support
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local MCP_URL = "http://localhost:44755/mcp/input"
local POLL_INTERVAL = 0.1

local inputEvent = ReplicatedStorage:FindFirstChild("MCPInputCommand")
if not inputEvent then
    inputEvent = Instance.new("RemoteEvent")
    inputEvent.Name = "MCPInputCommand"
    inputEvent.Parent = ReplicatedStorage
end

local function processCommand(command)
    print("[MCPPoller] Received:", command.command_type)
    for _, player in Players:GetPlayers() do
        inputEvent:FireClient(player, command)
    end
end

local function pollLoop()
    print("[MCPPoller] Started - polling " .. MCP_URL)
    while true do
        local success, result = pcall(function()
            local response = HttpService:GetAsync(MCP_URL)
            return HttpService:JSONDecode(response)
        end)
        if success and result and result.commands then
            if #result.commands > 0 then
                print("[MCPPoller] Got", #result.commands, "commands!")
            end
            for _, command in ipairs(result.commands) do
                processCommand(command)
            end
        end
        task.wait(POLL_INTERVAL)
    end
end

task.spawn(pollLoop)
print("[MCPPoller] Script loaded")
"#;

const MCP_INPUT_HANDLER_SOURCE: &str = r#"-- Auto-installed by MCP Server for input simulation support
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local KEY_MAP = {
    A = Enum.KeyCode.A, B = Enum.KeyCode.B, C = Enum.KeyCode.C, D = Enum.KeyCode.D,
    E = Enum.KeyCode.E, F = Enum.KeyCode.F, G = Enum.KeyCode.G, H = Enum.KeyCode.H,
    I = Enum.KeyCode.I, J = Enum.KeyCode.J, K = Enum.KeyCode.K, L = Enum.KeyCode.L,
    M = Enum.KeyCode.M, N = Enum.KeyCode.N, O = Enum.KeyCode.O, P = Enum.KeyCode.P,
    Q = Enum.KeyCode.Q, R = Enum.KeyCode.R, S = Enum.KeyCode.S, T = Enum.KeyCode.T,
    U = Enum.KeyCode.U, V = Enum.KeyCode.V, W = Enum.KeyCode.W, X = Enum.KeyCode.X,
    Y = Enum.KeyCode.Y, Z = Enum.KeyCode.Z,
    Space = Enum.KeyCode.Space, Return = Enum.KeyCode.Return,
    Tab = Enum.KeyCode.Tab, Escape = Enum.KeyCode.Escape,
    LeftShift = Enum.KeyCode.LeftShift, LeftControl = Enum.KeyCode.LeftControl,
    Up = Enum.KeyCode.Up, Down = Enum.KeyCode.Down,
    Left = Enum.KeyCode.Left, Right = Enum.KeyCode.Right,
}

local MOUSE_MAP = {
    Left = Enum.UserInputType.MouseButton1,
    Right = Enum.UserInputType.MouseButton2,
    Middle = Enum.UserInputType.MouseButton3,
}

local function getEvent(name)
    local e = ReplicatedStorage:FindFirstChild(name)
    if not e then
        e = Instance.new("BindableEvent")
        e.Name = name
        e.Parent = ReplicatedStorage
    end
    return e
end

local function handleKeyboard(data)
    local keyCode = KEY_MAP[data.key]
    if not keyCode then return end
    local event = getEvent("MCPInputReceived")
    local info = { KeyCode = keyCode, UserInputType = Enum.UserInputType.Keyboard }
    if data.action == "tap" then
        info.UserInputState = Enum.UserInputState.Begin
        event:Fire(info)
        task.wait(0.05)
        info.UserInputState = Enum.UserInputState.End
        event:Fire(info)
    else
        info.UserInputState = data.action == "begin" and Enum.UserInputState.Begin or Enum.UserInputState.End
        event:Fire(info)
    end
    print("[MCPInput] Key:", data.key, data.action)
end

local function handleMouse(data)
    local button = MOUSE_MAP[data.key]
    if not button then return end
    local event = getEvent("MCPInputReceived")
    local info = { UserInputType = button, Position = Vector3.new(data.mouseX or 0, data.mouseY or 0, 0) }
    if data.action == "tap" then
        info.UserInputState = Enum.UserInputState.Begin
        event:Fire(info)
        task.wait(0.05)
        info.UserInputState = Enum.UserInputState.End
        event:Fire(info)
    else
        info.UserInputState = data.action == "begin" and Enum.UserInputState.Begin or Enum.UserInputState.End
        event:Fire(info)
    end
    print("[MCPInput] Mouse:", data.key, data.action)
end

local function handleGuiClick(data)
    local current = player.PlayerGui
    for _, part in string.split(data.path, ".") do
        if part ~= "PlayerGui" and part ~= "StarterGui" then
            current = current:FindFirstChild(part)
            if not current then return end
        end
    end
    local event = getEvent("MCPGuiClicked")
    event:Fire({ element = current, path = data.path })
    print("[MCPInput] GUI clicked:", data.path)
end

local inputCommand = ReplicatedStorage:WaitForChild("MCPInputCommand", 10)
if inputCommand then
    inputCommand.OnClientEvent:Connect(function(command)
        local data = command.data
        if command.command_type == "input" then
            if data.inputType == "keyboard" then handleKeyboard(data)
            elseif data.inputType == "mouse" then handleMouse(data) end
        elseif command.command_type == "gui_click" then
            handleGuiClick(data)
        end
    end)
    print("[MCPInput] Client handler ready!")
end
"#;

/// Command for input simulation - queued by MCP tools, polled by game
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct InputCommand {
    pub command_type: String,
    pub data: serde_json::Value,
    pub id: Uuid,
    pub timestamp: u64,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct ToolArguments {
    args: ToolArgumentValues,
    id: Option<Uuid>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct RunCommandResponse {
    response: String,
    id: Uuid,
}

pub struct AppState {
    process_queue: VecDeque<ToolArguments>,
    output_map: HashMap<Uuid, mpsc::UnboundedSender<Result<String>>>,
    waiter: watch::Receiver<()>,
    trigger: watch::Sender<()>,
    pub input_command_queue: VecDeque<InputCommand>,
}
pub type PackedState = Arc<Mutex<AppState>>;

impl AppState {
    pub fn new() -> Self {
        let (trigger, waiter) = watch::channel(());
        Self {
            process_queue: VecDeque::new(),
            output_map: HashMap::new(),
            waiter,
            trigger,
            input_command_queue: VecDeque::new(),
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
struct WriteScript {
    #[schemars(description = "Path to script in game hierarchy (e.g., 'ServerScriptService.GameManager')")]
    path: String,
    #[schemars(description = "The Luau source code to write to the script")]
    source: String,
    #[schemars(description = "Type of script: 'Script', 'LocalScript', or 'ModuleScript'. Defaults to 'Script'.")]
    script_type: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
struct SimulateInput {
    #[schemars(description = "Type of input: 'keyboard' or 'mouse'")]
    input_type: String,
    #[schemars(description = "For keyboard: key name (e.g., 'W', 'Space', 'E'). For mouse: 'Left', 'Right', 'Middle'")]
    key: String,
    #[schemars(description = "Action type: 'begin' (key down), 'end' (key up), or 'tap' (quick press and release)")]
    action: String,
    #[schemars(description = "For mouse input: X position on screen")]
    mouse_x: Option<f64>,
    #[schemars(description = "For mouse input: Y position on screen")]
    mouse_y: Option<f64>,
}

#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
struct ClickGui {
    #[schemars(description = "Path to the GUI element (e.g., 'PlayerGui.MainUI.PlayButton')")]
    path: String,
}

#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
enum ToolArgumentValues {
    RunCode(RunCode),
    InsertModel(InsertModel),
    WriteScript(WriteScript),
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

    #[tool(
        description = "Simulates keyboard or mouse input during playtest. Required scripts (MCPInputPoller, MCPInputHandler) will be auto-installed if missing. Supports keyboard keys (W, A, S, D, Space, E, etc.) and mouse buttons (Left, Right, Middle)."
    )]
    async fn simulate_input(
        &self,
        Parameters(args): Parameters<SimulateInput>,
    ) -> Result<CallToolResult, ErrorData> {
        let (scripts_installed, installed_names) = self.ensure_input_scripts_installed().await;

        let command = InputCommand {
            command_type: "input".to_string(),
            data: serde_json::json!({
                "inputType": args.input_type,
                "key": args.key,
                "action": args.action,
                "mouseX": args.mouse_x,
                "mouseY": args.mouse_y,
            }),
            id: Uuid::new_v4(),
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis() as u64,
        };

        {
            let mut state = self.state.lock().await;
            state.input_command_queue.push_back(command.clone());
        }

        let mut msg = format!(
            "Queued {} input: {} {} (id: {}).",
            args.input_type, args.key, args.action, command.id
        );

        if scripts_installed {
            if let Some(names) = installed_names {
                msg.push_str(&format!(
                    "\n\n✅ Auto-installed required scripts: {}.\nNote: You must restart playtest (stop and F5 again) for the scripts to take effect.",
                    names
                ));
            }
        }

        Ok(CallToolResult::success(vec![Content::text(msg)]))
    }

    #[tool(
        description = "Simulates clicking a GUI element during playtest. Required scripts (MCPInputPoller, MCPInputHandler) will be auto-installed if missing. Provide the path to the GUI element (e.g., 'ScreenGui.PlayButton')."
    )]
    async fn click_gui(
        &self,
        Parameters(args): Parameters<ClickGui>,
    ) -> Result<CallToolResult, ErrorData> {
        let (scripts_installed, installed_names) = self.ensure_input_scripts_installed().await;

        let command = InputCommand {
            command_type: "gui_click".to_string(),
            data: serde_json::json!({ "path": args.path }),
            id: Uuid::new_v4(),
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis() as u64,
        };

        {
            let mut state = self.state.lock().await;
            state.input_command_queue.push_back(command.clone());
        }

        let mut msg = format!("Queued GUI click: {} (id: {}).", args.path, command.id);

        if scripts_installed {
            if let Some(names) = installed_names {
                msg.push_str(&format!(
                    "\n\n✅ Auto-installed required scripts: {}.\nNote: You must restart playtest (stop and F5 again) for the scripts to take effect.",
                    names
                ));
            }
        }

        Ok(CallToolResult::success(vec![Content::text(msg)]))
    }

    async fn ensure_input_scripts_installed(&self) -> (bool, Option<String>) {
        let check_code = r#"
            local poller = game:GetService("ServerScriptService"):FindFirstChild("MCPInputPoller")
            local sps = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
            local handler = sps and sps:FindFirstChild("MCPInputHandler")
            return tostring(poller ~= nil) .. "," .. tostring(handler ~= nil)
        "#;

        let scripts_status = match self.run_tool_raw(ToolArgumentValues::RunCode(RunCode {
            command: check_code.to_string(),
        })).await {
            Ok(status) => status,
            Err(_) => return (false, Some("Failed to check scripts".to_string())),
        };

        let parts: Vec<&str> = scripts_status.trim().split(',').collect();
        let poller_exists = parts.first().map_or(false, |s| s.contains("true"));
        let handler_exists = parts.get(1).map_or(false, |s| s.contains("true"));

        if poller_exists && handler_exists {
            return (false, None);
        }

        let mut installed = Vec::new();

        if !poller_exists {
            if self.run_tool_raw(ToolArgumentValues::WriteScript(WriteScript {
                path: "ServerScriptService.MCPInputPoller".to_string(),
                source: MCP_INPUT_POLLER_SOURCE.to_string(),
                script_type: Some("Script".to_string()),
            })).await.is_err() {
                return (false, Some("Failed to install MCPInputPoller".to_string()));
            }
            installed.push("MCPInputPoller (ServerScriptService)");
        }

        if !handler_exists {
            if self.run_tool_raw(ToolArgumentValues::WriteScript(WriteScript {
                path: "StarterPlayer.StarterPlayerScripts.MCPInputHandler".to_string(),
                source: MCP_INPUT_HANDLER_SOURCE.to_string(),
                script_type: Some("LocalScript".to_string()),
            })).await.is_err() {
                return (false, Some("Failed to install MCPInputHandler".to_string()));
            }
            installed.push("MCPInputHandler (StarterPlayerScripts)");
        }

        (true, if installed.is_empty() { None } else { Some(installed.join(", ")) })
    }

    async fn run_tool_raw(&self, args: ToolArgumentValues) -> std::result::Result<String, String> {
        let (command, id) = ToolArguments::new(args);
        let (tx, mut rx) = mpsc::unbounded_channel::<Result<String>>();
        let trigger = {
            let mut state = self.state.lock().await;
            state.process_queue.push_back(command);
            state.output_map.insert(id, tx);
            state.trigger.clone()
        };

        if trigger.send(()).is_err() {
            return Err("Failed to trigger command".to_string());
        }

        let result = match tokio::time::timeout(Duration::from_secs(30), rx.recv()).await {
            Ok(Some(result)) => result,
            Ok(None) => {
                let mut state = self.state.lock().await;
                state.output_map.remove_entry(&id);
                return Err("Channel closed".to_string());
            }
            Err(_) => {
                let mut state = self.state.lock().await;
                state.output_map.remove_entry(&id);
                return Err("Timeout".to_string());
            }
        };

        {
            let mut state = self.state.lock().await;
            state.output_map.remove_entry(&id);
        }

        result.map_err(|e| e.to_string())
    }

    async fn generic_tool_run(
        &self,
        args: ToolArgumentValues,
    ) -> Result<CallToolResult, ErrorData> {
        let (command, id) = ToolArguments::new(args);
        tracing::debug!("Running command: {:?}", command);
        let (tx, mut rx) = mpsc::unbounded_channel::<Result<String>>();
        let trigger = {
            let mut state = self.state.lock().await;
            state.process_queue.push_back(command);
            state.output_map.insert(id, tx);
            state.trigger.clone()
        };
        trigger
            .send(())
            .map_err(|e| ErrorData::internal_error(format!("Unable to trigger send {e}"), None))?;
        let result = rx
            .recv()
            .await
            .ok_or(ErrorData::internal_error("Couldn't receive response", None))?;
        {
            let mut state = self.state.lock().await;
            state.output_map.remove_entry(&id);
        }
        tracing::debug!("Sending to MCP: {result:?}");
        match result {
            Ok(result) => Ok(CallToolResult::success(vec![Content::text(result)])),
            Err(err) => Ok(CallToolResult::error(vec![Content::text(err.to_string())])),
        }
    }
}

pub async fn request_handler(State(state): State<PackedState>) -> Result<impl IntoResponse> {
    let timeout = tokio::time::timeout(LONG_POLL_DURATION, async {
        loop {
            let mut waiter = {
                let mut state = state.lock().await;
                if let Some(task) = state.process_queue.pop_front() {
                    return Ok::<ToolArguments, Error>(task);
                }
                state.waiter.clone()
            };
            waiter.changed().await?
        }
    })
    .await;
    match timeout {
        Ok(result) => Ok(Json(result?).into_response()),
        _ => Ok((StatusCode::LOCKED, String::new()).into_response()),
    }
}

pub async fn response_handler(
    State(state): State<PackedState>,
    Json(payload): Json<RunCommandResponse>,
) -> Result<impl IntoResponse> {
    tracing::debug!("Received reply from studio {payload:?}");
    let mut state = state.lock().await;
    let tx = state
        .output_map
        .remove(&payload.id)
        .ok_or_eyre("Unknown ID")?;
    Ok(tx.send(Ok(payload.response))?)
}

pub async fn proxy_handler(
    State(state): State<PackedState>,
    Json(command): Json<ToolArguments>,
) -> Result<impl IntoResponse> {
    let id = command.id.ok_or_eyre("Got proxy command with no id")?;
    tracing::debug!("Received request to proxy {command:?}");
    let (tx, mut rx) = mpsc::unbounded_channel();
    {
        let mut state = state.lock().await;
        state.process_queue.push_back(command);
        state.output_map.insert(id, tx);
    }
    let response = rx.recv().await.ok_or_eyre("Couldn't receive response")??;
    {
        let mut state = state.lock().await;
        state.output_map.remove_entry(&id);
    }
    tracing::debug!("Sending back to dud: {response:?}");
    Ok(Json(RunCommandResponse { response, id }))
}

pub async fn dud_proxy_loop(state: PackedState, exit: Receiver<()>) {
    let client = reqwest::Client::new();

    let mut waiter = { state.lock().await.waiter.clone() };
    while exit.is_empty() {
        let entry = { state.lock().await.process_queue.pop_front() };
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
                        .output_map
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

// Input command polling response
#[derive(Debug, Serialize)]
pub struct InputCommandsResponse {
    pub commands: Vec<InputCommand>,
}

/// Handler for GET /mcp/input - Game polls this to get pending input commands
pub async fn input_poll_handler(State(state): State<PackedState>) -> impl IntoResponse {
    let mut state = state.lock().await;
    let commands: Vec<InputCommand> = state.input_command_queue.drain(..).collect();
    Json(InputCommandsResponse { commands })
}
