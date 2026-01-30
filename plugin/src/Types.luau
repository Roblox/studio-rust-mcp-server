export type InsertModelArgs = {
	query: string,
}

export type RunCodeArgs = {
	command: string,
}

export type ValidateUIArgs = {
	path: string?,
}

export type ToolArgs = { InsertModel: InsertModelArgs } | { RunCode: RunCodeArgs } | { ValidateUI: ValidateUIArgs }

export type ToolFunction = (ToolArgs) -> string?

return {}
