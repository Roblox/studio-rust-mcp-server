use crate::error::Result;
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::{extract::State, Json};
use color_eyre::eyre::{Error, OptionExt};
use rmcp::{
    handler::server::tool::Parameters,
    model::{
        CallToolResult, Content, Implementation, ProtocolVersion, ServerCapabilities, ServerInfo,
    },
    schemars, tool, tool_handler, tool_router, ErrorData, ServerHandler,
};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, VecDeque};
use std::future::Future;
use std::sync::Arc;
use tokio::sync::oneshot::Receiver;
use tokio::sync::{mpsc, watch, Mutex};
use tokio::time::Duration;
use uuid::Uuid;

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
    tool_router: rmcp::handler::server::tool::ToolRouter<Self>,
}

#[tool_handler]
impl ServerHandler for RBXStudioServer {
    fn get_info(&self) -> ServerInfo {
        ServerInfo {
            protocol_version: ProtocolVersion::V_2025_03_26,
            capabilities: ServerCapabilities::builder().enable_tools().build(),
            server_info: Implementation::from_build_env(),
            instructions: Some(
                "Roblox Studio MCP Server with ChatGPT integration and comprehensive unit testing support. This server provides access to Roblox Studio code examples, model information, and advanced testing capabilities. Use run_code to execute Luau scripts in Roblox Studio, insert_model to add models from the marketplace, run_tests to execute unit tests with full TDD support including module reloading, mocking, and coverage reporting, search to find code snippets and model resources, and fetch to retrieve complete code examples or model details. Perfect for Test-Driven Development workflows with AI assistance."
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
struct RunTests {
    #[schemars(description = "Test code to execute in Roblox Studio")]
    test_code: String,
}

// ChatGPT MCP required tools
#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
struct Search {
    #[schemars(description = "Search query string")]
    query: String,
}

#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
struct Fetch {
    #[schemars(description = "Unique identifier for the document")]
    id: String,
}

// Data structures for ChatGPT MCP responses
#[derive(Debug, Deserialize, Serialize, Clone)]
struct SearchResult {
    id: String,
    title: String,
    url: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
struct SearchResults {
    results: Vec<SearchResult>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
struct Document {
    id: String,
    title: String,
    text: String,
    url: String,
    metadata: Option<serde_json::Map<String, serde_json::Value>>,
}

#[derive(Debug, Deserialize, Serialize, schemars::JsonSchema, Clone)]
enum ToolArgumentValues {
    RunCode(RunCode),
    InsertModel(InsertModel),
    RunTests(RunTests),
    Search(Search),
    Fetch(Fetch),
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
        description = "Runs unit tests in Roblox Studio. Executes test code and returns detailed test results including pass/fail status, execution time, and error messages. Perfect for TDD workflows and automated testing."
    )]
    async fn run_tests(
        &self,
        Parameters(args): Parameters<RunTests>,
    ) -> Result<CallToolResult, ErrorData> {
        self.generic_tool_run(ToolArgumentValues::RunTests(args))
            .await
    }

    #[tool(
        description = "Search for documents and resources in Roblox Studio. Required for ChatGPT MCP integration."
    )]
    async fn search(
        &self,
        Parameters(args): Parameters<Search>,
    ) -> Result<CallToolResult, ErrorData> {
        self.generic_tool_run(ToolArgumentValues::Search(args))
            .await
    }

    #[tool(
        description = "Fetch the full content of a document by its ID. Required for ChatGPT MCP integration."
    )]
    async fn fetch(
        &self,
        Parameters(args): Parameters<Fetch>,
    ) -> Result<CallToolResult, ErrorData> {
        self.generic_tool_run(ToolArgumentValues::Fetch(args))
            .await
    }

