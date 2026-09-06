-- DCE Control Center v2 - Plugin Registry (Authoritative)
-- SOLE OWNER: Plugin registration, discovery, validation, lifecycle tracking
-- All plugins register here. No other module may track plugin state.
-- Per ADR-0026: Plugin Registry registers with DCE Core via Registry
--
-- SPRINT 1.11.1 FIX: Removed polling loop, removed cached EventBus/Logger,
-- removed direct EventBus:Emit) calls, uses canonical lifecycle events.
---@diagnostic disable: undefined-global

local PluginRegistry = {}
local DCE = nil

-- Plugin storage
local registeredPlugins = {} -- id -> manifest
local activePlugins = {}     -- id -> instance

local function AcquireSDK()
    local success, api = pcall(function()
        if exports and exports['dce-core'] and exports['dce-core'].GetDCEAPI then
            return exports['dce-core']:GetDCEAPI()
        end
        return nil
    end)
    if success then
        DCE = api
    end
    return DCE
end

local function log(level, message, ...)
    if DCE and DCE.Log then
        DCE:Log("plugin-registry", level, message, ...)
    else
        print(("[DCE PluginRegistry] %s: %s"):format(level, message:format(...)))
    end
end

-- ============================================================================
-- Plugin Validation
-- ============================================================================

local function ValidateManifest(manifest)
    if not manifest then return false, "Manifest is nil" end
    if not manifest.id then return false, "Plugin id is required" end
    if not manifest.name then return false, "Plugin name is required" end
    if not manifest.version then return false, "Plugin version is required" end
    return true, nil
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Register a plugin with the registry.
---@param manifest table Plugin manifest (id, name, version, description, author, dependencies)
---@return boolean success, string|nil error
function PluginRegistry.Register(manifest)
    if not DCE then
        log("error", "Cannot register plugin - SDK not acquired")
        return false, "SDK not available"
    end

    local valid, err = ValidateManifest(manifest)
    if not valid then
        log("error", "Invalid plugin manifest: %s", err or "unknown")
        return false, err
    end

    if registeredPlugins[manifest.id] then
        log("warn", "Plugin already registered, updating: %s", manifest.id)
    end

    registeredPlugins[manifest.id] = manifest
    log("info", "Plugin registered: %s v%s", manifest.id, manifest.version)

    DCE:Emit("plugin:registered", {
        eventVersion = 1, timestamp = os.time(), source = "plugin-registry",
        payload = { id = manifest.id, name = manifest.name, version = manifest.version }
    })

    return true, nil
end

--- Get a registered plugin manifest.
function PluginRegistry.GetPlugin(pluginId)
    return registeredPlugins[pluginId]
end

--- Get all registered plugin manifests.
function PluginRegistry.ListPlugins()
    local result = {}
    for id, manifest in pairs(registeredPlugins) do
        table.insert(result, manifest)
    end
    table.sort(result, function(a, b) return (a.priority or 999) < (b.priority or 999) end)
    return result
end

--- Get active plugin instances (server-side).
function PluginRegistry.ListActive()
    local result = {}
    for id, instance in pairs(activePlugins) do
        table.insert(result, { id = id, instance = instance })
    end
    return result
end

--- Mark a plugin as active.
function PluginRegistry.SetActive(pluginId, instance)
    activePlugins[pluginId] = instance or true
    log("info", "Plugin activated: %s", pluginId)
end

--- Mark a plugin as inactive.
function PluginRegistry.SetInactive(pluginId)
    activePlugins[pluginId] = nil
    log("info", "Plugin deactivated: %s", tostring(pluginId))
end

--- Unregister a plugin.
function PluginRegistry.Unregister(pluginId)
    registeredPlugins[pluginId] = nil
    activePlugins[pluginId] = nil
    log("info", "Plugin unregistered: %s", tostring(pluginId))
    if DCE then
        DCE:Emit("plugin:unregistered", {
            eventVersion = 1, timestamp = os.time(), source = "plugin-registry",
            payload = { id = pluginId }
        })
    end
    return true
end

--- Check if a plugin is registered.
function PluginRegistry.IsRegistered(pluginId)
    return registeredPlugins[pluginId] ~= nil
end

--- Validate plugin dependencies are all registered.
function PluginRegistry.ValidateDependencies(pluginId)
    local manifest = registeredPlugins[pluginId]
    if not manifest then return false, "Plugin not registered" end
    if not manifest.dependencies then return true, nil end

    for _, depId in ipairs(manifest.dependencies) do
        if not registeredPlugins[depId] then
            return false, ("Missing dependency: %s"):format(depId)
        end
    end
    return true, nil
end

--- Get plugin count.
function PluginRegistry.GetCount()
    local count = 0
    for _ in pairs(registeredPlugins) do count = count + 1 end
    return count
end

-- ============================================================================
-- Lifecycle
-- ============================================================================

function PluginRegistry.Init()
    if not DCE then
        log("error", "Cannot init - SDK not acquired")
        return false
    end

    if DCE.RegisterService then
        DCE:RegisterService("PluginRegistry", PluginRegistry)
        log("info", "Registered with DCE Core")
    end

    log("info", "Plugin Registry ready")
    return true
end

function PluginRegistry.Shutdown()
    registeredPlugins = {}
    activePlugins = {}
    log("info", "Plugin Registry shut down")
end

-- ============================================================================
-- Lifecycle — Subscribe to Canonical Lifecycle Events
-- ============================================================================

Citizen.CreateThread(function()
    Citizen.Wait(0)
    DCE = AcquireSDK()
    if DCE then
        DCE:On("lifecycle:running", function(payload)
            PluginRegistry.Init()
        end)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    PluginRegistry.Shutdown()
end)

-- ============================================================================
-- Administrative Interface
-- ============================================================================

function PluginRegistry.GetStatus()
    return {
        state = "running",
        uptime = os.time() - (PluginRegistry._startUptime or os.time()),
        registeredCount = PluginRegistry.GetCount()
    }
end

function PluginRegistry.GetHealth()
    return { healthy = true, errorCount = 0 }
end

function PluginRegistry.GetMetrics()
    return {
        registered = PluginRegistry.GetCount(),
        active = #PluginRegistry.ListActive()
    }
end

function PluginRegistry.GetCapabilities()
    return {
        admin = true,
        readOnly = false,
        actions = { "register", "unregister", "list", "validate" }
    }
end

PluginRegistry._startUptime = os.time()
return PluginRegistry