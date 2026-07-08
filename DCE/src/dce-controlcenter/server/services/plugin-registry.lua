-- DCE Control Center v2 - Plugin Registry Service
-- Manages plugin registration and discovery for UI extensions
-- No hardcoded plugins - everything is discovered dynamically

local PluginRegistry = {}
local logger
local registeredPlugins = {}
local pluginCategories = {} -- category -> plugin list

--- Initialize the service
function PluginRegistry.Init(log)
    logger = log
    if logger then
        logger.Info("plugin-registry", "Initializing Plugin Registry...")
    end
end

--- Log helper
local function log(level, msg, ...)
    if logger then
        logger.Log("plugin-registry", level, msg, ...)
    end
end

--- Register plugin category
---@param category string
---@param pluginId string
local function registerPluginCategory(category, pluginId)
    if not pluginCategories[category] then
        pluginCategories[category] = {}
    end
    if not pluginCategories[category][pluginId] then
        table.insert(pluginCategories[category], pluginId)
    end
end

--- Unregister plugin category
---@param category string
---@param pluginId string
local function unregisterPluginCategory(category, pluginId)
    if pluginCategories[category] then
        for i, id in ipairs(pluginCategories[category]) do
            if id == pluginId then
                table.remove(pluginCategories[category], i)
                break
            end
        end
    end
end

--- Build standardized plugin info
---@param pluginId string
---@param manifest table
---@return table
function PluginRegistry.BuildPluginInfo(pluginId, manifest)
    return {
        id = pluginId,
        name = manifest.DisplayName or manifest.Name or pluginId,
        description = manifest.Description or "",
        version = manifest.Version or "unknown",
        author = manifest.Author or "unknown",
        icon = manifest.Icon or "🔧",
        category = (manifest.ControlCenter and manifest.ControlCenter.category) or "general",
        priority = manifest.Priority or 100,
        supportsHotReload = manifest.SupportsHotReload or false,
        provides = manifest.Provides or {},
        permissions = manifest.Permissions or {},
    }
end

--- Register a plugin with full manifest
---@param pluginId string
---@param manifest table Complete plugin manifest
---@return boolean
function PluginRegistry.Register(pluginId, manifest)
    if not pluginId or not manifest then
        log("error", "Plugin registration requires id and manifest")
        return false
    end
    
    -- Validate manifest structure
    if type(manifest) ~= "table" then
        log("error", "Plugin manifest must be a table")
        return false
    end
    
    -- Store plugin
    registeredPlugins[pluginId] = {
        id = pluginId,
        manifest = manifest,
        registeredAt = os.time(),
        enabled = true,
    }
    
    -- Register categories
    local cc = manifest.ControlCenter or {}
    local category = cc.category or "general"
    registerPluginCategory(category, pluginId)
    
    -- Register permissions if provided
    if manifest.Permissions then
        PluginRegistry._permissions = PluginRegistry._permissions or {}
        for _, perm in ipairs(manifest.Permissions.required or {}) do
            PluginRegistry._permissions[perm] = pluginId
        end
    end
    
    -- Register commands if provided
    if cc.commands then
        PluginRegistry._commands = PluginRegistry._commands or {}
        for _, cmd in ipairs(cc.commands) do
            PluginRegistry._commands[cmd.id or cmd.command] = {
                pluginId = pluginId,
                command = cmd,
            }
        end
    end
    
    -- Register routes/windows
    if cc.routes then
        PluginRegistry._routes = PluginRegistry._routes or {}
        for routePath, routeDef in pairs(cc.routes) do
            PluginRegistry._routes[routePath] = {
                pluginId = pluginId,
                route = routeDef,
            }
        end
    end
    
    log("info", "Registered plugin: %s (category: %s)", pluginId, category)
    return true
end

