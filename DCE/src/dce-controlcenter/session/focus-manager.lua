-- DCE Control Center v2 - Focus Manager (Authoritative)
-- SOLE OWNER of SetNuiFocus - ONLY this file may call this native
-- Per ADR-0026: Every focus change is logged with full context
-- Registered with DCE Core via DCE:RegisterService() - never globals

local FocusManager = {}
local dceCoreReady = false
local EventBus = nil
local Logger = nil
local DCE = nil

local FOCUS_STATES = { RELEASED = "released", PENDING = "pending", ACQUIRED = "acquired" }
local currentState = FOCUS_STATES.RELEASED
local currentSessionId = nil

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

local function log(level, message)
    if Logger and Logger.Log then
        Logger.Log("focus", level, message)
    else
        print(("[DCE Focus] %s: %s"):format(level, message))
    end
end

local function logFocusChange(hasFocus, hasCursor, stateBefore, caller, reason)
    ConnectToCore()
    local timestamp = GetGameTimer and (GetGameTimer() * 1000) or (os.time() * 1000)
    local stack = debug and debug.traceback and debug.traceback() or "disabled"
    
    print(("[DCE-FOCUS][%s] ts=%d | before=%s | focus=%s | cursor=%s | caller=%s | reason=%s | session=%s")
        :format(hasFocus and "ACQUIRED" or "RELEASED", timestamp, stateBefore, 
                tostring(hasFocus), tostring(hasCursor), caller, reason, 
                tostring(currentSessionId or "none")))
    
    if EventBus and EventBus.Emit then
        EventBus.Emit("controlcenter:focus:" .. (hasFocus and "acquired" or "released"), {
            eventVersion = 1, timestamp = timestamp, source = "focus-manager",
            payload = { hasFocus = hasFocus, hasCursor = hasCursor, sessionId = currentSessionId, caller = caller, reason = reason }
        })
    end
end

-- ============================================================================
-- Public API
-- ============================================================================

function FocusManager.RequestFocus(sessionId, reason)
    ConnectToCore()
    if currentState == FOCUS_STATES.ACQUIRED then return true end
    
    local previous = currentState
    logFocusChange(true, true, previous, "FocusManager.RequestFocus", reason or "unknown")
    
    if SetNuiFocus then SetNuiFocus(true, true) end
    if SetNuiFocusKeepInput then SetNuiFocusKeepInput(false) end
    
    currentState = FOCUS_STATES.ACQUIRED
    currentSessionId = sessionId
    log("info", ("Focus acquired | session: %s"):format(tostring(sessionId)))
    return true
end

function FocusManager.ReleaseFocus(caller, reason)
    ConnectToCore()
    if currentState == FOCUS_STATES.RELEASED then return true end
    
    local previous = currentState
    logFocusChange(false, false, previous, caller or "FocusManager.ReleaseFocus", reason or "unknown")
    
    if SetNuiFocus then SetNuiFocus(false, false) end
    if SetNuiFocusKeepInput then SetNuiFocusKeepInput(false) end
    
    currentState = FOCUS_STATES.RELEASED
    currentSessionId = nil
    log("info", "Focus released")
    return true
end

function FocusManager.EmergencyRelease(reason)
    return FocusManager.ReleaseFocus("emergency", reason or "emergency")
end

function FocusManager.HasFocus()
    return currentState == FOCUS_STATES.ACQUIRED
end

function FocusManager.GetState()
    return currentState
end

function FocusManager.GetFocusedSession()
    return currentSessionId
end

function FocusManager.Reset()
    currentState = FOCUS_STATES.RELEASED
    currentSessionId = nil
end

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

AddEventHandler("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    local attempts = 0
    while not ConnectToCore() and attempts < 50 do
        Wait(100); attempts = attempts + 1
    end
    if DCE and DCE.RegisterService then
        DCE.RegisterService("FocusManager", FocusManager)
        log("info", "FocusManager registered with DCE Core")
    end
end)

AddEventHandler("onClientResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    FocusManager.EmergencyRelease("resource_stop")
end)

return FocusManager