-- Types.luau

-- Generic Result Wrappers (to be returned by ToolHelpers.FormatSuccessResult/FormatErrorResult)
export type WrappedSuccessResult = {
	content: {{ type: string, text: string }}, -- Assumes text content, could be more complex
	isError: false,
}

export type WrappedErrorResult = {
	content: {{ type: string, text: string }},
	isError: true,
}

export type WrappedToolResult = WrappedSuccessResult | WrappedErrorResult

--[[
	Individual Tool Argument Types
	Each tool should have its arguments defined here.
]]

export type AddDebrisItemArgs = { instance_path: string, lifetime: number? } -- Original Placeholder
export type AddTagArgs = {
	instance_path: string,
	tag_name: string,
}



export type ComputePathArgs = {
	start_position: {x: number, y: number, z: number},
	end_position: {x: number, y: number, z: number},
	agent_parameters: {
		AgentRadius: number?,
		AgentHeight: number?,
		AgentCanJump: boolean?,
		WaypointSpacing: number?,
		Costs: {[string]: number}? -- e.g., {Water = 10, Grass = 1}
	}?
}

export type CreateInstanceArgs = {
	class_name: string,
	properties: { [string]: any }?, -- JSON representation of properties
	parent_path: string?, -- Optional path for the parent
}


export type FilterTextForPlayerArgs = {
	text_to_filter: string,
	player_path: string
}

export type GetInstancePropertiesArgs = { -- Original definition
	instance_path: string,
	property_names: {string} | string, -- Can be an array of names or a single name
}

export type GetMouseHitCFrameArgs = {
	camera_path: string?
}


export type GetMousePositionArgs = {
	-- No arguments currently defined, but type is added for consistency
}

export type GetPlayersInTeamArgs = {
	team_path_or_name: string
}

export type GetProductInfoArgs = {
	asset_id: number,
	info_type: string -- expecting "Asset" or "Product"
}

export type GetTeamsArgs = {
	-- No arguments currently defined
}

export type GetTeleportDataArgs = {
	-- No arguments currently defined
}

export type IncrementDataArgs = {
	store_name: string,
	key: string,
	increment_by: number? -- Optional, tool defaults to 1
}

export type InsertModelArgs = {
	query: string, -- Asset ID or search query
	parent_path: string?,
}

export type IsKeyDownArgs = {
	key_code_string: string
}

export type IsMouseButtonDownArgs = {
	mouse_button_string: string
}

export type KickPlayerArgs = {
	player_path_or_name: string,
	kick_message: string?
}

export type LoadAssetByIdArgs = {
	asset_id: number,
	parent_path: string?,
	desired_name: string?
}

export type LoadDataArgs = {
	store_name: string,
	key: string
}

export type PlaySoundIdArgs = {
	sound_id: string, -- e.g., "rbxassetid://123"
	parent_path: string?,
	properties: {[string]: any}? -- For Sound instance properties like Volume, Looped, etc.
}

export type PromptPurchaseArgs = {
	player_path: string,
	asset_id: number
}

-- Renaming RunScriptArgs to CreateScriptArgs for clarity
export type CreateScriptArgs = {
	parent_path: string,
	script_source: string,
	script_name: string,
	script_type: string, -- Expecting "Script", "LocalScript", or "ModuleScript"
	initially_disabled: boolean?
}

export type RunCodeArgs = {
	command: string, -- Luau code to execute
}

export type SaveDataArgs = {
	store_name: string,
	key: string,
	data: any -- Data to save, should be any DataStore-compatible Lua type
}

export type SendChatMessageArgs = {
	message_text: string,
	channel_name: string?,
	speaker_path: string?
}

export type SetInstancePropertiesArgs = { -- Original definition
	instance_path: string,
	properties: { [string]: any }, -- JSON representation of properties to set
}

export type TweenPropertiesArgs = {
	instance_path: string,
	duration: number,
	easing_style: string, -- Name of Enum.EasingStyle (e.g., "Linear", "Quad")
	easing_direction: string, -- Name of Enum.EasingDirection (e.g., "In", "Out", "InOut")
	properties_to_tween: {[string]: any}, -- Table of properties to their goal values
	repeat_count: number?,
	reverses: boolean?,
	delay_time: number?
}




