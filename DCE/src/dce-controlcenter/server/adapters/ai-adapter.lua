-- DCE Control Center v2 - AI Adapter (Authoritative)

local AIAdapter = {}
local EventBus = nil; local Logger = nil; local dceCoreReady = false

local function ConnectToCore()
    if dceCoreReady then return true end
    if GetResourceState('dce-core') ~= 'started' then return false end
    local DCE = exports['dce-core']:GetDCEAPI()
    if not DCE then return false end
    EventBus = DCE.GetService and DCE.GetService("EventBus")
    Logger = DCE.GetService and DCE.GetService("Logger")
    dceCoreReady = true; return true
end

function AIAdapter.GetStatus() return { enabled = false, activeAgents = 0 } end
function AIAdapter.GetMetrics() return { total = 0 } end
function AIAdapter.GetCapabilities() return { admin = true, readOnly = false, actions = { "getStatus", "getMetrics" } } end

ConnectToCore()
return AIAdapter