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

-- For tools already inspected or simple ones
export type CreateInstanceArgs = {
	class_name: string,
	properties: { [string]: any }?, -- JSON representation of properties
	parent_path: string?, -- Optional path for the parent
}
export type AddTagArgs = {
	instance_path: string,
	tag_name: string,
}
export type InsertModelArgs = {
	query: string, -- Asset ID or search query
	parent_path: string?,
}
export type RunCodeArgs = {
	command: string, -- Luau code to execute
}
export type DeleteInstanceArgs = {
	instance_path: string,
}
export type GetInstancePropertiesArgs = {
	instance_path: string,
	property_names: {string} | string, -- Can be an array of names or a single name
}
export type SetInstancePropertiesArgs = {
	instance_path: string,
	properties: { [string]: any }, -- JSON representation of properties to set
}

-- Placeholder for other tools - to be defined
export type AddDebrisItemArgs = { instance_path: string, lifetime: number? }
export type CallInstanceMethodArgs = { instance_path: string, method_name: string, arguments: {any}? }
-- ... (many more Arg types to be defined based on each tool's needs)


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
export type SetInstancePropertiesResultData = {
	message: string,
	instance_path: string,
	properties_set: { [string]: any }, -- Echo back the properties that were attempted to set
}

-- Placeholder for other tools
export type AddDebrisItemResultData = { message: string, instance_path: string }
export type CallInstanceMethodResultData = { message: string, return_values: {any}? }
-- ... (many more ResultData types to be defined)


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
