-- DCE Scenario Engine - Resource Entry Point

local ScenarioEngine = DCEScenarioEngine

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
            return exports['dce-core']:GetDCEAPI()
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

    DCE.Log("events", "info", "=== DCE Scenario Engine Starting ===")

    ScenarioEngine.Initialize()

    -- Register the ScenarioEngine service
    DCE.RegisterService("ScenarioEngine", {
        CreateScenario = function(data) return ScenarioEngine.CreateScenario(data) end,
        GetScenario = function(scenarioId) return ScenarioEngine.GetScenario(scenarioId) end,
        GetActiveScenarios = function() return ScenarioEngine.GetActiveScenarios() end,
        GetAllScenarios = function() return ScenarioEngine.GetAllScenarios() end,
        InterdictScenario = function(scenarioId) return ScenarioEngine.InterdictScenario(scenarioId) end,
    })

-- Schedule scenario tick
    local Config = _G.Config or {}
    local tickInterval = 10000
    if Config.Scenario and Config.Scenario.TickInterval then
        tickInterval = Config.Scenario.TickInterval
    end
    DCE.Schedule("scenario:engine:tick", tickInterval, function()
        ScenarioEngine.Tick()
    end, { immediate = true })

    -- Subscribe to AI Director decisions to create scenarios
    DCE.On("organization:activity:started", function(payload)
        local data = payload.payload or payload
        ScenarioEngine.CreateScenario({
            organizationId = data.organizationId,
            activityId = data.activity,
            regionId = data.location,
            score = data.score,
        })
    end)

    DCE.Log("events", "info", "=== DCE Scenario Engine Started ===")
end

local function OnEventsStop()
    DCE.Log("events", "info", "=== DCE Scenario Engine Stopping ===")

    DCE.UnregisterService("ScenarioEngine")
    ScenarioEngine.Shutdown()

    DCE.Log("events", "info", "=== DCE Scenario Engine Stopped ===")
end

-- ============================================================================
-- Lifecycle Hooks
-- ============================================================================

-- Wait for AI to be ready before initializing
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