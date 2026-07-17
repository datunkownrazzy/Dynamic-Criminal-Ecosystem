-- DCE Control Center v2 - Territory Adapter (Authoritative)

local TerritoryAdapter = {}
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

function TerritoryAdapter.List() return {} end
function TerritoryAdapter.Get(id) return nil end
function TerritoryAdapter.GetMetrics() return { total = 0, contested = 0 } end
function TerritoryAdapter.GetCapabilities() return { admin = true, readOnly = false, actions = { "list", "get", "getMetrics" } } end

ConnectToCore()
return TerritoryAdapter