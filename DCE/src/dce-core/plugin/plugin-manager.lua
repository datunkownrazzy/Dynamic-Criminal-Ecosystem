-- DCE Plugin Architecture — Sprint 1.9 Freeze
-- Complete plugin lifecycle:
--   Discovery → Validation → Dependency Resolution → Loading
--   → Initialization → Ready → Shutdown → Unload
--
-- Supports:
--   Capability Discovery
--   Plugin Version Compatibility
--   Dependency Resolution
--
-- No plugins need to exist. Only the architecture.
---@diagnostic disable: undefined-global

local PluginArchitecture = {}

-- ============================================================================
-- Plugin Lifecycle States
-- ============================================================================

local State = {
    UNKNOWN      = "UNKNOWN",
    DISCOVERED   = "DISCOVERED",
    VALIDATED    = "VALIDATED",
    RESOLVED     = "RESOLVED",
    LOADING      = "LOADING",
    INITIALIZED  = "INITIALIZED",
    READY        = "READY",
    SHUTDOWN     = "SHUTDOWN",
    UNLOADED     = "UNLOADED",
    FAILED       = "FAILED",
}

local VALID_TRANSITIONS = {
    [State.UNKNOWN]     = { State.DISCOVERED, State.FAILED },
    [State.DISCOVERED]  = { State.VALIDATED, State.FAILED },
    [State.VALIDATED]   = { State.RESOLVED, State.FAILED },
    [State.RESOLVED]    = { State.LOADING, State.FAILED },
    [State.LOADING]     = { State.INITIALIZED, State.FAILED },
    [State.INITIALIZED] = { State.READY, State.FAILED },
    [State.READY]       = { State.SHUTDOWN, State.FAILED },
    [State.SHUTDOWN]    = { State.UNLOADED, State.FAILED },
    [State.UNLOADED]    = { State.DISCOVERED, State.FAILED },
    [State.FAILED]      = { State.DISCOVERED, State.UNLOADED },
}

-- ============================================================================
-- Plugin Manifest Schema
-- ============================================================================

local REQUIRED_MANIFEST_FIELDS = {
    "name",
    "version",
    "description",
    "author",
}

local OPTIONAL_MANIFEST_FIELDS = {
    "dependencies",
    "capabilities",
    "sdkVersion",
    "runtime",
    "interfaces",
}

-- ============================================================================
-- Plugin Instances
-- ============================================================================

local plugins = {}
local pluginIndex = 0

--- Validate a plugin manifest
---@param manifest table Plugin manifest
---@return boolean valid, string|nil error
local function validateManifest(manifest)
    if type(manifest) ~= "table" then
        return false, "Manifest must be a table"
    end

    for _, field in ipairs(REQUIRED_MANIFEST_FIELDS) do
        if not manifest[field] then
            return false, string.format("Missing required manifest field: %s", field)
        end
    end

    if type(manifest.version) ~= "string" then
        return false, "Plugin version must be a string (semver)"
    end

    return true, nil
end

--- Resolve plugin dependencies
---@param manifest table Plugin manifest
---@return table resolved, table unresolved
local function resolveDependencies(manifest)
    local resolved = {}
    local unresolved = {}

    if not manifest.dependencies then
        return resolved, unresolved
    end

    for _, depName in ipairs(manifest.dependencies) do
        if plugins[depName] then
            local depState = plugins[depName].state
            if depState == State.READY or depState == State.INITIALIZED then
                table.insert(resolved, depName)
            else
                table.insert(unresolved, depName)
            end
        else
            table.insert(unresolved, depName)
        end
    end

    return resolved, unresolved
end

--- Register a plugin
---@param manifest table Plugin manifest
---@return boolean success, string|nil error
function PluginArchitecture.Register(manifest)
    local valid, err = validateManifest(manifest)
    if not valid then
        return false, err
    end

    if plugins[manifest.name] then
        return false, string.format("Plugin already registered: %s", manifest.name)
    end

    pluginIndex = pluginIndex + 1
    plugins[manifest.name] = {
        id = pluginIndex,
        name = manifest.name,
        manifest = manifest,
        state = State.DISCOVERED,
        capabilities = manifest.capabilities or {},
        interfaces = manifest.interfaces or {},
        transitions = {},
        errors = {},
        registeredAt = os.time(),
    }

    return true
end

