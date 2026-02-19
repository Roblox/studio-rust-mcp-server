export type InsertModelArgs = {
	query: string,
}

export type RunCodeArgs = {
	command: string,
}

export type WriteScriptArgs = {
	path: string,
	source: string,
	script_type: string?,
}

export type ToolArgs = { InsertModel: InsertModelArgs } | { RunCode: RunCodeArgs } | { WriteScript: WriteScriptArgs }

export type ToolFunction = (ToolArgs) -> string?

return {}
