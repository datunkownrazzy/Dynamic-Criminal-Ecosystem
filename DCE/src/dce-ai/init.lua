-- DCE AI Director & Organizations — Sprint 1.11.6 FiveM Loader Compliance
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
    error("dce-ai: exports['dce-core']:GetDCEAPI() returned nil. Add 'dce-core' to dependencies and ensure it starts first.")
end

local initialized = false

local function OnAIStart()
    if initialized then return end

    DCE:Log("ai", "info", "=== DCE AI Director & Organizations Starting ===")

    if DCEOrganizationsService and DCEOrganizationsService.Initialize then
        DCEOrganizationsService.Initialize()
    end
    if DCEAIDirectorService and DCEAIDirectorService.Initialize then
        DCEAIDirectorService.Initialize()
    end

    DCE:RegisterService("Organizations", {
        GetState = function(orgId) return DCEOrganizationsService and DCEOrganizationsService.GetState(orgId) end,
        GetIdentity = function(orgId) return DCEOrganizationsService and DCEOrganizationsService.GetIdentity(orgId) end,
        GetLeadership = function(orgId) return DCEOrganizationsService and DCEOrganizationsService.GetLeadership(orgId) end,
        GetAllOrgIds = function() return DCEOrganizationsService and DCEOrganizationsService.GetAllOrgIds() end,
        GetOrgState = function(orgId) return DCEOrganizationsService and DCEOrganizationsService.GetOrgState(orgId) end,
        GetAllOrgStates = function() return DCEOrganizationsService and DCEOrganizationsService.GetAllOrgStates() end,
        SetOrganizationState = function(orgId, newState) return DCEOrganizationsService and DCEOrganizationsService.SetOrganizationState(orgId, newState) end,
        AddHeat = function(orgId, amount) if DCEOrganizationsService and DCEOrganizationsService.AddHeat then DCEOrganizationsService.AddHeat(orgId, amount) end end,
        AddMoney = function(orgId, amount) if DCEOrganizationsService and DCEOrganizationsService.AddMoney then DCEOrganizationsService.AddMoney(orgId, amount) end end,
    })

    DCE:RegisterService("AIDirector", {
        Tick = function() return DCEAIDirectorService and DCEAIDirectorService.Tick() end,
        EvaluateOrganization = function(orgId) return DCEAIDirectorService and DCEAIDirectorService.EvaluateOrganization(orgId) end,
        GetActiveDecision = function(orgId) return DCEAIDirectorService and DCEAIDirectorService.GetActiveDecision(orgId) end,
        ClearDecision = function(orgId) if DCEAIDirectorService and DCEAIDirectorService.ClearDecision then DCEAIDirectorService.ClearDecision(orgId) end end,
    })

    local tickInterval = DCE:GetConfig("AI.DirectorTickInterval", 5000)
    DCE:Schedule("ai:director:tick", tickInterval, function()
        if DCEAIDirectorService and DCEAIDirectorService.Tick then
            DCEAIDirectorService.Tick()
        end
    end, { immediate = true })

    initialized = true
    DCE:Log("ai", "info", "=== DCE AI Director & Organizations Started ===")
end

local function OnAIStop()
    if not DCE then return end
    DCE:Log("ai", "info", "=== DCE AI Director & Organizations Stopping ===")
    DCE:UnregisterService("AIDirector")
    DCE:UnregisterService("Organizations")
    if DCEAIDirectorService and DCEAIDirectorService.Shutdown then
        DCEAIDirectorService.Shutdown()
    end
    if DCEOrganizationsService and DCEOrganizationsService.Shutdown then
        DCEOrganizationsService.Shutdown()
    end
    initialized = false
    DCE:Log("ai", "info", "=== DCE AI Director & Organizations Stopped ===")
end

-- ============================================================================
-- Lifecycle — Unconditional sticky subscription
-- ============================================================================
-- The EventBus replays sticky events to new subscribers, guaranteeing delivery
-- even if lifecycle:running was already emitted before this resource loaded.
DCE:On("lifecycle:running", function(payload)
    OnAIStart()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnAIStop()
    end
end)