--[[
	Individual Tool Success Result Data Types
	This is the 'data' part that a tool function should return upon success.
	ToolHelpers.FormatSuccessResult will then wrap this in a WrappedSuccessResult.
]]

export type CreateInstanceResultData = {
	message: string,
	instance_path: string,
	class_name: string,
}
export type AddTagResultData = {
	message: string,
	instance_path: string,
	tag_name: string,
}
export type InsertModelResultData = {
	message: string,
	instance_path: string?, -- Path if model inserted into workspace
	asset_id: number?, -- ID of the inserted model
}
export type RunCodeResultData = {
	message: string,
	return_values: {any}?, -- Values returned by the executed code
	output: string?, -- Captured output from the code
}
export type DeleteInstanceResultData = {
	message: string,
	instance_path: string,
}
export type GetInstancePropertiesResultData = {
	instance_path: string,
	properties: { [string]: any }, -- JSON representation of fetched properties
}

-- Placeholder for other tools
export type AddDebrisItemResultData = { message: string, instance_path: string } -- Existing placeholder
export type CallInstanceMethodResultData = { message: string, return_values: {any}? } -- Existing placeholder

export type ComputePathResultData = {
	message: string,
	status: string, -- Enum.PathStatus as string
	start_position_used: {x: number, y: number, z: number}, -- Serialized Vector3
	end_position_used: {x: number, y: number, z: number},   -- Serialized Vector3
	waypoints: {{x: number, y: number, z: number}}? -- Array of serialized Vector3
}

export type CreateScriptResultData = { -- For RunScript.luau
	message: string,
	script_path: string,
	script_type: string,
	initially_disabled: boolean
}

export type FilterTextForPlayerResultData = {
	message: string,
	original_text: string,
	filtered_text: string,
	player_context_path: string,
	player_user_id_used: number
}

export type GetMouseHitCFrameResultData = {
	message: string,
	instance_hit_path: string?,
	position: {x: number, y: number, z: number}?, -- Serialized Vector3
	cframe_components: { position: {x:number,y:number,z:number}, orientation: {x:number,y:number,z:number} }? -- Serialized CFrame
}

export type GetMousePositionResultData = {
	message: string,
	x: number,
	y: number,
	viewport_size: {x: number, y: number}
}

export type GetPlayersInTeamResultData = {
	message: string,
	team_name: string,
	team_path: string,
	players: {{name: string, path: string, user_id: number}}
}

export type GetProductInfoResultData = {
	message: string,
	asset_id: number,
	info_type_used: string,
	product_info: {[string]: any} -- Raw table from MarketplaceService
}

export type GetTeamsResultData = {
	message: string,
	team_count: number,
	teams: {{
		name: string,
		path: string,
		team_color_brickcolor_string: string,
		team_color_rgb: {R:number, G:number, B:number},
		auto_assignable: boolean,
		player_count: number
	}}
}

export type GetTeleportDataResultData = {
	message: string,
	teleport_data: any?, -- Can be any Lua type, or nil
	source_place_id: number?
}

export type IncrementDataResultData = {
	message: string,
	store_name: string,
	key: string,
	new_value: any, -- Can be number or other data store type
	incremented_by: number
}

export type IsKeyDownResultData = {
	message: string,
	key_code_used: string, -- Enum.KeyCode as string
	is_down: boolean
}

export type IsMouseButtonDownResultData = {
	message: string,
	mouse_button_checked: string, -- Enum.UserInputType as string
	is_down: boolean
}

export type KickPlayerResultData = {
	message: string,
	kicked_player_name: string,
	kick_message_used: string
}

export type LoadAssetByIdResultData = {
	message: string,
	asset_path: string,
	asset_id: number,
	asset_class_name: string
}

export type LoadDataResultData = {
	message: string,
	store_name: string,
	key: string,
	data: any? -- Can be any DataStore-compatible type, or nil
}

export type PlaySoundIdResultData = {
	message: string,
	sound_path: string,
	sound_id: string,
	is_playing: boolean,
	duration: number?, -- Duration might not be available if sound didn't load
	details: string? -- Optional field for extra info like loading failure
}

export type PromptPurchaseResultData = {
	message: string,
	player_name: string,
	asset_id: number,
	purchase_type_prompted: string
}

