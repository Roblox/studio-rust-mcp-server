export type InsertModelArgs = {
	query: string,
}

export type RunCodeArgs = {
	command: string,
}

export type GetStudioStateArgs = {}

export type StartPlaytestArgs = {}

export type StartSimulationArgs = {}

export type StopSimulationArgs = {}

export type StopPlaytestArgs = {}

export type ToolArgs =
	{ InsertModel: InsertModelArgs }
	| { RunCode: RunCodeArgs }
	| { GetStudioState: GetStudioStateArgs }
	| { StartPlaytest: StartPlaytestArgs }
	| { StartSimulation: StartSimulationArgs }
	| { StopSimulation: StopSimulationArgs }
	| { StopPlaytest: StopPlaytestArgs }

export type ToolFunction = (ToolArgs) -> string?

return {}
