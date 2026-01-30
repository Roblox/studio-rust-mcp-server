export type InsertModelArgs = {
	query: string,
}

export type RunCodeArgs = {
	command: string,
}

export type ReadOutputArgs = {
	filter: string?, -- "all" | "print" | "warn" | "error"
	max_lines: number?, -- Maximum number of lines to return (default: 1000)
	clear_after_read: boolean?, -- Clear buffer after reading (default: true)
}

export type ToolArgs =
	{ InsertModel: InsertModelArgs }
	| { RunCode: RunCodeArgs }
	| { ReadOutput: ReadOutputArgs }

export type ToolFunction = (ToolArgs) -> string?

return {}
