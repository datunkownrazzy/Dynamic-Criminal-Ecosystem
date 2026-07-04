-- DCE Plugin Manager
-- Validates plugin manifests at startup per DCE-0003.
-- Ensures dependency presence, version compatibility, and ID uniqueness.

local PluginManager = {}
local loadedPlugins = {}  -- pluginId -> manifest
local logger

local DCE_VERSION = "1.0.0"

--- Initialize the plugin manager with a reference to the logger.
function PluginManager.Init(log)
    logger = log
end

--- Validate and register a plugin manifest.
--- Per DCE-0003 spec: validation happens before the plugin's Register/Subscribe/Activate phases.
---@param manifest table The plugin manifest table
---@return boolean valid, string|nil errorMessage
function PluginManager.Register(manifest)
    if not manifest or type(manifest) ~= "table" then
        return false, "manifest must be a table"
    end

    -- Validate required fields
    if not manifest.Name or type(manifest.Name) ~= "string" then
        return false, "manifest.Name is required and must be a string"
    end

    if not manifest.Id or type(manifest.Id) ~= "string" then
        return false, "manifest.Id is required and must be a string"
    end

    if not manifest.Version or type(manifest.Version) ~= "string" then
        return false, "manifest.Version is required and must be a semver string"
    end

    if not manifest.Requires or type(manifest.Requires) ~= "table" then
        return false, "manifest.Requires is required and must be an array"
    end

    if not manifest.DCE or not manifest.DCE.Min then
        return false, "manifest.DCE.Min is required"
    end

    -- Check ID uniqueness
    if loadedPlugins[manifest.Id] then
        return false, string.format("plugin ID '%s' is already registered by '%s'", manifest.Id, loadedPlugins[manifest.Id].Name)
    end

    -- Check DCE version compatibility
    if Config.PluginManager.FailOnVersionMismatch then
        local minOk = PluginManager.CompareVersions(DCE_VERSION, manifest.DCE.Min) >= 0
        if not minOk then
            return false, string.format(
                "plugin '%s' requires DCE >= %s, but running DCE %s",
                manifest.Id, manifest.DCE.Min, DCE_VERSION
            )
        end

        if manifest.DCE.Max then
            local maxOk = PluginManager.CompareVersions(manifest.DCE.Max, DCE_VERSION) >= 0
            if not maxOk then
                return false, string.format(
                    "plugin '%s' requires DCE <= %s, but running DCE %s",
                    manifest.Id, manifest.DCE.Max, DCE_VERSION
                )
            end
        end
    end

    -- Check dependency presence
    if Config.PluginManager.FailOnMissingDependency then
        for _, depId in ipairs(manifest.Requires) do
            -- Check if the dependency is a registered DCE service or a loaded resource
            local depFound = DCE and DCE.HasService and DCE:HasService(depId)
            if not depFound then
                -- Check if it's a FiveM resource
                local resourceState = GetResourceState(depId)
                if resourceState ~= "started" and resourceState ~= "starting" then
                    return false, string.format(
                        "plugin '%s' requires '%s' which is not available (resource state: %s)",
                        manifest.Id, depId, tostring(resourceState)
                    )
                end
            end
        end
    end

    -- Register the plugin
    loadedPlugins[manifest.Id] = manifest

    log("info", "core", "Plugin registered: %s v%s (%s)", manifest.Name, manifest.Version, manifest.Id)
    return true
end

--- Compare two semver strings.
---@param a string Version a
---@param b string Version b
---@return number -1 if a < b, 0 if a == b, 1 if a > b
function PluginManager.CompareVersions(a, b)
    local function parse(version)
        local parts = {}
        for part in string.gmatch(version, "%d+") do
            table.insert(parts, tonumber(part))
        end
        -- Pad to 3 parts (major.minor.patch)
        while #parts < 3 do
            table.insert(parts, 0)
        end
        return parts
    end

    local aParts = parse(a)
    local bParts = parse(b)

    for i = 1, 3 do
        if aParts[i] < bParts[i] then
            return -1
        elseif aParts[i] > bParts[i] then
            return 1
        end
    end

    return 0
end

--- Get a registered plugin's manifest.
---@param pluginId string
---@return table|nil
function PluginManager.Get(pluginId)
    return loadedPlugins[pluginId]
end

--- List all registered plugins.
---@return table Array of manifest tables
function PluginManager.List()
    local result = {}
    for _, manifest in pairs(loadedPlugins) do
        table.insert(result, manifest)
    end
    return result
end

--- Unregister a plugin. Called during resource stop.
---@param pluginId string
function PluginManager.Unregister(pluginId)
    if loadedPlugins[pluginId] then
        log("info", "core", "Plugin unregistered: %s", pluginId)
        loadedPlugins[pluginId] = nil
    end
end

--- Unregister all plugins. Called during shutdown.
function PluginManager.Clear()
    for pluginId, _ in pairs(loadedPlugins) do
        loadedPlugins[pluginId] = nil
    end
    log("info", "core", "PluginManager: all plugins cleared")
end

local function log(level, module, message, ...)
    if logger then
        logger.Log(module, level, message, ...)
    end
end

_G.DCEPluginManager = PluginManager
