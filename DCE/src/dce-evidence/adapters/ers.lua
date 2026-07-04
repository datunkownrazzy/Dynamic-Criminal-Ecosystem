-- DCE ERS (Extended Roleplay System) Evidence Adapter
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

    -- Check if ERS is available
    if GetResourceState("ers") == "started" then
        self.available = true
        DCE.Log("evidence", "info", "ERS adapter: ERS resource detected and available")
    else
        DCE.Log("evidence", "warn", "ERS adapter: ERS resource not found, running in standalone mode")
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

    -- Export to ERS if available
    if exports.ers and exports.ers.AddEvidence then
        exports.ers.AddEvidence(evidenceData)
    end
end

--- Transfer evidence in ERS.
---@param custodyData table Custody record summary
function ERSAdapter:TransferEvidence(custodyData)
    if not self.available then
        return
    end

    if exports.ers and exports.ers.TransferEvidence then
        exports.ers.TransferEvidence(custodyData)
    end
end

--- Verify evidence in ERS.
---@param evidenceData table Evidence summary
function ERSAdapter:VerifyEvidence(evidenceData)
    if not self.available then
        return
    end

    if exports.ers and exports.ers.VerifyEvidence then
        exports.ers.VerifyEvidence(evidenceData)
    end
end

--- Link evidence to a case in ERS.
---@param evidenceId string
---@param caseId string
function ERSAdapter:LinkToCase(evidenceId, caseId)
    if not self.available then
        return
    end

    if exports.ers and exports.ers.LinkToCase then
        exports.ers.LinkToCase(evidenceId, caseId)
    end
end

_G.DCERSAdapter = ERSAdapter