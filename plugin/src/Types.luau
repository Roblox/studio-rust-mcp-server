export type InsertModelArgs = {
	query: string,
}

export type RunCodeArgs = {
	command: string,
}

export type CreateResponsiveLayoutArgs = {
	name: string,
	containers: {string},
}

export type ToolArgs = { InsertModel: InsertModelArgs } | { RunCode: RunCodeArgs } | { CreateResponsiveLayout: CreateResponsiveLayoutArgs }

export type ToolFunction = (ToolArgs) -> string?

return {}
