export type InsertModelArgs = {
	query: string,
	asset_id: number?,
}

export type RunCodeArgs = {
	command: string,
}

export type ToolArgs = { InsertModel: InsertModelArgs } | { RunCode: RunCodeArgs }

export type ToolFunction = (ToolArgs) -> string?

return {}
