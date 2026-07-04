-- DCE AI Director & Organizations - Resource Entry Point
-- Registers both the Organizations and AI Director services.
-- Per ADR-0001: they share this resource but are registered as separate services.

local OrganizationsService = DCEOrganizationsService
local AIDirectorService = DCEAIDirectorService

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

local initialized = false

local function GetDCEAPI()
    local DCEAPI = nil
    local attempts = 0
    while not DCEAPI and attempts < 50 do
        attempts = attempts + 1
        Citizen.Wait(100)
        local success, api = pcall(function()
            return exports['dce-core']:GetDCEAPI()
        end)
        if success then
            DCEAPI = api
        end
    end
    return DCEAPI
end

local function OnAIStart()
    local DCEAPI = GetDCEAPI()
    if not DCEAPI then
        print("^1[DCE AI] FATAL: Could not obtain DCE API from dce-core^0")
        return
    end
    _G.DCE = DCEAPI

    DCE.Log("ai", "info", "=== DCE AI Director & Organizations Starting ===")

    -- Initialize services
    OrganizationsService.Initialize()
    AIDirectorService.Initialize()

    -- Register the Organizations service
    DCE.RegisterService("Organizations", {
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
    DCE.RegisterService("AIDirector", {
        Tick = function() return AIDirectorService.Tick() end,
        EvaluateOrganization = function(orgId) return AIDirectorService.EvaluateOrganization(orgId) end,
        GetActiveDecision = function(orgId) return AIDirectorService.GetActiveDecision(orgId) end,
        ClearDecision = function(orgId) AIDirectorService.ClearDecision(orgId) end,
    })

-- Schedule AI Director tick (time-sliced)
    local Config = _G.Config or {}
    local directorTickInterval = 5000
    if Config.AI and Config.AI.DirectorTickInterval then
        directorTickInterval = Config.AI.DirectorTickInterval
    end
    DCE.Schedule("ai:director:tick", directorTickInterval, function()
        AIDirectorService.Tick()
    end, { immediate = true })

    initialized = true
    DCE.Log("ai", "info", "=== DCE AI Director & Organizations Started ===")
end

local function OnAIStop()
    DCE.Log("ai", "info", "=== DCE AI Director & Organizations Stopping ===")

    -- Unregister services
    DCE.UnregisterService("AIDirector")
    DCE.UnregisterService("Organizations")

    -- Shutdown services
    AIDirectorService.Shutdown()
    OrganizationsService.Shutdown()

    initialized = false
    DCE.Log("ai", "info", "=== DCE AI Director & Organizations Stopped ===")
end

-- ============================================================================
-- Lifecycle Hooks
-- ============================================================================

-- Wait for world to be ready before initializing (AI depends on World service)
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == "dce-world" then
        OnAIStart()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnAIStop()
    end
end)