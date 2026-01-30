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
use chrono::{DateTime, Utc};

pub const STUDIO_PLUGIN_PORT: u16 = 44755;
const LONG_POLL_DURATION: Duration = Duration::from_secs(15);

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
struct SearchAssets {
    #[schemars(description = "Search query for finding assets (e.g., 'medieval castle', 'sci-fi weapon', 'tree')")]
    query: String,
    #[schemars(description = "Maximum number of results to return (default: 10, max: 20)")]
    max_results: Option<u32>,
}

#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
struct PreviewAsset {
    #[schemars(description = "Asset ID to preview (from search_assets results)")]
    asset_id: u64,
    #[schemars(description = "Whether to keep the asset in workspace after preview (default: false - removes after screenshot)")]
    keep: Option<bool>,
}

// ============ Asset Search Enrichment Types ============

/// Response from the Luau plugin's SearchAssets
#[derive(Debug, Deserialize)]
struct PluginSearchResponse {
    success: bool,
    error: Option<String>,
    assets: Vec<PluginAssetResult>,
    query: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PluginAssetResult {
    #[serde(deserialize_with = "deserialize_number_from_string")]
    asset_id: u64,
    name: String,
    creator: String,
}

/// Deserialize a number that may come as a string (Luau JSONEncode quirk)
fn deserialize_number_from_string<'de, D>(deserializer: D) -> std::result::Result<u64, D::Error>
where
    D: serde::Deserializer<'de>,
{
    use serde::de::Error;

    #[derive(Deserialize)]
    #[serde(untagged)]
    enum StringOrNumber {
        String(String),
        Number(u64),
    }

    match StringOrNumber::deserialize(deserializer)? {
        StringOrNumber::String(s) => s.parse().map_err(D::Error::custom),
        StringOrNumber::Number(n) => Ok(n),
    }
}

/// Response from economy.roblox.com/v2/assets/{id}/details
#[derive(Debug, Deserialize)]
#[serde(rename_all = "PascalCase")]
struct EconomyAssetDetails {
    description: Option<String>,
    creator: Option<EconomyCreator>,
    updated: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "PascalCase")]
struct EconomyCreator {
    has_verified_badge: Option<bool>,
}

/// Enriched asset with all metadata and quality score
#[derive(Debug, Serialize)]
struct EnrichedAsset {
    asset_id: u64,
    name: String,
    creator: String,
    creator_verified: bool,
    description: Option<String>,
    favorites: u64,
    quality_score: f64,
}

