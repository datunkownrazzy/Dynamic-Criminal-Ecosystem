-- DCE Control Center v2 - Dispatch Adapter (Authoritative)
-- Translates Dispatch subsystem data for CC UI

local DispatchAdapter = {}
local EventBus = nil
local Logger = nil
local dceCoreReady = false

local function ConnectToCore()
    if dceCoreReady then return true end
    if GetResourceState('dce-core') ~= 'started' then return false end
    local DCE = exports['dce-core']:GetDCEAPI()
    if not DCE then return false end
    EventBus = DCE.GetService and DCE.GetService("EventBus")
    Logger = DCE.GetService and DCE.GetService("Logger")
    dceCoreReady = true
    return true
end

function DispatchAdapter.GetActiveCalls()
    return {}
end

function DispatchAdapter.GetCallHistory()
    return {}
end

function DispatchAdapter.GetMetrics()
    return { active = 0, total = 0 }
end

function DispatchAdapter.GetCapabilities()
    return { admin = true, readOnly = false, actions = { "getActiveCalls", "getCallHistory" } }
end

ConnectToCore()
return DispatchAdapter