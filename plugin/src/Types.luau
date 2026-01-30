export type InsertModelArgs = {
	query: string,
}

export type RunCodeArgs = {
	command: string,
}

export type SearchAssetsArgs = {
	query: string,
	max_results: number?,
}

export type PreviewAssetArgs = {
	asset_id: number,
	keep: boolean?,
}

export type ToolArgs =
	{ InsertModel: InsertModelArgs }
	| { RunCode: RunCodeArgs }
	| { SearchAssets: SearchAssetsArgs }
	| { PreviewAsset: PreviewAssetArgs }

export type ToolFunction = (ToolArgs) -> string?

return {}
