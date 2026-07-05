-- DCE ERS Evidence Adapter
-- Provides integration with the ERS evidence system.
-- Falls back gracefully if ERS is not available.

local ERSAdapter = {}
ERSAdapter.__index = ERSAdapter

--- Create a new ERS adapter instance.
---@param config table Integration configuration
---@return table Adapter instance
function ERSAdapter.New(config)
    local self = setmetatable({}, ERSAdapter)
    self.config = config or {}
    self.available = false

    -- Get ERS resource name from config (defaults to "ers")
    local Config = _G.Config or {}
    local ersConfig = (Config.Evidence and Config.Evidence.Integration) or {}
    local resourceName = ersConfig.ResourceName or "ers"

    -- Check if ERS is available at runtime
    if GetResourceState and GetResourceState(resourceName) == "started" then
        self.available = true
        if DCE and DCE.Log then
            DCE.Log("evidence", "info", "ERS evidence adapter: ERS resource detected and available")
        end
    else
        if DCE and DCE.Log then
            DCE.Log("evidence", "warn", "ERS evidence adapter: ERS resource not found, using local standalone registry")
        end
    end

    return self
end

--- Check if the adapter is available.
---@return boolean
function ERSAdapter:IsAvailable()
    return self.available
end

--- Create evidence in ERS.
---@param evidenceData table Evidence summary
function ERSAdapter:CreateEvidence(evidenceData)
    if not self.available then
        return
    end

    if exports and exports.ers and exports.ers.CreateEvidence then
        exports.ers.CreateEvidence(evidenceData)
    end
end

--- Transfer evidence in ERS.
---@param transferData table Transfer data
function ERSAdapter:TransferEvidence(transferData)
    if not self.available then
        return
    end

    if exports and exports.ers and exports.ers.TransferEvidence then
        exports.ers.TransferEvidence(transferData)
    end
end

--- Verify evidence in ERS.
---@param evidenceData table Evidence summary
function ERSAdapter:VerifyEvidence(evidenceData)
    if not self.available then
        return
    end

    if exports and exports.ers and exports.ers.VerifyEvidence then
        exports.ers.VerifyEvidence(evidenceData)
    end
end

--- Link evidence to case in ERS.
---@param evidenceId string
---@param caseId string
function ERSAdapter:LinkToCase(evidenceId, caseId)
    if not self.available then
        return
    end

    if exports and exports.ers and exports.ers.LinkEvidenceToCase then
        exports.ers.LinkEvidenceToCase(evidenceId, caseId)
    end
end

_G.DCEERSEvidenceAdapter = ERSAdapter