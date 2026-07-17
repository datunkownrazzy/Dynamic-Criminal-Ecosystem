-- DCE Control Center v2 - Evidence Adapter (Authoritative)

local EvidenceAdapter = {}
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

function EvidenceAdapter.List() return {} end
function EvidenceAdapter.Get(id) return nil end
function EvidenceAdapter.Create(data) return nil end
function EvidenceAdapter.Update(id, data) return false end
function EvidenceAdapter.Delete(id) return false end
function EvidenceAdapter.GetMetrics() return { total = 0 } end
function EvidenceAdapter.GetCapabilities() return { admin = true, readOnly = false, actions = { "list", "get", "create", "update", "delete" } } end

ConnectToCore()
return EvidenceAdapter