--- Unregister a plugin
---@param pluginId string
---@return boolean
function PluginRegistry.Unregister(pluginId)
    if not registeredPlugins[pluginId] then
        return false
    end
    
    -- Unregister from categories
    for category, _ in pairs(pluginCategories) do
        unregisterPluginCategory(category, pluginId)
    end
    
    -- Unregister permissions
    if PluginRegistry._permissions then
        for perm, pid in pairs(PluginRegistry._permissions) do
            if pid == pluginId then
                PluginRegistry._permissions[perm] = nil
            end
        end
    end
    
    registeredPlugins[pluginId] = nil
    log("info", "Unregistered plugin: %s", pluginId)
    return true
end

--- Get plugin manifest
---@param pluginId string
---@return table|nil
function PluginRegistry.GetManifest(pluginId)
    local plugin = registeredPlugins[pluginId]
    return plugin and plugin.manifest
end

--- List plugins by category
---@param category string|nil
---@return table
function PluginRegistry.ListPlugins(category)
    local result = {}
    if category then
        for _, pluginId in ipairs(pluginCategories[category] or {}) do
            local plugin = registeredPlugins[pluginId]
            if plugin and plugin.enabled then
                table.insert(result, PluginRegistry.BuildPluginInfo(pluginId, plugin.manifest))
            end
        end
    else
        for pluginId, plugin in pairs(registeredPlugins) do
            if plugin.enabled then
                table.insert(result, PluginRegistry.BuildPluginInfo(pluginId, plugin.manifest))
            end
        end
    end
    return result
end

--- Enable/disable a plugin
---@param pluginId string
---@param enabled boolean
---@return boolean
function PluginRegistry.SetEnabled(pluginId, enabled)
    if registeredPlugins[pluginId] then
        registeredPlugins[pluginId].enabled = enabled
        return true
    end
    return false
end

--- List all categories
---@return table
function PluginRegistry.ListCategories()
    local cats = {}
    for category, _ in pairs(pluginCategories) do
        table.insert(cats, category)
    end
    return cats
end

--- Get permissions for a plugin
---@param pluginId string
---@return table
function PluginRegistry.GetPluginPermissions(pluginId)
    local manifest = PluginRegistry.GetManifest(pluginId)
    if manifest and manifest.Permissions then
        return manifest.Permissions.required or {}
    end
    return {}
end

--- Build permission tree from all plugins
---@return table
function PluginRegistry.BuildPermissionTree()
    local tree = {}
    for pluginId, plugin in pairs(registeredPlugins) do
        if plugin.enabled and plugin.manifest.Permissions then
            for _, perm in ipairs(plugin.manifest.Permissions.required or {}) do
                tree[perm] = pluginId
            end
        end
    end
    return tree
end

--- Register a location provider
---@param providerId string
---@param provider table Provider module
---@return boolean
function PluginRegistry.RegisterLocationProvider(providerId, provider)
    PluginRegistry._locationProviders = PluginRegistry._locationProviders or {}
    PluginRegistry._locationProviders[providerId] = {
        provider = provider,
        initialized = false,
    }
    return true
end

--- Get location provider
---@param providerId string
---@return table|nil
function PluginRegistry.GetLocationProvider(providerId)
    local p = PluginRegistry._locationProviders and PluginRegistry._locationProviders[providerId]
    return p and p.provider
end

--- List all location providers
---@return table
function PluginRegistry.ListLocationProviders()
    local providers = {}
    for id, data in pairs(PluginRegistry._locationProviders or {}) do
        if data.initialized then
            table.insert(providers, id)
        end
    end
    return providers
end

--- Shutdown the registry
function PluginRegistry.Shutdown()
    registeredPlugins = {}
    pluginCategories = {}
    if PluginRegistry._locationProviders then
        for id, data in pairs(PluginRegistry._locationProviders) do
            if data.provider and data.provider.Shutdown then
                data.provider.Shutdown()
            end
            PluginRegistry._locationProviders[id] = nil
        end
    end
    log("info", "Plugin Registry shut down")
end

return PluginRegistry