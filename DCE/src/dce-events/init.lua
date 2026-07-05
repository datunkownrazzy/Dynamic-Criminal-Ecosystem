-- DCE Scenario Engine - Resource Entry Point

-- ============================================================================
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

local function OnEventsStart()
    local DCEAPI = GetDCEAPI()
    if not DCEAPI then
        print("^1[DCE Events] FATAL: Could not obtain DCE API from dce-core^0")
        return
    end
    _G.DCE = DCEAPI

    if DCE and DCE.Log then
        DCE.Log("events", "info", "=== DCE Scenario Engine Starting ===")
    end

    -- Initialize scenario engine (DCEScenarioEngine is set by services/scenario-engine.lua at load time)
    if DCEScenarioEngine and DCEScenarioEngine.Initialize then
        DCEScenarioEngine.Initialize()
    end

    -- Register the Scenario Engine service
    -- Defensive patterns: return nil OR actual value for service timing safety
    if DCE and DCE.RegisterService then
        DCE.RegisterService("ScenarioEngine", {
            CreateScenario = function(data) return DCEScenarioEngine and DCEScenarioEngine.CreateScenario(data) end,
            Tick = function() return DCEScenarioEngine and DCEScenarioEngine.Tick() end,
            GetScenario = function(scenarioId) return DCEScenarioEngine and DCEScenarioEngine.GetScenario(scenarioId) end,
            GetActiveScenarios = function() return DCEScenarioEngine and DCEScenarioEngine.GetActiveScenarios() end,
            GetAllScenarios = function() return DCEScenarioEngine and DCEScenarioEngine.GetAllScenarios() end,
            InterdictScenario = function(scenarioId) return DCEScenarioEngine and DCEScenarioEngine.InterdictScenario(scenarioId) end,
        })
    end

    -- Schedule scenario tick
    local Config = _G.Config or {}
    local tickInterval = 5000
    if Config.Scenario and Config.Scenario.TickInterval then
        tickInterval = Config.Scenario.TickInterval
    end
    if DCE and DCE.Schedule then
        DCE.Schedule("events:scenario:tick", tickInterval, function()
            if DCEScenarioEngine and DCEScenarioEngine.Tick then
                DCEScenarioEngine.Tick()
            end
        end)
    end

    if DCE and DCE.Log then
        DCE.Log("events", "info", "=== DCE Scenario Engine Started ===")
    end
end

local function OnEventsStop()
    -- Safely clean up - DCE may be nil if core shut down first
    if DCE and DCE.Log then
        DCE.Log("events", "info", "=== DCE Scenario Engine Stopping ===")
    end
    
    if DCE and DCE.UnregisterService then
        DCE.UnregisterService("ScenarioEngine")
    end
    
    if DCEScenarioEngine and DCEScenarioEngine.Shutdown then
        DCEScenarioEngine.Shutdown()
    end
    
    if DCE and DCE.Log then
        DCE.Log("events", "info", "=== DCE Scenario Engine Stopped ===")
    end
end

-- ============================================================================
-- Lifecycle Hooks
-- ============================================================================

-- Wait for AI to be ready before initializing (events depends on AI Director)
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == "dce-ai" then
        OnEventsStart()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnEventsStop()
    end
end)