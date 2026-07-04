-- DCE Evidence Service - Resource Entry Point

local EvidenceService = DCEEvidenceService
local EvidenceFactory = DCEEvidenceFactory
local ERSAdapter = DCERSAdapter

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

local function OnEvidenceStart()
    DCE:Log("evidence", "info", "=== DCE Evidence Service Starting ===")

    EvidenceService.Initialize()
    EvidenceService.InitializeAdapter()

    -- Register the Evidence service
    DCE:RegisterService("Evidence", {
        CreateEvidence = function(data) return EvidenceService.CreateEvidence(data) end,
        GetEvidence = function(evidenceId) return EvidenceService.GetEvidence(evidenceId) end,
        GetAllEvidence = function() return EvidenceService.GetAllEvidence() end,
        GetEvidenceByScenario = function(scenarioId) return EvidenceService.GetEvidenceByScenario(scenarioId) end,
        GetEvidenceByOrganization = function(orgId) return EvidenceService.GetEvidenceByOrganization(orgId) end,
        TransferEvidence = function(evidenceId, from, to, reason) return EvidenceService.TransferEvidence(evidenceId, from, to, reason) end,
        GetCustodyChain = function(evidenceId) return EvidenceService.GetCustodyChain(evidenceId) end,
        VerifyEvidence = function(evidenceId) return EvidenceService.VerifyEvidence(evidenceId) end,
        LinkToCase = function(evidenceId, caseId) return EvidenceService.LinkToCase(evidenceId, caseId) end,
        SetAdapter = function(adapter) EvidenceService.SetAdapter(adapter) end,
        GetAdapter = function() return EvidenceService.GetAdapter() end,
    })

    -- Subscribe to scenario completion events to create evidence
    DCE:On("scenario:completed", function(payload)
        local data = payload.payload or payload
        local evidenceData = EvidenceFactory.FromScenarioCompletion(data)
        if evidenceData then
            EvidenceService.CreateEvidence(evidenceData)
        end
    end)

    DCE:Log("evidence", "info", "=== DCE Evidence Service Started ===")
end

local function OnEvidenceStop()
    DCE:Log("evidence", "info", "=== DCE Evidence Service Stopping ===")

    DCE:UnregisterService("Evidence")
    EvidenceService.Shutdown()

    DCE:Log("evidence", "info", "=== DCE Evidence Service Stopped ===")
end

-- ============================================================================
-- Lifecycle Hooks
-- ============================================================================

DCE:Once("core:initialized", function()
    OnEvidenceStart()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnEvidenceStop()
    end
end)