--- Transition a plugin to a new state
---@param name string Plugin name
---@param target string Target state
---@return boolean success, string|nil error
function PluginArchitecture.Transition(name, target)
    local plugin = plugins[name]
    if not plugin then
        return false, "Plugin not found: " .. name
    end

    local from = plugin.state
    local allowed = VALID_TRANSITIONS[from]
    if not allowed then
        return false, string.format("No transitions defined from %s", from)
    end

    local valid = false
    for _, s in ipairs(allowed) do
        if s == target then valid = true break end
    end
    if not valid then
        return false, string.format("Invalid transition: %s -> %s for plugin '%s'",
            from, target, name)
    end

    plugin.state = target
    table.insert(plugin.transitions, {
        from = from,
        to = target,
        time = os.time(),
    })

    return true
end

--- Validate a plugin (check manifest, version compatibility)
---@param name string Plugin name
---@return boolean success, string|nil error
function PluginArchitecture.Validate(name)
    local plugin = plugins[name]
    if not plugin then
        return false, "Plugin not found: " .. name
    end

    -- Check SDK version compatibility
    if plugin.manifest.sdkVersion then
        local sdkVersion = "1.0.0"
        if _G.DCE and _G.DCE.GetVersion then
            local ok, ver = pcall(_G.DCE.GetVersion)
            if ok then sdkVersion = ver end
        end
        if plugin.manifest.sdkVersion ~= sdkVersion then
            return false, string.format("SDK version mismatch: plugin requires %s, core has %s",
                plugin.manifest.sdkVersion, sdkVersion)
        end
    end

    return PluginArchitecture.Transition(name, State.VALIDATED)
end

--- Resolve dependencies for a plugin
---@param name string Plugin name
---@return boolean success, string|nil error, table unresolved
function PluginArchitecture.ResolveDependencies(name)
    local plugin = plugins[name]
    if not plugin then
        return false, "Plugin not found: " .. name, {}
    end

    local resolved, unresolved = resolveDependencies(plugin.manifest)

    if #unresolved > 0 then
        return false, string.format("Unresolved dependencies: %s", table.concat(unresolved, ", ")), unresolved
    end

    return PluginArchitecture.Transition(name, State.RESOLVED), nil, {}
end

--- Load a plugin
---@param name string Plugin name
---@return boolean success, string|nil error
function PluginArchitecture.Load(name)
    local plugin = plugins[name]
    if not plugin then
        return false, "Plugin not found: " .. name
    end

    local ok, err = PluginArchitecture.Transition(name, State.LOADING)
    if not ok then return false, err end

    -- Plugin loading is handled by the plugin's own init.lua
    -- This framework tracks the lifecycle state

    return PluginArchitecture.Transition(name, State.INITIALIZED)
end

--- Start a plugin (transition to READY)
---@param name string Plugin name
---@return boolean success, string|nil error
function PluginArchitecture.Start(name)
    return PluginArchitecture.Transition(name, State.READY)
end

--- Shutdown a plugin
---@param name string Plugin name
---@return boolean success, string|nil error
function PluginArchitecture.Shutdown(name)
    local ok, err = PluginArchitecture.Transition(name, State.SHUTDOWN)
    if not ok then return false, err end
    return PluginArchitecture.Transition(name, State.UNLOADED)
end

--- Get plugin state
---@param name string Plugin name
---@return string|nil
function PluginArchitecture.GetState(name)
    local plugin = plugins[name]
    if not plugin then return nil end
    return plugin.state
end

--- List all registered plugins
---@return table
function PluginArchitecture.List()
    local list = {}
    for name, plugin in pairs(plugins) do
        table.insert(list, {
            name = name,
            version = plugin.manifest.version,
            state = plugin.state,
            capabilities = plugin.capabilities,
            dependencies = plugin.manifest.dependencies or {},
            transitions = #plugin.transitions,
            errors = #plugin.errors,
        })
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

--- Discover plugins by capability
---@param capability string Capability name
---@return table List of plugins with this capability
function PluginArchitecture.DiscoverByCapability(capability)
    local results = {}
    for name, plugin in pairs(plugins) do
        for _, cap in ipairs(plugin.capabilities) do
            if cap == capability then
                table.insert(results, {
                    name = name,
                    version = plugin.manifest.version,
                    state = plugin.state,
                })
                break
            end
        end
    end
    return results
end

--- Get all available capabilities
---@return table
function PluginArchitecture.ListCapabilities()
    local capabilities = {}
    for _, plugin in pairs(plugins) do
        for _, cap in ipairs(plugin.capabilities) do
            capabilities[cap] = true
        end
    end
    local list = {}
    for cap in pairs(capabilities) do
        table.insert(list, cap)
    end
    table.sort(list)
    return list
end

--- Clear all plugins
function PluginArchitecture.Clear()
    plugins = {}
    pluginIndex = 0
end

-- ============================================================================
-- Register
-- ============================================================================

_G.DCEPluginArchitecture = PluginArchitecture
return PluginArchitecture