export type SaveDataResultData = {
	message: string,
	store_name: string,
	key: string
}

export type SendChatMessageResultData = {
	message: string,
	message_sent: string,
	channel_used: string,
	speaker_used: string
}

export type TweenPropertiesResultData = {
	message: string,
	instance_path: string,
	duration: number,
	easing_style_used: string, -- Name of Enum.EasingStyle
	easing_direction_used: string, -- Name of Enum.EasingDirection
	properties_goal: {[string]: any} -- The goal table after JsonToRobloxValue, then back to JSON via RobloxValueToJson
}




--[[
	General Tool Function Signature
	Each tool module will export a function. For type checking within Main.server.luau,
	we might need a way to reference these. For now, this is a conceptual placeholder.
	The actual type of 'args' and the return type's 'data' field will be specific
	to each tool.
]]
export type ToolFunction = (args: any) -> WrappedToolResult -- All tools will be wrapped by helpers to return this.


-- This is a placeholder and might be removed or changed.
-- The old ToolArgs and ToolFunction are no longer comprehensive.
-- export type ToolArgs_Old = { InsertModel: InsertModelArgs } | { RunCode: RunCodeArgs }
-- export type ToolFunction_Old = (ToolArgs_Old) -> string?

-- Appended types for batch update --

-- DeleteInstance
export type DeleteInstanceArgs = {
	path: string, -- Changed from instance_path for consistency with file content
}
export type DeleteInstanceResultData = {
	message: string,
	deleted_path: string,
	path_not_found: string?, -- If instance was not found
}

-- GetLightingProperty
export type GetLightingPropertyArgs = {
	property_name: string,
}
export type GetLightingPropertyResultData = {
	property_name: string,
	value: any, -- Raw Roblox value
}

-- SetLightingProperty
export type SetLightingPropertyArgs = {
	property_name: string,
	value: any, -- Value as received from JSON, will be converted by ToolHelpers.JsonToRobloxValue
}
export type SetLightingPropertyResultData = {
	property_name: string,
	new_value_set: any, -- Raw Roblox value after setting
}

-- GetWorkspaceProperty (similar to GetLightingProperty)
export type GetWorkspacePropertyArgs = {
	property_name: string,
}
export type GetWorkspacePropertyResultData = {
	property_name: string,
	value: any, -- Raw Roblox value
}

-- SetWorkspaceProperty (similar to SetLightingProperty)
export type SetWorkspacePropertyArgs = {
	property_name: string,
	value: any, -- Value as received from JSON
}
export type SetWorkspacePropertyResultData = {
	property_name: string,
	new_value_set: any, -- Raw Roblox value after setting
}

-- HasTag
export type HasTagArgs = {
	instance_path: string,
	tag_name: string,
}
export type HasTagResultData = {
	instance_path: string,
	tag_name: string,
	has_tag: boolean,
}

-- RemoveTag
export type RemoveTagArgs = {
	instance_path: string,
	tag_name: string,
}
export type RemoveTagResultData = {
	instance_path: string,
	tag_name: string,
	message: string, -- Explicit message for clarity
}

-- Appended types for batch update --

-- InstanceInfo for reuse
export type InstanceInfo = {
	name: string,
	path: string,
	class_name: string,
}

-- GetChildrenOfInstance
export type GetChildrenOfInstanceArgs = {
	instance_path: string,
}
export type GetChildrenOfInstanceResultData = {
	instance_path: string,
	children: {InstanceInfo},
}

-- GetDescendantsOfInstance
export type GetDescendantsOfInstanceArgs = {
	instance_path: string,
}
export type GetDescendantsOfInstanceResultData = {
	instance_path: string,
	descendants: {InstanceInfo},
}

-- GetInstanceProperties
export type PropertyAccessError = {
    name: string,
    error: string,
}
export type GetInstancePropertiesArgs = {
	path: string, -- path to the instance
	property_names: {string},
}
export type GetInstancePropertiesResultData = {
	instance_path: string,
	properties: {[string]: any}, -- Successfully fetched properties (raw Roblox values)
	errors: {PropertyAccessError}?, -- Errors for properties that couldn't be fetched
}

-- GetInstancesWithTag
export type GetInstancesWithTagArgs = {
	tag_name: string,
}
export type GetInstancesWithTagResultData = {
	tag_name: string,
	instances: {InstanceInfo},
}

