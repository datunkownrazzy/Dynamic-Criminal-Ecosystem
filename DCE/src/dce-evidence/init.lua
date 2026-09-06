-- DCE Evidence Service — Sprint 1.11.6 FiveM Loader Compliance
--
-- PLATFORM CONSUMER.
-- Does NOT own runtime state. Does NOT poll. Does NOT retry.
--
-- SDK acquisition is DIRECT and UNCONDITIONAL:
--   local DCE = exports['dce-core']:GetDCEAPI()
--
-- Deterministic because fxmanifest.lua declares dependencies { 'dce-core' },
-- which per the FiveM resource manifest reference REQUIRES dce-core to load
-- and fully start BEFORE this resource executes any script.
---
---@diagnostic disable: undefined-global

-- ============================================================================
-- SDK Acquisition — Direct, single call, no polling, no retries
-- ============================================================================
local DCE = exports['dce-core']:GetDCEAPI()

if not DCE then
    error("dce-evidence: exports['dce-core']:GetDCEAPI() returned nil. Add 'dce-core' to dependencies and ensure it starts first.")
end

local initialized = false

local function OnEvidenceStart()
    if initialized then return end

    DCE:Log("evidence", "info", "=== DCE Evidence Service Starting ===")

    if DCEEvidenceService and DCEEvidenceService.Initialize then
        DCEEvidenceService.Initialize()
    end
    if DCEEvidenceService and DCEEvidenceService.InitializeAdapter then
        DCEEvidenceService.InitializeAdapter()
    end

    DCE:RegisterService("Evidence", {
        CreateEvidence = function(data) return DCEEvidenceService and DCEEvidenceService.CreateEvidence(data) end,
        GetEvidence = function(evidenceId) return DCEEvidenceService and DCEEvidenceService.GetEvidence(evidenceId) end,
        GetAllEvidence = function() return DCEEvidenceService and DCEEvidenceService.GetAllEvidence() end,
        GetEvidenceByScenario = function(scenarioId) return DCEEvidenceService and DCEEvidenceService.GetEvidenceByScenario(scenarioId) end,
        GetEvidenceByOrganization = function(orgId) return DCEEvidenceService and DCEEvidenceService.GetEvidenceByOrganization(orgId) end,
        TransferEvidence = function(evidenceId, from, to, reason) return DCEEvidenceService and DCEEvidenceService.TransferEvidence(evidenceId, from, to, reason) end,
        GetCustodyChain = function(evidenceId) return DCEEvidenceService and DCEEvidenceService.GetCustodyChain(evidenceId) end,
        VerifyEvidence = function(evidenceId) return DCEEvidenceService and DCEEvidenceService.VerifyEvidence(evidenceId) end,
        LinkToCase = function(evidenceId, caseId) return DCEEvidenceService and DCEEvidenceService.LinkToCase(evidenceId, caseId) end,
        SetAdapter = function(adapter) if DCEEvidenceService and DCEEvidenceService.SetAdapter then DCEEvidenceService.SetAdapter(adapter) end end,
        GetAdapter = function() return DCEEvidenceService and DCEEvidenceService.GetAdapter() end,
    })

    -- Subscribe to scenario completion events
    DCE:On("scenario:completed", function(payload)
        local data = payload and (payload.payload or payload)
        if data and DCEEvidenceFactory and DCEEvidenceFactory.FromScenarioCompletion then
            local evidenceData = DCEEvidenceFactory.FromScenarioCompletion(data)
            if evidenceData and DCEEvidenceService and DCEEvidenceService.CreateEvidence then
                DCEEvidenceService.CreateEvidence(evidenceData)
            end
        end
    end)
    DCE:Log("evidence", "info", "Subscribed to scenario:completed")

    initialized = true
    DCE:Log("evidence", "info", "=== DCE Evidence Service Started ===")
end

local function OnEvidenceStop()
    if not DCE then return end
    DCE:Log("evidence", "info", "=== DCE Evidence Service Stopping ===")
    DCE:UnregisterService("Evidence")
    if DCEEvidenceService and DCEEvidenceService.Shutdown then
        DCEEvidenceService.Shutdown()
    end
    initialized = false
    DCE:Log("evidence", "info", "=== DCE Evidence Service Stopped ===")
end

-- ============================================================================
-- Lifecycle — Unconditional sticky subscription
-- ============================================================================
-- The EventBus replays sticky events to new subscribers, guaranteeing delivery
-- even if lifecycle:running was already emitted before this resource loaded.
DCE:On("lifecycle:running", function(payload)
    OnEvidenceStart()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnEvidenceStop()
    end
end)