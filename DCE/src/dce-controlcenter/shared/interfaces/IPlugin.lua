-- DCE Control Center v2 - Plugin Interface
-- Base interface for all Control Center plugins

local IPlugin = {}

--- Get plugin manifest
---@return table
function IPlugin.GetManifest()
    error("IPlugin:GetManifest must be implemented by plugin")
end

--- Render plugin UI into container
---@param containerElement any DOM element reference
function IPlugin.Render(containerElement)
    error("IPlugin:Render must be implemented by plugin")
end

--- Called when plugin is activated
function IPlugin.OnActivate()
    -- Optional - default implementation does nothing
end

--- Called when plugin is deactivated
function IPlugin.OnDeactivate()
    -- Optional - default implementation does nothing
end

--- Handle event from EventBus
---@param eventName string
---@param payload table
function IPlugin.OnEvent(eventName, payload)
    -- Optional - default implementation does nothing
end

--- Cleanup resources when plugin unloads
function IPlugin.OnDestroy()
    -- Optional - default implementation does nothing
end

--- Check if plugin supports hot reload
---@return boolean
function IPlugin.SupportsHotReload()
    return false
end

return IPlugin