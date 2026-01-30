export type InsertModelArgs = {
	query: string,
}

export type RunCodeArgs = {
	command: string,
}

export type PreviewLayoutArgs = {
	width: number,
	height: number,
	path: string?,
}

export type ToolArgs = { InsertModel: InsertModelArgs } | { RunCode: RunCodeArgs } | { PreviewLayout: PreviewLayoutArgs }

export type ToolFunction = (ToolArgs) -> string?

return {}