#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
enum ToolArgumentValues {
    RunCode(RunCode),
    InsertModel(InsertModel),
    SearchAssets(SearchAssets),
    PreviewAsset(PreviewAsset),
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
        description = "Searches the Roblox marketplace for assets matching a query. Returns a ranked list of assets with quality scores based on favorites, creator verification, and recency. Assets are sorted by quality score to help you choose the best option."
    )]
    async fn search_assets(
        &self,
        Parameters(args): Parameters<SearchAssets>,
    ) -> Result<CallToolResult, ErrorData> {
        // Step 1: Get basic search results from plugin
        let plugin_result = self
            .run_tool_raw(ToolArgumentValues::SearchAssets(args.clone()))
            .await
            .map_err(|e| ErrorData::internal_error(format!("Plugin search failed: {}", e), None))?;

        // Step 2: Parse the JSON response from plugin
        let plugin_response: PluginSearchResponse = serde_json::from_str(&plugin_result)
            .map_err(|e| {
                ErrorData::internal_error(format!("Failed to parse plugin response: {}", e), None)
            })?;

        if !plugin_response.success {
            return Ok(CallToolResult::error(vec![Content::text(
                plugin_response
                    .error
                    .unwrap_or_else(|| "Unknown search error".to_string()),
            )]));
        }

        if plugin_response.assets.is_empty() {
            return Ok(CallToolResult::success(vec![Content::text(format!(
                "No assets found for query: '{}'",
                plugin_response.query
            ))]));
        }

        // Step 3: Enrich assets with web API data
        let enriched = self.enrich_assets(plugin_response.assets).await;

        // Step 4: Format results
        let mut lines = vec![
            format!(
                "Found {} assets for '{}', ranked by quality:\n",
                enriched.len(),
                plugin_response.query
            ),
        ];

        for (i, asset) in enriched.iter().enumerate() {
            let verified = if asset.creator_verified { " ✓" } else { "" };
            let desc_preview = asset
                .description
                .as_ref()
                .map(|d| {
                    let clean = d.lines().next().unwrap_or("").trim();
                    if clean.len() > 60 {
                        format!("{}...", &clean[..57])
                    } else {
                        clean.to_string()
                    }
                })
                .unwrap_or_default();

            lines.push(format!(
                "{}. **{}** (ID: {})\n   Creator: {}{} | ⭐ {} favorites | Score: {:.1}\n   {}",
                i + 1,
                asset.name,
                asset.asset_id,
                asset.creator,
                verified,
                asset.favorites,
                asset.quality_score,
                desc_preview
            ));
        }

        lines.push(String::new());
        lines.push("Use `preview_asset` with an asset_id to see what it looks like.".to_string());

        Ok(CallToolResult::success(vec![Content::text(lines.join("\n"))]))
    }

    /// Enrich assets with metadata from Roblox web APIs
    async fn enrich_assets(&self, assets: Vec<PluginAssetResult>) -> Vec<EnrichedAsset> {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(10))
            .build()
            .unwrap_or_default();

        // Fetch metadata for each asset concurrently
        let futures: Vec<_> = assets
            .into_iter()
            .map(|asset| {
                let client = client.clone();
                async move {
                    let (economy_data, favorites) = tokio::join!(
                        Self::fetch_economy_details(&client, asset.asset_id),
                        Self::fetch_favorites_count(&client, asset.asset_id)
                    );

                    let (description, creator_verified, updated) = match economy_data {
                        Ok(details) => (
                            details.description,
                            details
                                .creator
                                .as_ref()
                                .and_then(|c| c.has_verified_badge)
                                .unwrap_or(false),
                            details.updated,
                        ),
                        Err(_) => (None, false, None),
                    };

                    let favorites = favorites.unwrap_or(0);
                    let quality_score =
                        Self::calculate_quality_score(favorites, creator_verified, &updated, &description);

                    EnrichedAsset {
                        asset_id: asset.asset_id,
                        name: asset.name,
                        creator: asset.creator,
                        creator_verified,
                        description,
                        favorites,
                        quality_score,
                    }
                }
            })
            .collect();

        let mut enriched: Vec<EnrichedAsset> = futures::future::join_all(futures).await;

        // Sort by quality score (highest first)
        enriched.sort_by(|a, b| {
            b.quality_score
                .partial_cmp(&a.quality_score)
                .unwrap_or(std::cmp::Ordering::Equal)
        });

        enriched
    }

    /// Fetch asset details from economy.roblox.com
    async fn fetch_economy_details(
        client: &reqwest::Client,
        asset_id: u64,
    ) -> std::result::Result<EconomyAssetDetails, reqwest::Error> {
        let url = format!("https://economy.roblox.com/v2/assets/{}/details", asset_id);
        client.get(&url).send().await?.json().await
    }

    /// Fetch favorites count from catalog.roblox.com
    async fn fetch_favorites_count(
        client: &reqwest::Client,
        asset_id: u64,
    ) -> std::result::Result<u64, reqwest::Error> {
        let url = format!(
            "https://catalog.roblox.com/v1/favorites/assets/{}/count",
            asset_id
        );
        client.get(&url).send().await?.json().await
    }

    /// Calculate quality score based on various factors
    fn calculate_quality_score(
        favorites: u64,
        creator_verified: bool,
        updated: &Option<String>,
        description: &Option<String>,
    ) -> f64 {
        let mut score = 0.0;

        // Favorites: logarithmic scale (diminishing returns)
        // 100 favorites = ~46 points, 1000 = ~69, 10000 = ~92
        if favorites > 0 {
            score += (favorites as f64).ln() * 10.0;
        }

        // Creator verified badge: +20 points
        if creator_verified {
            score += 20.0;
        }

        // Recency bonus: up to 15 points for recently updated assets
        if let Some(updated_str) = updated {
            if let Ok(updated_date) = DateTime::parse_from_rfc3339(updated_str) {
                let now = Utc::now();
                let days_ago = (now - updated_date.with_timezone(&Utc)).num_days();
                // Full 15 points if updated within 30 days, decreasing over 2 years
                let recency_score = 15.0 * (1.0 - (days_ago as f64 / 730.0).min(1.0));
                score += recency_score.max(0.0);
            }
        }

        // Description quality: up to 10 points
        if let Some(desc) = description {
            let desc_len = desc.len();
            if desc_len > 10 {
                score += 5.0 + (desc_len as f64 / 200.0).min(1.0) * 5.0;
            }
        }

        score
    }

    #[tool(
        description = "Previews an asset by temporarily inserting it and taking a screenshot. Use this to see what an asset looks like before committing to it. Set keep=true to keep the asset in workspace, or leave as default to remove after screenshot."
    )]
    async fn preview_asset(
        &self,
        Parameters(args): Parameters<PreviewAsset>,
    ) -> Result<CallToolResult, ErrorData> {
        self.generic_tool_run(ToolArgumentValues::PreviewAsset(args))
            .await
    }

    /// Run a tool and return the raw string result (for internal processing)
    async fn run_tool_raw(&self, args: ToolArgumentValues) -> std::result::Result<String, String> {
        let (command, id) = ToolArguments::new(args);
        tracing::debug!("Running command (raw): {:?}", command);
        let (tx, mut rx) = mpsc::unbounded_channel::<Result<String>>();
        let trigger = {
            let mut state = self.state.lock().await;
            state.process_queue.push_back(command);
            state.output_map.insert(id, tx);
            state.trigger.clone()
        };
        trigger.send(()).map_err(|e| format!("Unable to trigger send: {e}"))?;
        let result = rx
            .recv()
            .await
            .ok_or_else(|| "Couldn't receive response".to_string())?;
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
