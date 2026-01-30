use crate::error::Result;
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{extract::State, Json};
use base64::Engine;
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

// Screenshot configuration
const SCREENSHOT_MAX_DIMENSION: u32 = 1920;
const SCREENSHOT_JPEG_QUALITY: u8 = 85;
const SCREENSHOT_TIMEOUT_SECS: u64 = 10;

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
struct CaptureScreenshot {
    // No parameters - captures the Roblox Studio window
}

#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
enum ToolArgumentValues {
    RunCode(RunCode),
    InsertModel(InsertModel),
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
        description = "Captures a screenshot of the Roblox Studio window and returns it as a JPEG image. Useful for visual debugging, verifying UI changes, or analyzing the workspace layout."
    )]
    async fn capture_screenshot(
        &self,
        Parameters(_args): Parameters<CaptureScreenshot>,
    ) -> Result<CallToolResult, ErrorData> {
        // Rust-only implementation - no plugin communication needed
        match Self::take_studio_screenshot().await {
            Ok(base64_data) => Ok(CallToolResult::success(vec![Content::image(
                base64_data,
                "image/jpeg",
            )])),
            Err(e) => Ok(CallToolResult::error(vec![Content::text(format!(
                "Failed to capture screenshot: {}",
                e
            ))])),
        }
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

    /// Process an image: resize to fit within max dimensions and encode as JPEG base64
    fn process_screenshot(img: image::DynamicImage) -> Result<String, Error> {
        let resized = img.resize(
            SCREENSHOT_MAX_DIMENSION,
            SCREENSHOT_MAX_DIMENSION,
            image::imageops::FilterType::Lanczos3,
        );

        let mut buffer = Vec::new();
        let rgb_image = resized.to_rgb8();
        let encoder =
            image::codecs::jpeg::JpegEncoder::new_with_quality(&mut buffer, SCREENSHOT_JPEG_QUALITY);
        rgb_image.write_with_encoder(encoder)?;

        Ok(base64::engine::general_purpose::STANDARD.encode(&buffer))
    }

    #[cfg(target_os = "macos")]
    async fn take_studio_screenshot() -> Result<String, Error> {
        use std::fs;
        use std::io::Write;
        use tokio::process::Command;

        let temp_screenshot =
            std::env::temp_dir().join(format!("roblox_studio_{}.png", Uuid::new_v4()));
        let temp_swift =
            std::env::temp_dir().join(format!("get_window_{}.swift", Uuid::new_v4()));

        let swift_script = r#"
import Cocoa
import CoreGraphics

let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

for window in windowList {
    if let ownerName = window[kCGWindowOwnerName as String] as? String,
       ownerName.contains("Roblox"),
       let windowName = window[kCGWindowName as String] as? String,
       windowName.contains("Roblox Studio"),
       let windowNumber = window[kCGWindowNumber as String] as? Int {
        print(windowNumber)
        exit(0)
    }
}
exit(1)
"#;

        let mut swift_file = fs::File::create(&temp_swift)?;
        swift_file.write_all(swift_script.as_bytes())?;
        drop(swift_file);

        let window_id_result = tokio::time::timeout(
            Duration::from_secs(SCREENSHOT_TIMEOUT_SECS),
            Command::new("swift").arg(&temp_swift).output(),
        )
        .await
        .map_err(|_| Error::msg("Timed out while finding Roblox Studio window"))?;

        let window_id_output = window_id_result?;
        let _ = fs::remove_file(&temp_swift);

        if !window_id_output.status.success() {
            return Err(Error::msg(
                "Roblox Studio window not found. Please ensure Roblox Studio is open.",
            ));
        }

        let window_id_str = String::from_utf8_lossy(&window_id_output.stdout);
        let window_id = window_id_str
            .trim()
            .parse::<i32>()
            .map_err(|_| Error::msg("Failed to parse window ID"))?;

        let capture_result = tokio::time::timeout(
            Duration::from_secs(SCREENSHOT_TIMEOUT_SECS),
            Command::new("screencapture")
                .arg("-l")
                .arg(window_id.to_string())
                .arg("-o")
                .arg("-x")
                .arg(&temp_screenshot)
                .status(),
        )
        .await
        .map_err(|_| Error::msg("Timed out while capturing screenshot"))?;

        let capture = capture_result?;

        if !capture.success() {
            return Err(Error::msg(
                "Failed to capture screenshot. On macOS, ensure Screen Recording permission is granted in System Settings > Privacy & Security > Screen Recording.",
            ));
        }

        let img = image::open(&temp_screenshot)?;
        let _ = fs::remove_file(&temp_screenshot);

        Self::process_screenshot(img)
    }

    #[cfg(target_os = "windows")]
    async fn take_studio_screenshot() -> Result<String, Error> {
        use std::fs;
        use tokio::process::Command;

        let temp_path =
            std::env::temp_dir().join(format!("roblox_studio_{}.png", Uuid::new_v4()));

        let ps_script = format!(
            r#"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;

public struct RECT {{
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}}

public class Win32 {{
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
}}
"@

$process = Get-Process | Where-Object {{ $_.MainWindowTitle -like "*Roblox Studio*" }} | Select-Object -First 1
if ($null -eq $process) {{
    Write-Error "No Roblox Studio window found"
    exit 1
}}

$handle = $process.MainWindowHandle
$rect = New-Object RECT
[Win32]::GetWindowRect($handle, [ref]$rect) | Out-Null

$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top

$bitmap = New-Object System.Drawing.Bitmap $width, $height
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)

$bitmap.Save('{}', [System.Drawing.Imaging.ImageFormat]::Png)
"#,
            temp_path.display()
        );

        let capture_result = tokio::time::timeout(
            Duration::from_secs(SCREENSHOT_TIMEOUT_SECS),
            Command::new("powershell")
                .arg("-Command")
                .arg(&ps_script)
                .status(),
        )
        .await
        .map_err(|_| Error::msg("Timed out while capturing screenshot"))?;

        let capture = capture_result?;

        if !capture.success() {
            return Err(Error::msg(
                "Failed to capture screenshot. Is Roblox Studio running?",
            ));
        }

        let img = image::open(&temp_path)?;
        let _ = fs::remove_file(&temp_path);

        Self::process_screenshot(img)
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    async fn take_studio_screenshot() -> Result<String, Error> {
        Err(Error::msg(
            "Screenshot capture is only supported on macOS and Windows",
        ))
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
