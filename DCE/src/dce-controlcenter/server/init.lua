-- DCE Control Center v2 - Server Entry Point (Authoritative)
-- True Lazy Initialization: Bootstrap exists -> Nothing happens -> /dce -> Everything initializes
-- Per ADR-0026: No JavaScript initialization may occur before /dce.
-- Single entry point: /dce command from client.
-- Per CC-v2-COMPLETE-ARCHITECTURE.md: All services accessed via DCE:GetService(), never globals.

local Logger = nil
local EventBus = nil
local DCE = nil
local dceCoreReady = false

local function ConnectToCore()
    if dceCoreReady then return true end
    if GetResourceState('dce-core') ~= 'started' then return false end
    DCE = exports['dce-core']:GetDCEAPI()
    if not DCE then return false end
    Logger = DCE.GetService and DCE.GetService("Logger")
    EventBus = DCE.GetService and DCE.GetService("EventBus")
    dceCoreReady = true
    return true
end

local function log(level, message, ...)
    if Logger and Logger.Log then
        Logger.Log("controlcenter-init", level, message, ...)
    else
        print(("[DCE Init] %s: %s"):format(level, message:format(...)))
    end
end

-- ============================================================================
-- Service Access - Always via DCE:GetService(), never globals
-- ============================================================================

local function GetService(serviceName)
    if not DCE then return nil end
    return DCE.GetService and DCE.GetService(serviceName)
end

-- ============================================================================
-- Exports - Server-side only services
-- ============================================================================
-- FocusManager is NOT exported here because it is a client-side service.
-- It registers with DCE Core on the client and resolves only there.
-- Only server-side services are accessible via server_exports.

local function GetPluginAPI()
    local PR = GetService("PluginRegistry")
    if PR then
        return {
            registerPlugin = function(manifest)
                return PR.Register and PR.Register(manifest.id or manifest.name, manifest)
            end,
            getPlugins = function()
                return PR.ListPlugins and PR.ListPlugins() or {}
            end,
            isRegistered = function(pluginId)
                return PR.IsRegistered and PR.IsRegistered(pluginId) or false
            end
        }
    end
    return nil
end

local function GetSessionManager()
    return GetService("SessionManager")
end

local function GetWorkspaceManager()
    return GetService("WorkspaceManager")
end

local function GetPluginRegistry()
    return GetService("PluginRegistry")
end

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    log("info", "Resource starting - true lazy init architecture")
    local attempts = 0
    while not ConnectToCore() and attempts < 50 do
        Wait(100)
        attempts = attempts + 1
    end
    log("info", "Control Center ready - waiting for /dce commands from client")
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    log("info", "Resource stopping")
    if EventBus then
        EventBus.Emit("controlcenter:resource:stopping", {
            eventVersion = 1, timestamp = os.time(), source = "controlcenter-init"
        })
    end
end)

-- ============================================================================
-- Export Functions (server-side only - FocusManager excluded intentionally)
-- ============================================================================
-- FocusManager is a client-side service registered via DCE.Core on the client.
-- Server exports cannot resolve client-registered services.
-- Consumers must access FocusManager via client-side DCE:GetService("FocusManager").

exports('GetPluginAPI', GetPluginAPI)
exports('GetSessionManager', GetSessionManager)
exports('GetWorkspaceManager', GetWorkspaceManager)
exports('GetPluginRegistry', GetPluginRegistry)