-- DCE Native Evidence Adapter
-- Provides standalone evidence functionality without any third-party integration.
-- This is the fallback adapter when ERS or other integrations are not available.

local NativeAdapter = {}
NativeAdapter.__index = NativeAdapter

--- Create a new Native adapter instance.
---@param config table Integration configuration (unused for native)
---@return table Adapter instance
function NativeAdapter.New(config)
    local self = setmetatable({}, NativeAdapter)
    self.config = config or {}
    return self
end

--- Check if the adapter is available.
---@return boolean Always true for native adapter
function NativeAdapter:IsAvailable()
    return true
end

--- Create evidence in the local registry.
---@param evidenceData table Evidence summary (for interface compatibility)
function NativeAdapter:CreateEvidence(evidenceData)
    -- Native adapter just acknowledges - evidence is stored in DCE registry
    -- No external integration needed
end

--- Transfer evidence (updates custody chain in DCE).
---@param transferData table Transfer data (for interface compatibility)
function NativeAdapter:TransferEvidence(transferData)
    -- Native adapter just acknowledges - custody handled by DCE
end

--- Verify evidence.
---@param evidenceData table Evidence summary (for interface compatibility)
function NativeAdapter:VerifyEvidence(evidenceData)
    -- Native adapter just acknowledges - verification handled by DCE
end

--- Link evidence to case.
---@param evidenceId string Evidence ID
---@param caseId string Case ID (for interface compatibility)
function NativeAdapter:LinkToCase(evidenceId, caseId)
    -- Native adapter just acknowledges - linking handled by DCE
end

--- Get diagnostics for the adapter.
---@return table Diagnostics information
function NativeAdapter:GetDiagnostics()
    return {
        status = "active",
        health = 100,
        latency = 0,
        queue = 0,
        errors = 0,
        lastCheck = os.time(),
        capabilities = { "CreateEvidence", "TransferEvidence", "VerifyEvidence", "LinkToCase" },
    }
end

--- Health check for the adapter.
---@return boolean Always true for native adapter
function NativeAdapter:HealthCheck()
    return true
end

_G.DCENativeEvidenceAdapter = NativeAdapter
return NativeAdapter
