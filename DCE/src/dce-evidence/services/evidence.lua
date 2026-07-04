-- DCE Evidence Service
-- Authoritative owner of evidence state. Manages the Evidence Registry,
-- evidence lifecycle, confidence scoring, and chain of custody.

local Evidence = require("models.evidence")
local Custody = require("models.custody")

local EvidenceService = {}
local evidenceRegistry = {}  -- evidenceId -> Evidence instance
local custodyRecords = {}   -- evidenceId -> array of Custody records
local isInitialized = false

function EvidenceService.Initialize()
    if isInitialized then
        return
    end
    DCE:Log("evidence", "info", "Evidence Service initializing...")
    isInitialized = true
    DCE:Log("evidence", "info", "Evidence Service initialized")
end

-- ============================================================================
-- Service Interface
-- ============================================================================

--- Create a new evidence record.
---@param data table { type, description, source, organizationId?, scenarioId?, regionId?, confidence? }
---@return table|nil Evidence summary
function EvidenceService.CreateEvidence(data)
    if not data then
        return nil
    end

    local evidence = Evidence.New(data)
    evidenceRegistry[evidence.id] = evidence
    custodyRecords[evidence.id] = {}

    DCE:Log("evidence", "info", "Evidence created: %s (%s) - %s", evidence.id, evidence.type, evidence.description)

    -- Emit event
    DCE:Emit("evidence:item:created", {
        eventName = "evidence:item:created",
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-evidence",
        correlationId = evidence.id,
        payload = evidence:GetSummary(),
    })

    return evidence:GetSummary()
end

--- Get an evidence record by ID.
---@param evidenceId string
---@return table|nil
function EvidenceService.GetEvidence(evidenceId)
    local evidence = evidenceRegistry[evidenceId]
    if not evidence then
        return nil
    end
    return evidence:GetSummary()
end

--- Get all evidence records.
---@return table Array of evidence summaries
function EvidenceService.GetAllEvidence()
    local all = {}
    for _, evidence in pairs(evidenceRegistry) do
        table.insert(all, evidence:GetSummary())
    end
    return all
end

--- Get evidence linked to a specific scenario.
---@param scenarioId string
---@return table Array of evidence summaries
function EvidenceService.GetEvidenceByScenario(scenarioId)
    local results = {}
    for _, evidence in pairs(evidenceRegistry) do
        if evidence.scenarioId == scenarioId then
            table.insert(results, evidence:GetSummary())
        end
    end
    return results
end

--- Get evidence linked to a specific organization.
---@param organizationId string
---@return table Array of evidence summaries
function EvidenceService.GetEvidenceByOrganization(organizationId)
    local results = {}
    for _, evidence in pairs(evidenceRegistry) do
        if evidence.organizationId == organizationId then
            table.insert(results, evidence:GetSummary())
        end
    end
    return results
end

--- Transfer evidence (chain of custody).
---@param evidenceId string
---@param from string Previous holder
---@param to string New holder
---@param reason string Reason for transfer
---@return boolean success
function EvidenceService.TransferEvidence(evidenceId, from, to, reason)
    if not evidenceRegistry[evidenceId] then
        return false
    end

    local custody = Custody.New(evidenceId, from, to, reason)
    table.insert(custodyRecords[evidenceId], custody)

    DCE:Emit("evidence:item:transferred", {
        eventName = "evidence:item:transferred",
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-evidence",
        correlationId = evidenceId,
        payload = custody:GetSummary(),
    })

    return true
end

--- Get the chain of custody for an evidence item.
---@param evidenceId string
---@return table Array of custody records
function EvidenceService.GetCustodyChain(evidenceId)
    if not custodyRecords[evidenceId] then
        return {}
    end
    local chain = {}
    for _, record in ipairs(custodyRecords[evidenceId]) do
        table.insert(chain, record:GetSummary())
    end
    return chain
end

--- Verify an evidence item.
---@param evidenceId string
---@return boolean success
function EvidenceService.VerifyEvidence(evidenceId)
    local evidence = evidenceRegistry[evidenceId]
    if not evidence then
        return false
    end
    evidence:Verify()

    DCE:Emit("evidence:item:verified", {
        eventName = "evidence:item:verified",
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-evidence",
        correlationId = evidenceId,
        payload = evidence:GetSummary(),
    })

    return true
end

--- Link evidence to an investigation case.
---@param evidenceId string
---@param caseId string
---@return boolean success
function EvidenceService.LinkToCase(evidenceId, caseId)
    local evidence = evidenceRegistry[evidenceId]
    if not evidence then
        return false
    end
    evidence:LinkToCase(caseId)
    return true
end

-- ============================================================================
-- Shutdown
-- ============================================================================

function EvidenceService.Shutdown()
    DCE:Log("evidence", "info", "Evidence Service shutting down...")
    for id, _ in pairs(evidenceRegistry) do
        evidenceRegistry[id] = nil
        custodyRecords[id] = nil
    end
    isInitialized = false
    DCE:Log("evidence", "info", "Evidence Service shutdown complete")
end

return EvidenceService