export type InsertModelArgs = {
	query: string,
}

export type RunCodeArgs = {
	command: string,
}

type StartStopPlayMode = "start_play" | "run_server" | "stop"

export type StartStopPlayArgs = {
	mode: StartStopPlayMode,
}

export type ToolArgs =
	{}
	| { InsertModel: InsertModelArgs }
	| { RunCode: RunCodeArgs }
	| { StartStopPlay: StartStopPlayArgs }

export type ToolFunction = (ToolArgs) -> string?

return {}
