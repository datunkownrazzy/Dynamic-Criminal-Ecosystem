-- DCE Scenario Engine - Resource Entry Point

local ScenarioEngine = DCEScenarioEngine

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

local function OnEventsStart()
    DCE:Log("events", "info", "=== DCE Scenario Engine Starting ===")

    ScenarioEngine.Initialize()

    -- Register the ScenarioEngine service
    DCE:RegisterService("ScenarioEngine", {
        CreateScenario = function(data) return ScenarioEngine.CreateScenario(data) end,
        GetScenario = function(scenarioId) return ScenarioEngine.GetScenario(scenarioId) end,
        GetActiveScenarios = function() return ScenarioEngine.GetActiveScenarios() end,
        GetAllScenarios = function() return ScenarioEngine.GetAllScenarios() end,
        InterdictScenario = function(scenarioId) return ScenarioEngine.InterdictScenario(scenarioId) end,
    })

    -- Schedule scenario tick
    DCE:Schedule("scenario:engine:tick", Config.Scenario.TickInterval, function()
        ScenarioEngine.Tick()
    end, { immediate = true })

    -- Subscribe to AI Director decisions to create scenarios
    DCE:On("organization:activity:started", function(payload)
        local data = payload.payload or payload
        ScenarioEngine.CreateScenario({
            organizationId = data.organizationId,
            activityId = data.activity,
            regionId = data.location,
            score = data.score,
        })
    end)

    DCE:Log("events", "info", "=== DCE Scenario Engine Started ===")
end

local function OnEventsStop()
    DCE:Log("events", "info", "=== DCE Scenario Engine Stopping ===")

    DCE:UnregisterService("ScenarioEngine")
    ScenarioEngine.Shutdown()

    DCE:Log("events", "info", "=== DCE Scenario Engine Stopped ===")
end

-- ============================================================================
-- Lifecycle Hooks
-- ============================================================================

DCE:Once("core:initialized", function()
    OnEventsStart()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnEventsStop()
    end
end)