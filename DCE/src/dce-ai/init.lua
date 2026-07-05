-- DCE AI Director & Organizations - Resource Entry Point
-- Registers both the Organizations and AI Director services.
-- Per ADR-0001: they share this resource but are registered as separate services.
-- Defensive nil-check patterns are intentional for FiveM resource timing safety per ADR-0001

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

local function OnAIStart()
    local DCEAPI = GetDCEAPI()
    if not DCEAPI then
        print("^1[DCE AI] FATAL: Could not obtain DCE API from dce-core^0")
        return
    end
    _G.DCE = DCEAPI

    if DCE and DCE.Log then
        DCE.Log("ai", "info", "=== DCE AI Director & Organizations Starting ===")
    end

    -- Initialize services (DCEOrganizationsService and DCEAIDirectorService are set by their files at load time)
    if DCEOrganizationsService and DCEOrganizationsService.Initialize then
        DCEOrganizationsService.Initialize()
    end
    if DCEAIDirectorService and DCEAIDirectorService.Initialize then
        DCEAIDirectorService.Initialize()
    end

    -- Register the Organizations service
    -- Defensive patterns: return nil OR actual value for service timing safety
    if DCE and DCE.RegisterService then
        DCE.RegisterService("Organizations", {
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
    end

    -- Register the AI Director service
    if DCE and DCE.RegisterService then
        DCE.RegisterService("AIDirector", {
            Tick = function() return DCEAIDirectorService and DCEAIDirectorService.Tick() end,
            EvaluateOrganization = function(orgId) return DCEAIDirectorService and DCEAIDirectorService.EvaluateOrganization(orgId) end,
            GetActiveDecision = function(orgId) return DCEAIDirectorService and DCEAIDirectorService.GetActiveDecision(orgId) end,
            ClearDecision = function(orgId) if DCEAIDirectorService and DCEAIDirectorService.ClearDecision then DCEAIDirectorService.ClearDecision(orgId) end end,
        })
    end

    -- Schedule AI Director tick (time-sliced)
    local Config = _G.Config or {}
    local directorTickInterval = 5000
    if Config.AI and Config.AI.DirectorTickInterval then
        directorTickInterval = Config.AI.DirectorTickInterval
    end
    if DCE and DCE.Schedule then
        DCE.Schedule("ai:director:tick", directorTickInterval, function()
            if DCEAIDirectorService and DCEAIDirectorService.Tick then
                DCEAIDirectorService.Tick()
            end
        end, { immediate = true })
    end

    initialized = true
    if DCE and DCE.Log then
        DCE.Log("ai", "info", "=== DCE AI Director & Organizations Started ===")
    end
end

local function OnAIStop()
    -- Safely clean up - DCE may be nil if core shut down first
    if DCE and DCE.Log then
        DCE.Log("ai", "info", "=== DCE AI Director & Organizations Stopping ===")
    end
    
    if DCE and DCE.UnregisterService then
        DCE.UnregisterService("AIDirector")
        DCE.UnregisterService("Organizations")
    end
    
    if DCEAIDirectorService and DCEAIDirectorService.Shutdown then
        DCEAIDirectorService.Shutdown()
    end
    if DCEOrganizationsService and DCEOrganizationsService.Shutdown then
        DCEOrganizationsService.Shutdown()
    end
    
    initialized = false
    if DCE and DCE.Log then
        DCE.Log("ai", "info", "=== DCE AI Director & Organizations Stopped ===")
    end
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