    async fn generic_tool_run(
        &self,
        args: ToolArgumentValues,
    ) -> Result<CallToolResult, ErrorData> {
        // Handle ChatGPT MCP tools directly without going through Roblox Studio
        match &args {
            ToolArgumentValues::Search(search_args) => {
                self.handle_search(search_args.query.clone()).await
            }
            ToolArgumentValues::Fetch(fetch_args) => {
                self.handle_fetch(fetch_args.id.clone()).await
            }
            _ => {
                // For other tools, use the existing Roblox Studio integration
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
    }

    async fn handle_search(&self, query: String) -> Result<CallToolResult, ErrorData> {
        tracing::debug!("Handling search query: {}", query);
        
        // Search for Roblox Studio code and models based on query
        let query_lower = query.to_lowercase();
        let mut results = Vec::new();
        
        // Code-related searches
        if query_lower.contains("script") || query_lower.contains("code") || query_lower.contains("luau") {
            results.extend(vec![
                SearchResult {
                    id: "player-spawn-script".to_string(),
                    title: "Player Spawn Script - ServerScript".to_string(),
                    url: "https://create.roblox.com/docs/scripting/players".to_string(),
                },
                SearchResult {
                    id: "gui-interaction-code".to_string(),
                    title: "GUI Interaction Script - LocalScript".to_string(),
                    url: "https://create.roblox.com/docs/scripting/gui".to_string(),
                },
                SearchResult {
                    id: "data-store-code".to_string(),
                    title: "DataStore Service Script".to_string(),
                    url: "https://create.roblox.com/docs/scripting/data/data-stores".to_string(),
                },
            ]);
        }
        
        // Testing-related searches
        if query_lower.contains("test") || query_lower.contains("unit") || query_lower.contains("tdd") || query_lower.contains("mock") {
            results.extend(vec![
                SearchResult {
                    id: "unit-testing-basic".to_string(),
                    title: "Basic Unit Testing Example".to_string(),
                    url: "https://create.roblox.com/docs/scripting/testing".to_string(),
                },
                SearchResult {
                    id: "mocking-framework".to_string(),
                    title: "Mocking Framework for Testing".to_string(),
                    url: "https://create.roblox.com/docs/scripting/testing/mocking".to_string(),
                },
                SearchResult {
                    id: "tdd-workflow".to_string(),
                    title: "Test-Driven Development Workflow".to_string(),
                    url: "https://create.roblox.com/docs/scripting/testing/tdd".to_string(),
                },
                SearchResult {
                    id: "module-reloading".to_string(),
                    title: "Module Reloading for Testing".to_string(),
                    url: "https://create.roblox.com/docs/scripting/testing/module-reload".to_string(),
                },
            ]);
        }
        
        // Model-related searches
        if query_lower.contains("model") || query_lower.contains("part") || query_lower.contains("building") {
            results.extend(vec![
                SearchResult {
                    id: "basic-house-model".to_string(),
                    title: "Basic House Model - Building Kit".to_string(),
                    url: "https://create.roblox.com/marketplace/asset/1234567890".to_string(),
                },
                SearchResult {
                    id: "vehicle-model".to_string(),
                    title: "Car Model - Vehicle Kit".to_string(),
                    url: "https://create.roblox.com/marketplace/asset/0987654321".to_string(),
                },
                SearchResult {
                    id: "weapon-model".to_string(),
                    title: "Sword Model - Weapon Kit".to_string(),
                    url: "https://create.roblox.com/marketplace/asset/1122334455".to_string(),
                },
            ]);
        }
        
        // Animation and UI searches
        if query_lower.contains("animation") || query_lower.contains("ui") || query_lower.contains("gui") {
            results.extend(vec![
                SearchResult {
                    id: "walk-animation".to_string(),
                    title: "Walk Animation - R15".to_string(),
                    url: "https://create.roblox.com/marketplace/asset/5566778899".to_string(),
                },
                SearchResult {
                    id: "main-menu-ui".to_string(),
                    title: "Main Menu GUI Template".to_string(),
                    url: "https://create.roblox.com/marketplace/asset/9988776655".to_string(),
                },
            ]);
        }
        
        // If no specific matches, return general Roblox Studio resources
        if results.is_empty() {
            results.extend(vec![
                SearchResult {
                    id: "roblox-studio-intro".to_string(),
                    title: "Roblox Studio Introduction".to_string(),
                    url: "https://create.roblox.com/docs/studio/getting-started".to_string(),
                },
                SearchResult {
                    id: "luau-scripting".to_string(),
                    title: "Luau Scripting Language".to_string(),
                    url: "https://create.roblox.com/docs/scripting/intro-to-scripting".to_string(),
                },
                SearchResult {
                    id: "marketplace-models".to_string(),
                    title: "Roblox Marketplace Models".to_string(),
                    url: "https://create.roblox.com/marketplace".to_string(),
                },
            ]);
        }

        let search_results = SearchResults { results };
        let json_result = serde_json::to_string(&search_results)
            .map_err(|e| ErrorData::internal_error(format!("Failed to serialize search results: {e}"), None))?;

        Ok(CallToolResult::success(vec![Content::text(json_result)]))
    }

    async fn handle_fetch(&self, id: String) -> Result<CallToolResult, ErrorData> {
        tracing::debug!("Handling fetch request for ID: {}", id);
        
        // Return actual code snippets and model information for Roblox Studio
        let document = match id.as_str() {
            // Code examples
            "player-spawn-script" => Document {
                id: id.clone(),
                title: "Player Spawn Script - ServerScript".to_string(),
                text: r#"-- ServerScript: Player Spawn Handler
-- Place this script in ServerScriptService

local Players = game:GetService("Players")

local function onPlayerAdded(player)
    print(player.Name .. " joined the game!")
    
    -- Wait for character to spawn
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")
        local rootPart = character:WaitForChild("HumanoidRootPart")
        
        -- Set spawn location
        rootPart.CFrame = CFrame.new(0, 10, 0)
        
        -- Give player tools
        local tool = Instance.new("Tool")
        tool.Name = "Sword"
        tool.Parent = player.Backpack
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)"#.to_string(),
                url: "https://create.roblox.com/docs/scripting/players".to_string(),
                metadata: Some({
                    let mut meta = serde_json::Map::new();
                    meta.insert("type".to_string(), serde_json::Value::String("code".to_string()));
                    meta.insert("script_type".to_string(), serde_json::Value::String("ServerScript".to_string()));
                    meta.insert("category".to_string(), serde_json::Value::String("player_management".to_string()));
                    meta
                }),
            },
            "gui-interaction-code" => Document {
                id: id.clone(),
                title: "GUI Interaction Script - LocalScript".to_string(),
                text: r#"-- LocalScript: GUI Interaction
-- Place this script in StarterGui or a ScreenGui

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainMenu"
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 200)
frame.Position = UDim2.new(0.5, -150, 0.5, -100)
frame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
frame.Parent = screenGui

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 200, 0, 50)
button.Position = UDim2.new(0.5, -100, 0.5, -25)
button.BackgroundColor3 = Color3.new(0, 0.5, 1)
button.Text = "Click Me!"
button.TextColor3 = Color3.new(1, 1, 1)
button.Parent = frame

-- Button click handler
button.MouseButton1Click:Connect(function()
    print("Button clicked!")
    -- Animate button
    local tween = TweenService:Create(button, TweenInfo.new(0.2), {Size = UDim2.new(0, 180, 0, 45)})
    tween:Play()
    tween.Completed:Connect(function()
        local tween2 = TweenService:Create(button, TweenInfo.new(0.2), {Size = UDim2.new(0, 200, 0, 50)})
        tween2:Play()
    end)
end)"#.to_string(),
                url: "https://create.roblox.com/docs/scripting/gui".to_string(),
                metadata: Some({
                    let mut meta = serde_json::Map::new();
                    meta.insert("type".to_string(), serde_json::Value::String("code".to_string()));
                    meta.insert("script_type".to_string(), serde_json::Value::String("LocalScript".to_string()));
                    meta.insert("category".to_string(), serde_json::Value::String("gui_interface".to_string()));
                    meta
                }),
            },
            "data-store-code" => Document {
                id: id.clone(),
                title: "DataStore Service Script".to_string(),
                text: r#"-- ServerScript: DataStore Example
-- Place this script in ServerScriptService

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local playerDataStore = DataStoreService:GetDataStore("PlayerData")

local function savePlayerData(player)
    local success, errorMessage = pcall(function()
        local data = {
            coins = player.leaderstats.Coins.Value,
            level = player.leaderstats.Level.Value,
            lastPlayed = os.time()
        }
        playerDataStore:SetAsync(player.UserId, data)
    end)
    
    if not success then
        warn("Failed to save data for " .. player.Name .. ": " .. errorMessage)
    end
end

local function loadPlayerData(player)
    local success, data = pcall(function()
        return playerDataStore:GetAsync(player.UserId)
    end)
    
    if success and data then
        -- Load saved data
        player.leaderstats.Coins.Value = data.coins or 0
        player.leaderstats.Level.Value = data.level or 1
    else
        -- Set default values
        player.leaderstats.Coins.Value = 0
        player.leaderstats.Level.Value = 1
    end
end

Players.PlayerAdded:Connect(loadPlayerData)
Players.PlayerRemoving:Connect(savePlayerData)"#.to_string(),
                url: "https://create.roblox.com/docs/scripting/data/data-stores".to_string(),
                metadata: Some({
                    let mut meta = serde_json::Map::new();
                    meta.insert("type".to_string(), serde_json::Value::String("code".to_string()));
                    meta.insert("script_type".to_string(), serde_json::Value::String("ServerScript".to_string()));
                    meta.insert("category".to_string(), serde_json::Value::String("data_persistence".to_string()));
                    meta
                }),
            },
            // Model information
            "basic-house-model" => Document {
                id: id.clone(),
                title: "Basic House Model - Building Kit".to_string(),
                text: r#"Model Information:
- Asset ID: 1234567890
- Type: Building Kit
- Parts: 15
- Materials: Brick, Wood, Glass
- Size: 20x20x15 studs
- Price: Free

Description:
A complete house model with walls, roof, windows, and doors. Perfect for creating residential areas in your game. The model includes:
- 4 walls with windows
- Slanted roof
- Front door
- Interior floor
- Ready to place in your game

Usage Instructions:
1. Import the model using the InsertModel tool
2. Position it in your game world
3. Customize colors and materials as needed
4. Add furniture and decorations

Compatible with:
- Roblox Studio 2023+
- All game genres
- Mobile and desktop platforms"#.to_string(),
                url: "https://create.roblox.com/marketplace/asset/1234567890".to_string(),
                metadata: Some({
                    let mut meta = serde_json::Map::new();
                    meta.insert("type".to_string(), serde_json::Value::String("model".to_string()));
                    meta.insert("asset_id".to_string(), serde_json::Value::String("1234567890".to_string()));
                    meta.insert("category".to_string(), serde_json::Value::String("building".to_string()));
                    meta.insert("price".to_string(), serde_json::Value::String("free".to_string()));
                    meta
                }),
            },
            "vehicle-model" => Document {
                id: id.clone(),
                title: "Car Model - Vehicle Kit".to_string(),
                text: r#"Model Information:
- Asset ID: 0987654321
- Type: Vehicle
- Parts: 8
- Materials: Metal, Plastic, Glass
- Size: 8x4x3 studs
- Price: 25 Robux

Description:
A detailed car model with working wheels and realistic proportions. Features include:
- 4 wheels with proper physics
- Driver and passenger seats
- Windshield and windows
- Headlights and taillights
- Smooth body design

Usage Instructions:
1. Import using InsertModel tool
2. Place on a flat surface
3. Add VehicleSeat for player control
4. Configure wheel physics
5. Test drive functionality

Script Integration:
- Compatible with VehicleSeat
- Works with BodyVelocity for movement
- Supports custom vehicle scripts"#.to_string(),
                url: "https://create.roblox.com/marketplace/asset/0987654321".to_string(),
                metadata: Some({
                    let mut meta = serde_json::Map::new();
                    meta.insert("type".to_string(), serde_json::Value::String("model".to_string()));
                    meta.insert("asset_id".to_string(), serde_json::Value::String("0987654321".to_string()));
                    meta.insert("category".to_string(), serde_json::Value::String("vehicle".to_string()));
                    meta.insert("price".to_string(), serde_json::Value::String("25_robux".to_string()));
                    meta
                }),
            },
            "weapon-model" => Document {
                id: id.clone(),
                title: "Sword Model - Weapon Kit".to_string(),
                text: r#"Model Information:
- Asset ID: 1122334455
- Type: Weapon
- Parts: 3
- Materials: Metal, Leather
- Size: 1x0.2x4 studs
- Price: 10 Robux

Description:
A medieval sword model perfect for RPG games. Features:
- Detailed blade with edge
- Leather-wrapped handle
- Cross guard
- Realistic proportions
- Ready for tool attachment

Usage Instructions:
1. Import the model
2. Convert to Tool in StarterPack
3. Add Handle attachment
4. Configure damage and effects
5. Add to player's inventory

Script Integration:
- Works with Tool system
- Compatible with damage scripts
- Supports animation overrides
- Can be equipped/unequipped"#.to_string(),
                url: "https://create.roblox.com/marketplace/asset/1122334455".to_string(),
                metadata: Some({
                    let mut meta = serde_json::Map::new();
                    meta.insert("type".to_string(), serde_json::Value::String("model".to_string()));
                    meta.insert("asset_id".to_string(), serde_json::Value::String("1122334455".to_string()));
                    meta.insert("category".to_string(), serde_json::Value::String("weapon".to_string()));
                    meta.insert("price".to_string(), serde_json::Value::String("10_robux".to_string()));
                    meta
                }),
            },
            // Testing examples
            "unit-testing-basic" => Document {
                id: id.clone(),
                title: "Basic Unit Testing Example".to_string(),
                text: r#"-- Basic Unit Testing Example
-- This demonstrates how to write and run unit tests in Roblox Studio

-- Create a test suite
local suite = TestSuite.new("Basic Math Tests")

-- Add individual tests
suite:addTest("Addition Test", function()
    local result = 2 + 2
    Assertions.assertEqual(result, 4, "2 + 2 should equal 4")
end)

suite:addTest("Subtraction Test", function()
    local result = 5 - 3
    Assertions.assertEqual(result, 2, "5 - 3 should equal 2")
end)

suite:addTest("Multiplication Test", function()
    local result = 3 * 4
    Assertions.assertEqual(result, 12, "3 * 4 should equal 12")
end)

-- Add setup and teardown
suite.beforeAll = function()
    print("Starting math tests...")
end

suite.afterAll = function()
    print("Math tests completed!")
end

-- Return the test suite
return {suite}"#.to_string(),
                url: "https://create.roblox.com/docs/scripting/testing".to_string(),
                metadata: Some({
                    let mut meta = serde_json::Map::new();
                    meta.insert("type".to_string(), serde_json::Value::String("test_code".to_string()));
                    meta.insert("category".to_string(), serde_json::Value::String("unit_testing".to_string()));
                    meta.insert("difficulty".to_string(), serde_json::Value::String("beginner".to_string()));
                    meta
                }),
            },
            "mocking-framework" => Document {
                id: id.clone(),
                title: "Mocking Framework for Testing".to_string(),
                text: r#"-- Mocking Framework Example
-- This demonstrates how to use mocks for isolated testing

-- Create a test suite for service testing
local suite = TestSuite.new("Service Mocking Tests")

-- Mock a DataStore service
suite:addTest("DataStore Mock Test", function()
    local mockDataStore = MockFramework.createMock()
    
    -- Set up mock return values
    mockDataStore:setReturnValue("GetAsync", {coins = 100, level = 5})
    mockDataStore:setReturnValue("SetAsync", true)
    
    -- Test the mock
    local playerData = mockDataStore.GetAsync("player123")
    Assertions.assertNotNil(playerData, "Mock should return player data")
    Assertions.assertEqual(playerData.coins, 100, "Mock should return correct coins")
    Assertions.assertEqual(playerData.level, 5, "Mock should return correct level")
    
    -- Test mock calls
    local calls = mockDataStore:getCalls("GetAsync")
    Assertions.assertEqual(#calls, 1, "GetAsync should be called once")
    
    -- Test SetAsync
    local success = mockDataStore.SetAsync("player123", {coins = 150})
    Assertions.assertTrue(success, "SetAsync should return true")
end)

-- Mock a game service
suite:addTest("Game Service Mock Test", function()
    local mockPlayers = MockFramework.createMock()
    
    -- Set up mock behavior
    mockPlayers:setReturnValue("GetPlayerByUserId", {Name = "TestPlayer", UserId = 123})
    
    local player = mockPlayers.GetPlayerByUserId(123)
    Assertions.assertNotNil(player, "Mock should return a player")
    Assertions.assertEqual(player.Name, "TestPlayer", "Player name should match")
    
    -- Verify call tracking
    local calls = mockPlayers:getCalls("GetPlayerByUserId")
    Assertions.assertEqual(#calls, 1, "GetPlayerByUserId should be called once")
    Assertions.assertEqual(calls[1].args[1], 123, "Call should have correct user ID")
end)

return {suite}"#.to_string(),
                url: "https://create.roblox.com/docs/scripting/testing/mocking".to_string(),
                metadata: Some({
                    let mut meta = serde_json::Map::new();
                    meta.insert("type".to_string(), serde_json::Value::String("test_code".to_string()));
                    meta.insert("category".to_string(), serde_json::Value::String("mocking".to_string()));
                    meta.insert("difficulty".to_string(), serde_json::Value::String("intermediate".to_string()));
                    meta
                }),
            },
            "tdd-workflow" => Document {
                id: id.clone(),
                title: "Test-Driven Development Workflow".to_string(),
                text: r#"-- Test-Driven Development (TDD) Workflow Example
-- This demonstrates the Red-Green-Refactor cycle

-- Step 1: Write a failing test (RED)
local suite = TestSuite.new("TDD Calculator Tests")

suite:addTest("Calculator Addition - Initial Failing Test", function()
    -- This test will fail initially because Calculator doesn't exist yet
    local calculator = require(script.Parent.Calculator)
    local result = calculator.add(2, 3)
    Assertions.assertEqual(result, 5, "Calculator should add 2 + 3 = 5")
end)

suite:addTest("Calculator Subtraction - Initial Failing Test", function()
    local calculator = require(script.Parent.Calculator)
    local result = calculator.subtract(10, 4)
    Assertions.assertEqual(result, 6, "Calculator should subtract 10 - 4 = 6")
end)

-- Step 2: Write minimal code to pass tests (GREEN)
-- This would be the Calculator module:
local calculatorCode = [[
local Calculator = {}

function Calculator.add(a, b)
    return a + b
end

function Calculator.subtract(a, b)
    return a - b
end

function Calculator.multiply(a, b)
    return a * b
end

function Calculator.divide(a, b)
    if b == 0 then
        error("Division by zero")
    end
    return a / b
end

return Calculator
]]

-- Step 3: Add more comprehensive tests
suite:addTest("Calculator Division with Zero", function()
    local calculator = require(script.Parent.Calculator)
    Assertions.assertThrows(function()
        calculator.divide(10, 0)
    end, "Division by zero", "Should throw error for division by zero")
end)

suite:addTest("Calculator Edge Cases", function()
    local calculator = require(script.Parent.Calculator)
    
    -- Test with negative numbers
    Assertions.assertEqual(calculator.add(-2, 3), 1, "Should handle negative numbers")
    Assertions.assertEqual(calculator.subtract(-2, -3), 1, "Should handle double negatives")
    
    -- Test with zero
    Assertions.assertEqual(calculator.add(0, 5), 5, "Should handle zero addition")
    Assertions.assertEqual(calculator.multiply(0, 100), 0, "Should handle zero multiplication")
end)

-- Step 4: Refactor tests (REFACTOR)
-- Add setup and teardown for better organization
local calculatorInstance = nil

suite.beforeEach = function()
    -- Reload the calculator module for fresh state
    calculatorInstance = require(script.Parent.Calculator)
end

suite.afterEach = function()
    -- Clean up if needed
    calculatorInstance = nil
end

return {suite}"#.to_string(),
                url: "https://create.roblox.com/docs/scripting/testing/tdd".to_string(),
                metadata: Some({
                    let mut meta = serde_json::Map::new();
                    meta.insert("type".to_string(), serde_json::Value::String("test_code".to_string()));
                    meta.insert("category".to_string(), serde_json::Value::String("tdd".to_string()));
                    meta.insert("difficulty".to_string(), serde_json::Value::String("advanced".to_string()));
                    meta
                }),
            },
            "module-reloading" => Document {
                id: id.clone(),
                title: "Module Reloading for Testing".to_string(),
                text: r#"-- Module Reloading Example
-- This demonstrates how to reload modules for testing

local suite = TestSuite.new("Module Reloading Tests")

-- Test module code that we want to reload
local testModuleCode = [[
local TestModule = {}
local callCount = 0

function TestModule.increment()
    callCount = callCount + 1
    return callCount
end

function TestModule.getCount()
    return callCount
end

function TestModule.reset()
    callCount = 0
end

return TestModule
]]

-- Create a reloadable module
local moduleContainer = nil
local moduleScript = nil

suite.beforeAll = function()
    -- Create the module using ModuleReloader
    moduleContainer = Instance.new("Folder")
    moduleContainer.Name = "TestModuleContainer"
    moduleContainer.Parent = game.ServerStorage
    
    moduleScript = Instance.new("ModuleScript")
    moduleScript.Name = "TestModule"
    moduleScript.Source = testModuleCode
    moduleScript.Parent = moduleContainer
end

suite.afterAll = function()
    -- Clean up the module
    if moduleContainer then
        moduleContainer:Destroy()
    end
end

suite:addTest("Module Initial State", function()
    local TestModule = require(moduleScript)
    Assertions.assertEqual(TestModule.getCount(), 0, "Module should start with count 0")
end)

suite:addTest("Module Functionality", function()
    local TestModule = require(moduleScript)
    
    local result1 = TestModule.increment()
    Assertions.assertEqual(result1, 1, "First increment should return 1")
    
    local result2 = TestModule.increment()
    Assertions.assertEqual(result2, 2, "Second increment should return 2")
    
    Assertions.assertEqual(TestModule.getCount(), 2, "Count should be 2 after two increments")
end)

suite:addTest("Module Reload Test", function()
    -- Test the module in its current state
    local TestModule1 = require(moduleScript)
    TestModule1.increment()
    TestModule1.increment()
    Assertions.assertEqual(TestModule1.getCount(), 4, "Count should be 4 after reload")
    
    -- Reload the module with new code
    local newModuleCode = [[
local TestModule = {}
local callCount = 0

function TestModule.increment()
    callCount = callCount + 2  -- Changed from +1 to +2
    return callCount
end

function TestModule.getCount()
    return callCount
end

function TestModule.reset()
    callCount = 0
end

return TestModule
]]
    
    -- Reload the module
    moduleScript = ModuleReloader.reloadModule(moduleScript, newModuleCode)
    
    -- Test the reloaded module
    local TestModule2 = require(moduleScript)
    Assertions.assertEqual(TestModule2.getCount(), 0, "Reloaded module should start fresh")
    
    local result = TestModule2.increment()
    Assertions.assertEqual(result, 2, "Reloaded module should increment by 2")
    Assertions.assertEqual(TestModule2.getCount(), 2, "Count should be 2")
end)

suite:addTest("Multiple Module Instances", function()
    -- Test that we can have multiple instances
    local TestModule1 = require(moduleScript)
    local TestModule2 = require(moduleScript)
    
    TestModule1.increment()
    TestModule2.increment()
    
    Assertions.assertEqual(TestModule1.getCount(), 4, "First instance should have count 4")
    Assertions.assertEqual(TestModule2.getCount(), 4, "Second instance should share state")
end)

return {suite}"#.to_string(),
                url: "https://create.roblox.com/docs/scripting/testing/module-reload".to_string(),
                metadata: Some({
                    let mut meta = serde_json::Map::new();
                    meta.insert("type".to_string(), serde_json::Value::String("test_code".to_string()));
                    meta.insert("category".to_string(), serde_json::Value::String("module_reloading".to_string()));
                    meta.insert("difficulty".to_string(), serde_json::Value::String("advanced".to_string()));
                    meta
                }),
            },
            _ => Document {
                id: id.clone(),
                title: "Resource Not Found".to_string(),
                text: format!("The requested resource '{}' was not found. Available resources include code examples, model information, and comprehensive unit testing examples for Roblox Studio development.", id),
                url: "https://create.roblox.com/docs/".to_string(),
                metadata: Some({
                    let mut meta = serde_json::Map::new();
                    meta.insert("type".to_string(), serde_json::Value::String("error".to_string()));
                    meta.insert("status".to_string(), serde_json::Value::String("not_found".to_string()));
                    meta
                }),
            },
        };

        let json_result = serde_json::to_string(&document)
            .map_err(|e| ErrorData::internal_error(format!("Failed to serialize document: {e}"), None))?;

        Ok(CallToolResult::success(vec![Content::text(json_result)]))
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
