-- DCE AI Director & Organizations - Resource Entry Point
-- Registers both the Organizations and AI Director services.
-- Per ADR-0001: they share this resource but are registered as separate services.

local OrganizationsService = require("services.organizations")
local AIDirectorService = require("services.ai-director")

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

local initialized = false

local function OnAIStart()
    DCE:Log("ai", "info", "=== DCE AI Director & Organizations Starting ===")

    -- Initialize services
    OrganizationsService.Initialize()
    AIDirectorService.Initialize()

    -- Register the Organizations service
    DCE:RegisterService("Organizations", {
        GetState = function(orgId) return OrganizationsService.GetState(orgId) end,
        GetIdentity = function(orgId) return OrganizationsService.GetIdentity(orgId) end,
        GetLeadership = function(orgId) return OrganizationsService.GetLeadership(orgId) end,
        GetAllOrgIds = function() return OrganizationsService.GetAllOrgIds() end,
        GetOrgState = function(orgId) return OrganizationsService.GetOrgState(orgId) end,
        GetAllOrgStates = function() return OrganizationsService.GetAllOrgStates() end,
        SetOrganizationState = function(orgId, newState) return OrganizationsService.SetOrganizationState(orgId, newState) end,
        AddHeat = function(orgId, amount) OrganizationsService.AddHeat(orgId, amount) end,
        AddMoney = function(orgId, amount) OrganizationsService.AddMoney(orgId, amount) end,
    })

    -- Register the AI Director service
    DCE:RegisterService("AIDirector", {
        Tick = function() return AIDirectorService.Tick() end,
        EvaluateOrganization = function(orgId) return AIDirectorService.EvaluateOrganization(orgId) end,
        GetActiveDecision = function(orgId) return AIDirectorService.GetActiveDecision(orgId) end,
        ClearDecision = function(orgId) AIDirectorService.ClearDecision(orgId) end,
    })

    -- Schedule AI Director tick (time-sliced)
    DCE:Schedule("ai:director:tick", Config.AI.DirectorTickInterval, function()
        AIDirectorService.Tick()
    end, { immediate = true })

    initialized = true
    DCE:Log("ai", "info", "=== DCE AI Director & Organizations Started ===")
end

local function OnAIStop()
    DCE:Log("ai", "info", "=== DCE AI Director & Organizations Stopping ===")

    -- Unregister services
    DCE:UnregisterService("AIDirector")
    DCE:UnregisterService("Organizations")

    -- Shutdown services
    AIDirectorService.Shutdown()
    OrganizationsService.Shutdown()

    initialized = false
    DCE:Log("ai", "info", "=== DCE AI Director & Organizations Stopped ===")
end

-- ============================================================================
-- Lifecycle Hooks
-- ============================================================================

-- Wait for core to be ready before initializing
DCE:Once("core:initialized", function()
    OnAIStart()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnAIStop()
    end
end)