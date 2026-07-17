-- DCE Control Center v2 - Session Manager Client (Authoritative)
-- Client-side session lifecycle management.
-- Receives commands from server, orchestrates local initialization.
-- Uses DCE:GetService() for dependencies - never globals.

local SessionManagerClient = {}
local currentSessionId = nil
local isActive = false

local DCE = nil
local dceCoreReady = false

local function GetService(serviceName)
    if not DCE then return nil end
    return DCE.GetService and DCE.GetService(serviceName)
end

local function ConnectToCore()
    if dceCoreReady then return true end
    if GetResourceState('dce-core') ~= 'started' then return false end
    DCE = exports['dce-core']:GetDCEAPI()
    dceCoreReady = true
    return true
end

local function log(level, message)
    print(("[DCE SessionClient] %s: %s"):format(level, message))
end

function SessionManagerClient.GetSessionId()
    return currentSessionId
end

function SessionManagerClient.IsActive()
    return isActive
end

-- ============================================================================
-- Session Boot Sequence
-- ============================================================================
-- Per CC-v2-COMPLETE-ARCHITECTURE.md:
-- 1. Browser activated (clean state)
-- 2. Application booted (JS lazy init)
-- 3. Focus acquired by FocusManager after boot completes

function SessionManagerClient.StartSession(data)
    if not data or not data.sessionId then
        log("error", "Invalid session start data")
        return
    end
    
    currentSessionId = data.sessionId
    isActive = true
    log("info", "Starting session: " .. tostring(data.sessionId))
    
    -- 1. Activate browser (ensure clean state)
    local BM = GetService("BrowserManager")
    if BM and BM.Activate then
        BM.Activate()
    end
    
    -- 2. Boot application in JS (lazy init) - Boot FIRST, then acquire focus
    SendNUIMessage({ action = "application:boot", data = { sessionId = data.sessionId } })
    
    -- 3. Focus is acquired by FocusManager after dce-cc:application:booted NUI callback
    log("info", "Session boot initiated for: " .. tostring(data.sessionId))
end

function SessionManagerClient.ReuseSession(data)
    if not data or not data.sessionId then return end
    
    currentSessionId = data.sessionId
    isActive = true
    log("info", "Reusing session: " .. tostring(data.sessionId))
    
    local WM = GetService("WorkspaceManager")
    if WM then
        local ws = WM.LoadWorkspace(GetPlayerServerId(PlayerId()))
        if ws then
            SendNUIMessage({ action = "application:restore-workspace", data = { windows = ws.windows or {} } })
        end
    end
    
    SendNUIMessage({ action = "application:activate", data = { sessionId = data.sessionId } })
end

function SessionManagerClient.EndSession(data)
    log("info", "Ending session: " .. tostring(currentSessionId))
    
    SendNUIMessage({ action = "application:shutdown", data = {} })
    
    local FM = GetService("FocusManager")
    if FM then
        FM.ReleaseFocus("session-manager-client", "session-end")
    end
    
    local endedSessionId = currentSessionId
    currentSessionId = nil
    isActive = false
    
    if endedSessionId then
        TriggerServerEvent('dce-cc:session:ended', { sessionId = data and data.sessionId or endedSessionId })
    end
    
    log("info", "Session ended")
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

RegisterNetEvent('dce-cc:client:session:start')
AddEventHandler('dce-cc:client:session:start', function(data)
    SessionManagerClient.StartSession(data)
end)

RegisterNetEvent('dce-cc:client:session:reuse')
AddEventHandler('dce-cc:client:session:reuse', function(data)
    SessionManagerClient.ReuseSession(data)
end)

RegisterNetEvent('dce-cc:client:session:end')
AddEventHandler('dce-cc:client:session:end', function(data)
    SessionManagerClient.EndSession(data)
end)

AddEventHandler("onClientResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if isActive then
        SendNUIMessage({ action = "application:shutdown", data = {} })
        isActive = false
        currentSessionId = nil
    end
end)

ConnectToCore()
return SessionManagerClient