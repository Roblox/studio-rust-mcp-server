export type InsertModelArgs = {
	query: string,
}

export type RunCodeArgs = {
	command: string,
}

export type WriteScriptArgs = {
	path: string,
	source: string,
}

export type ReadOutputArgs = {
	filter: string?, -- "all" | "print" | "warn" | "error"
	max_lines: number?, -- Maximum number of lines to return (default: 1000)
	clear_after_read: boolean?, -- Clear buffer after reading (default: true)
}

export type GetStudioStateArgs = {}

export type StartPlaytestArgs = {}

export type StartSimulationArgs = {}

export type StopSimulationArgs = {}

export type StopPlaytestArgs = {}

export type MoveCharacterArgs = {
	x: number,
	y: number,
	z: number,
	instant: boolean?, -- If true, teleport. If false/nil, walk to position
	character_name: string?, -- Optional character name, otherwise moves first character found
}

export type SimulateInputArgs = {
	input_type: string, -- "keyboard" or "mouse"
	key: string, -- Key name (e.g., "W", "Space") or mouse button ("Left", "Right")
	action: string, -- "begin", "end", or "tap"
	mouse_x: number?, -- Mouse X position (for mouse input)
	mouse_y: number?, -- Mouse Y position (for mouse input)
}

export type ClickGuiArgs = {
	path: string, -- Path to GUI element (e.g., "PlayerGui.MainUI.Button")
}

export type ToolArgs =
	{ InsertModel: InsertModelArgs }
	| { RunCode: RunCodeArgs }
	| { WriteScript: WriteScriptArgs }
	| { ReadOutput: ReadOutputArgs }
	| { GetStudioState: GetStudioStateArgs }
	| { StartPlaytest: StartPlaytestArgs }
	| { StartSimulation: StartSimulationArgs }
	| { StopSimulation: StopSimulationArgs }
	| { StopPlaytest: StopPlaytestArgs }
	| { MoveCharacter: MoveCharacterArgs }
	| { SimulateInput: SimulateInputArgs }
	| { ClickGui: ClickGuiArgs }

export type ToolFunction = (ToolArgs) -> string?

return {}