-- GetSelection
export type GetSelectionArgs = {
	-- No specific arguments for now, but can be extended
}
export type GetSelectionResultData = {
	selected_instances: {InstanceInfo},
}

-- SelectInstances
export type PathResolutionError = {
    path: string,
    error: string,
}
export type SelectInstancesArgs = {
	paths: {string}, -- Array of instance paths to select
}
export type SelectInstancesResultData = {
    message: string,
	selected_paths: {string}, -- Full paths of successfully selected instances
    selection_count: number,
	errors_finding_paths: {PathResolutionError}?, -- Paths that could not be found/selected
}

-- Appended types for batch update --

-- AddDebrisItem
export type AddDebrisItemArgs = {
	instance_path: string,
	lifetime: number,
}
export type AddDebrisItemResultData = {
	instance_path: string,
	lifetime: number,
	message: string,
}

-- GetProperties (Similar to GetInstanceProperties)
export type GetPropertiesArgs = {
	path: string,
	property_names: {string},
}
export type GetPropertiesResultData = {
	instance_path: string,
	properties: {[string]: any}, -- Successfully fetched properties (raw Roblox values)
	errors: {PropertyAccessError}?, -- Errors for properties that couldn't be fetched
}

-- SetInstanceProperties
export type PropertyWriteResult = {
    name: string,
    status: "success" | "conversion_error" | "set_error",
    error_message: string?,
    original_value: any?, -- For conversion errors
    value_tried: any?, -- For set errors
}
export type SetInstancePropertiesArgs = {
	path: string,
	properties: {[string]: any}, -- Table of property names to JSON-like values
}
export type SetInstancePropertiesResultData = {
	instance_path: string,
    results: {PropertyWriteResult}, -- Detailed results for each property
    message: string,
}

-- SetProperties (Alias/similar to SetInstanceProperties)
export type SetPropertiesArgs = {
	path: string,
	properties: {[string]: any},
}
export type SetPropertiesResultData = {
	instance_path: string,
    results: {PropertyWriteResult},
    message: string,
}

-- FindFirstChildMatching
export type FindFirstChildMatchingArgs = {
	parent_path: string,
	child_name: string,
	recursive: boolean?,
}
export type FindFirstChildMatchingResultData = {
	parent_path: string,
	child_name_searched: string,
	recursive_search: boolean,
	found_child_path: string?,
	found_child_class_name: string?,
	message: string,
}

-- Appended types for batch update --

-- CallInstanceMethod
export type CallInstanceMethodArgs = {
	path: string,
	method_name: string,
	arguments: {any}, -- Array of arguments, may need conversion from JSON representation
}
export type CallInstanceMethodResultData = {
	message: string,
	results: {any}?, -- Array of raw Roblox values returned by the method
}

-- CreateGuiElement
export type CreateGuiElementArgs = {
	element_type: string,
	parent_path: string?, -- Optional: Path to parent (PlayerGui, StarterGui, or other GuiElement)
	properties: {[string]: any}?, -- JSON-like table for properties
}
export type CreateGuiElementResultData = {
	message: string,
	element_path: string,
	element_type: string,
	parent_path_used: string?,
}

-- CreateProximityPrompt
export type CreateProximityPromptArgs = {
	parent_part_path: string, -- Path to the BasePart, Attachment, Model, or Accessory
	properties: {[string]: any}?, -- JSON-like table for properties
}
export type CreateProximityPromptResultData = {
	message: string,
	prompt_path: string,
	action_text: string?,
	object_text: string?,
	max_activation_distance: number?,
}

-- CreateTeam
export type CreateTeamArgs = {
	team_name: string,
	team_color_brickcolor_string: string,
	auto_assignable: boolean?, -- Defaults to true if nil
}
export type CreateTeamResultData = {
	message: string,
	team_name: string,
	team_color: string, -- string representation of BrickColor
	auto_assignable: boolean,
	team_path: string,
}

-- CreateTextChannel
export type CreateTextChannelArgs = {
	channel_name: string,
	properties: {[string]: any}?, -- JSON-like table for properties
}
export type CreateTextChannelResultData = {
	message: string,
	channel_name: string,
	channel_path: string,
}

return {} -- Required for Luau module scripts
