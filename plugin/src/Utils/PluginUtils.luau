local PluginUtils = {
	plugin = nil :: Plugin?,
}

function PluginUtils.getSettings(key: string): any
	assert(PluginUtils.plugin, "Plugin not set")
	return PluginUtils.plugin:GetSetting(key)
end

function PluginUtils.setSettings(key: string, value: any)
	assert(PluginUtils.plugin, "Plugin not set")
	PluginUtils.plugin:SetSetting(key, value)
end

return PluginUtils
