export type InsertModelArgs = {
	query: string,
}

export type RunCodeArgs = {
	command: string,
}

export type RunTestsArgs = {
	testCode: string,
}

export type ToolArgs = { InsertModel: InsertModelArgs } | { RunCode: RunCodeArgs } | { RunTests: RunTestsArgs }

export type ToolFunction = (ToolArgs) -> string?

return {}
