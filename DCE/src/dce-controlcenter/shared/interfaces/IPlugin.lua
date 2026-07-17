--- DCE Control Center v2 - Plugin Interface
--- Plugins are passive components that respond to session lifecycle events

---@class IPlugin
---@field name string Plugin identifier
---@field version string Plugin version
---@field description string Plugin description
---@field Initialize fun(self: IPlugin): boolean Called when plugin module is loaded (session start)
---@field Start fun(self: IPlugin): boolean Called when application becomes active (focus granted)
---@field Stop fun(self: IPlugin): boolean Called when application is closing (before focus release)
---@field Destroy fun(self: IPlugin): boolean Called when session ends (cleanup)
---@field onMessage fun(self: IPlugin, action: string, data: table): boolean Handle NUI messages
---@field GetManifest fun(): table Returns plugin manifest for registration
---@field SetSessionState fun(self: IPlugin, key: string, value: any): nil Store session-specific state
---@field GetSessionState fun(self: IPlugin, key: string): any Get session-specific state

--- Plugin interface contract
--- Rules:
--- 1. Plugins NEVER call SetNuiFocus directly
--- 2. Plugins NEVER create UI windows directly
--- 3. Plugins ONLY implement lifecycle hooks
--- 4. Plugins MAY emit events via EventBus
--- 5. Plugins MAY receive events via EventBus subscriptions

local IPlugin = {}

--- Create a new plugin instance
---@param manifest table Plugin manifest table
---@return IPlugin
function IPlugin.New(manifest)
    local plugin = {
        name = manifest.name or "unknown",
        version = manifest.version or "1.0.0",
        description = manifest.description or "",
        sessionId = nil,
        _sessionState = {}
    }
    
    --- Initialize plugin (session start)
    ---@return boolean
    function plugin.Initialize()
        plugin.sessionId = nil
        return true
    end
    
    --- Start plugin (focus granted)
    ---@return boolean
    function plugin.Start()
        return true
    end
    
    --- Stop plugin (focus release pending)
    ---@return boolean
    function plugin.Stop()
        return true
    end
    
    --- Destroy plugin (cleanup)
    ---@return boolean
    function plugin.Destroy()
        plugin._sessionState = {}
        plugin.sessionId = nil
        return true
    end
    
    --- Set session state
    ---@param key string
    ---@param value any
    function plugin.SetSessionState(key, value)
        plugin._sessionState[key] = value
    end
    
    --- Get session state
    ---@param key string
    ---@return any
    function plugin.GetSessionState(key)
        return plugin._sessionState[key]
    end
    
    --- Get plugin manifest
    ---@return table
    function plugin.GetManifest()
        return {
            name = plugin.name,
            version = plugin.version,
            description = plugin.description
        }
    end
    
    return plugin
end

return IPlugin