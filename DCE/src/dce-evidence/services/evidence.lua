-- DCE Evidence Service
-- Authoritative owner of evidence state. Manages the Evidence Registry,
-- evidence lifecycle, confidence scoring, and chain of custody.

-- Get modules safely from _G
local function getModule(name)
    return _G[name] or {}
end

local Evidence = getModule("DCEEvidence")
local Custody = getModule("DCECustody")

local EvidenceService = {}
local evidenceRegistry = {}  -- evidenceId -> Evidence instance
local custodyRecords = {}   -- evidenceId -> array of Custody records
local activeAdapter = nil
local isInitialized = false

--- Get Config safely
local function getConfig()
    return _G.Config or {}
end

function EvidenceService.Initialize()
    if isInitialized then
        return
    end
    if DCE and DCE.Log then
        DCE.Log("evidence", "info", "Evidence Service initializing...")
    end
    isInitialized = true
    if DCE and DCE.Log then
        DCE.Log("evidence", "info", "Evidence Service initialized")
    end
end

-- ============================================================================
-- Adapter Management
-- ============================================================================

--- Set the active evidence adapter.
---@param adapter table|nil Optional adapter implementing CreateEvidence, TransferEvidence, VerifyEvidence, LinkToCase
function EvidenceService.SetAdapter(adapter)
    activeAdapter = adapter
    if adapter then
        if DCE and DCE.Log then
            DCE.Log("evidence", "info", "Evidence adapter set")
        end
    else
        if DCE and DCE.Log then
            DCE.Log("evidence", "warn", "Evidence adapter cleared (using local standalone registry)")
        end
    end
end

--- Get the current evidence adapter.
---@return table|nil
function EvidenceService.GetAdapter()
    return activeAdapter
end

--- Resolve the configured evidence adapter or fall back to the local standalone registry.
function EvidenceService.InitializeAdapter()
    local Config = getConfig()
    local integration = {}
    if Config.Evidence and Config.Evidence.Integration then
        integration = Config.Evidence.Integration
    end
    local mode = integration.Mode or "native"

    if mode == "custom" and integration.Adapter then
        EvidenceService.SetAdapter(integration.Adapter)
        return
    end

    if mode == "ers" then
        -- ERS adapter is optional - check at runtime
        if _G.DCEERSEvidenceAdapter and _G.DCEERSEvidenceAdapter.New then
            local adapter = _G.DCEERSEvidenceAdapter.New(integration)
            if adapter and adapter.IsAvailable and adapter:IsAvailable() then
                EvidenceService.SetAdapter(adapter)
                return
            end
        end

        if integration.EnableStandaloneFallback ~= false then
            if DCE and DCE.Log then
                DCE.Log("evidence", "warn", "ERS evidence adapter unavailable; using local standalone registry")
            end
        end
    end

    -- Use native adapter as default fallback
    if mode == "native" or mode == "ers" or mode == "custom" then
        local nativeAdapter = _G.DCENativeEvidenceAdapter
        if nativeAdapter and nativeAdapter.New then
            EvidenceService.SetAdapter(nativeAdapter.New(integration))
            return
        end
    end

    EvidenceService.SetAdapter(nil)
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

    local evidence = nil
    if Evidence.New then
        evidence = Evidence.New(data)
    end
    if not evidence then
        return nil
    end

    evidenceRegistry[evidence.id] = evidence
    custodyRecords[evidence.id] = {}

    if DCE and DCE.Log then
        DCE.Log("evidence", "info", "Evidence created: %s (%s) - %s", evidence.id, evidence.type, evidence.description)
    end

    -- Emit event
    if DCE and DCE.Emit then
        DCE.Emit("evidence:item:created", {
            eventName = "evidence:item:created",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-evidence",
            correlationId = evidence.id,
            payload = evidence:GetSummary(),
        })
    end

    if activeAdapter and activeAdapter.CreateEvidence then
        activeAdapter.CreateEvidence(evidence:GetSummary())
    end

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
        if evidence then
            table.insert(all, evidence:GetSummary())
        end
    end
    return all
end

--- Get evidence linked to a specific scenario.
---@param scenarioId string
---@return table Array of evidence summaries
function EvidenceService.GetEvidenceByScenario(scenarioId)
    local results = {}
    for _, evidence in pairs(evidenceRegistry) do
        if evidence and evidence.scenarioId == scenarioId then
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
        if evidence and evidence.organizationId == organizationId then
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

    local custody = nil
    if Custody.New then
        custody = Custody.New(evidenceId, from, to, reason)
    end
    if custody then
        table.insert(custodyRecords[evidenceId], custody)

        if DCE and DCE.Emit then
            DCE.Emit("evidence:item:transferred", {
                eventName = "evidence:item:transferred",
                eventVersion = 1,
                timestamp = os.time(),
                source = "dce-evidence",
                correlationId = evidenceId,
                payload = custody:GetSummary(),
            })
        end

        if activeAdapter and activeAdapter.TransferEvidence then
            activeAdapter.TransferEvidence(custody:GetSummary())
        end
    end

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
        if record then
            table.insert(chain, record:GetSummary())
        end
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
    if evidence.Verify then
        evidence:Verify()
    end

    if DCE and DCE.Emit then
        DCE.Emit("evidence:item:verified", {
            eventName = "evidence:item:verified",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-evidence",
            correlationId = evidenceId,
            payload = evidence:GetSummary(),
        })
    end

    if activeAdapter and activeAdapter.VerifyEvidence then
        activeAdapter.VerifyEvidence(evidence:GetSummary())
    end

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
    if evidence.LinkToCase then
        evidence:LinkToCase(caseId)
    end

    if activeAdapter and activeAdapter.LinkToCase then
        activeAdapter.LinkToCase(evidenceId, caseId)
    end

    return true
end

-- ============================================================================
-- Shutdown
-- ============================================================================

function EvidenceService.Shutdown()
    if DCE and DCE.Log then
        DCE.Log("evidence", "info", "Evidence Service shutting down...")
    end
    for id, _ in pairs(evidenceRegistry) do
        evidenceRegistry[id] = nil
        custodyRecords[id] = nil
    end
    isInitialized = false
    if DCE and DCE.Log then
        DCE.Log("evidence", "info", "Evidence Service shutdown complete")
    end
end

_G.DCEEvidenceService = EvidenceService