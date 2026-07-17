-- DCE Control Center v2 - ControlCenter Service (Authoritative)
-- SOLE OWNER: Orchestration, permission validation, session coordination
-- Self-registers with DCE Core via Registry (never globals)
-- Per ADR-0026: True Lazy Initialization

local ControlCenterService = {}
local dceCoreReady = false
local Logger = nil
local EventBus = nil
local DCE = nil

local function ConnectToCore()
    if dceCoreReady then return true end
    if GetResourceState('dce-core') ~= 'started' then return false end
    
    DCE = exports['dce-core']:GetDCEAPI()
    if not DCE then return false end
    
    EventBus = DCE.GetService and DCE.GetService("EventBus")
    Logger = DCE.GetService and DCE.GetService("Logger")
    dceCoreReady = true
    return true
end

local function log(level, message, ...)
    if Logger and Logger.Log then
        Logger.Log("controlcenter", level, message, ...)
    else
        print(("[DCE CC] %s: %s"):format(level, message:format(...)))
    end
end

local function GetService(serviceName)
    if not DCE then return nil end
    return DCE.GetService and DCE.GetService(serviceName)
end

-- ============================================================================
-- Permission Validation
-- ============================================================================

function ControlCenterService.HasPermission(source)
    if not source then return false end
    if IsPlayerAceAllowed then
        return IsPlayerAceAllowed(source, "command.dce") or 
               IsPlayerAceAllowed(source, "group.admin") or
               IsPlayerAceAllowed(source, "group.superadmin")
    end
    return false
end

-- ============================================================================
-- Session Integration
-- ============================================================================

function ControlCenterService.RequestOpen(source)
    ConnectToCore()
    if not source or source == 0 then return false end
    if not ControlCenterService.HasPermission(source) then
        log("warn", "Player %d denied access", source)
        return false
    end
    
    local SM = GetService("SessionManager")
    if not SM then
        log("error", "SessionManager not available")
        return false
    end
    
    local existing = SM.GetSessionByPlayer(source)
    if existing then
        SM.ReuseSession(source)
        return true
    end
    
    local sessionId = SM.CreateSession(source)
    if not sessionId then
        log("error", "Failed to create session for player %d", source)
        return false
    end
    
    SM.StartSession(sessionId)
    return true
end

function ControlCenterService.RequestClose(source)
    local SM = GetService("SessionManager")
    if not SM then return false end
    
    local session = SM.GetSessionByPlayer(source)
    if not session then return true end
    
    SM.CloseSession(session.sessionId)
    SM.EndSession(session.sessionId)
    return true
end

-- ============================================================================
-- Init & Shutdown
-- ============================================================================

function ControlCenterService.Init()
    ConnectToCore()
    if not dceCoreReady then
        log("error", "Cannot init - dce-core not ready")
        return false
    end
    
    if DCE and DCE.RegisterService then
        DCE.RegisterService("ControlCenter", ControlCenterService)
        log("info", "Registered with DCE Core")
    end
    
    log("info", "Control Center Service ready")
    return true
end

function ControlCenterService.Shutdown()
    local SM = GetService("SessionManager")
    if SM then
        for _, session in pairs(SM.ListSessions()) do
            SM.CloseSession(session.sessionId)
            SM.EndSession(session.sessionId)
        end
    end
    log("info", "Control Center Service shut down")
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

RegisterNetEvent('dce-cc:server:open')
AddEventHandler('dce-cc:server:open', function()
    local src = source
    if src then ControlCenterService.RequestOpen(src) end
end)

RegisterNetEvent('dce-cc:server:close')
AddEventHandler('dce-cc:server:close', function()
    local src = source
    if src then ControlCenterService.RequestClose(src) end
end)

RegisterNetEvent('dce-cc:server:eventbus:subscribe')
AddEventHandler('dce-cc:server:eventbus:subscribe', function(data)
    local src = source
    ConnectToCore()
    if EventBus and EventBus.On and data and data.eventName then
        EventBus.On(data.eventName, function(payload)
            TriggerClientEvent('dce-cc:client:eventbus', src, {
                eventName = data.eventName,
                payload = payload
            })
        end)
    end
end)

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    local attempts = 0
    while not ConnectToCore() and attempts < 50 do
        Wait(100); attempts = attempts + 1
    end
    SetTimeout(0, function() ControlCenterService.Init() end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    ControlCenterService.Shutdown()
end)

-- ============================================================================
-- Administrative Contract
-- ============================================================================

ControlCenterService._startUptime = os.time()
function ControlCenterService.GetStatus()
    return { state = "running", uptime = os.time() - ControlCenterService._startUptime }
end
function ControlCenterService.GetHealth()
    return { healthy = true, errorCount = 0 }
end
function ControlCenterService.GetMetrics()
    local SM = GetService("SessionManager")
    return { activeSessions = SM and #SM.ListSessions() or 0 }
end
function ControlCenterService.GetCapabilities()
    return { admin = true, readOnly = false, actions = { "open", "close", "status" } }
end

return ControlCenterService