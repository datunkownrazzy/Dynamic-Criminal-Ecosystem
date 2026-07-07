-- DCE Evidence Service - Resource Entry Point
-- Defensive nil-check patterns are intentional for FiveM resource timing safety per ADR-0001

-- Resource Lifecycle
-- ============================================================================

local function GetDCEAPI()
    local DCEAPI = nil
    local attempts = 0
    while not DCEAPI and attempts < 50 do
        attempts = attempts + 1
        Citizen.Wait(100)
        local success, api = pcall(function()
            if exports and exports['dce-core'] and exports['dce-core'].GetDCEAPI then
                return exports['dce-core']:GetDCEAPI()
            end
            return nil
        end)
        if success then
            DCEAPI = api
        end
    end
    return DCEAPI
end

local function OnEvidenceStart()
    local DCEAPI = GetDCEAPI()
    if not DCEAPI then
        print("^1[DCE Evidence] FATAL: Could not obtain DCE API from dce-core^0")
        return
    end
    -- _G.DCE is owned by dce-core; use the API locally
    -- Do NOT overwrite _G.DCE to prevent race conditions

    if DCE and DCE.Log then
        DCE.Log("evidence", "info", "=== DCE Evidence Service Starting ===")
    end

    -- Initialize evidence service (DCEEvidenceService is set by services/evidence.lua at load time)
    if DCEEvidenceService and DCEEvidenceService.Initialize then
        DCEEvidenceService.Initialize()
    end
    if DCEEvidenceService and DCEEvidenceService.InitializeAdapter then
        DCEEvidenceService.InitializeAdapter()
    end

    -- Register the Evidence service
    -- Defensive patterns: return nil OR actual value for service timing safety
    if DCE and DCE.RegisterService then
        DCE.RegisterService("Evidence", {
            CreateEvidence = function(data) return DCEEvidenceService and DCEEvidenceService.CreateEvidence(data) end,
            GetEvidence = function(evidenceId) return DCEEvidenceService and DCEEvidenceService.GetEvidence(evidenceId) end,
            GetAllEvidence = function() return DCEEvidenceService and DCEEvidenceService.GetAllEvidence() end,
            GetEvidenceByScenario = function(scenarioId) return DCEEvidenceService and DCEEvidenceService.GetEvidenceByScenario(scenarioId) end,
            GetEvidenceByOrganization = function(orgId) return DCEEvidenceService and DCEEvidenceService.GetEvidenceByOrganization(orgId) end,
            TransferEvidence = function(evidenceId, from, to, reason) return DCEEvidenceService and DCEEvidenceService.TransferEvidence(evidenceId, from, to, reason) end,
            GetCustodyChain = function(evidenceId) return DCEEvidenceService and DCEEvidenceService.GetCustodyChain(evidenceId) end,
            VerifyEvidence = function(evidenceId) return DCEEvidenceService and DCEEvidenceService.VerifyEvidence(evidenceId) end,
            LinkToCase = function(evidenceId, caseId) return DCEEvidenceService and DCEEvidenceService.LinkToCase(evidenceId, caseId) end,
            SetAdapter = function(adapter) 
                if DCEEvidenceService and DCEEvidenceService.SetAdapter then 
                    DCEEvidenceService.SetAdapter(adapter) 
                end 
            end,
            GetAdapter = function() return DCEEvidenceService and DCEEvidenceService.GetAdapter() end,
        })
    end

    -- Subscribe to scenario completion events to create evidence
    if DCE and DCE.On then
        -- AUDIT: dce-evidence/init.lua:70 DCE.On event=scenario:completed
        print("[AUDIT-SITE] dce-evidence/init.lua:70 DCE.On event=scenario:completed cb_type=" .. type(function(payload) end))
        DCE.On("scenario:completed", function(payload)
            local data = payload and (payload.payload or payload)
            if data and DCEEvidenceFactory and DCEEvidenceFactory.FromScenarioCompletion then
                local evidenceData = DCEEvidenceFactory.FromScenarioCompletion(data)
                if evidenceData and DCEEvidenceService and DCEEvidenceService.CreateEvidence then
                    DCEEvidenceService.CreateEvidence(evidenceData)
                end
            end
        end)
    end

    if DCE and DCE.Log then
        DCE.Log("evidence", "info", "=== DCE Evidence Service Started ===")
    end
end

local function OnEvidenceStop()
    -- Safely clean up - DCE may be nil if core shut down first
    if DCE and DCE.Log then
        DCE.Log("evidence", "info", "=== DCE Evidence Service Stopping ===")
    end
    
    if DCE and DCE.UnregisterService then
        DCE.UnregisterService("Evidence")
    end
    
    if DCEEvidenceService and DCEEvidenceService.Shutdown then
        DCEEvidenceService.Shutdown()
    end
    
    if DCE and DCE.Log then
        DCE.Log("evidence", "info", "=== DCE Evidence Service Stopped ===")
    end
end

-- ============================================================================
-- Lifecycle Hooks
-- ============================================================================

-- Wait for events to be ready before initializing
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == "dce-events" then
        OnEvidenceStart()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnEvidenceStop()
    end
end)