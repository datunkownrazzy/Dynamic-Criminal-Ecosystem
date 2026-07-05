-- DCE Scenario Engine Service
-- Manages scenario lifecycle: creation, progression, and resolution.

-- Get modules safely from _G
local function getModule(name)
    return _G[name] or {}
end

local Scenario = getModule("DCEScenario")
local StateMachine = getModule("DCEStateMachine")
local Escalation = getModule("DCEEscalation")

local ScenarioEngine = {}
local scenarios = {}       -- scenarioId -> Scenario instance
local scenarioCounter = 0
local isInitialized = false

--- Initialize the Scenario Engine.
function ScenarioEngine.Initialize()
    if isInitialized then
        return
    end
    if DCE and DCE.Log then
        DCE.Log("events", "info", "Scenario Engine initializing...")
    end
    isInitialized = true
    if DCE and DCE.Log then
        DCE.Log("events", "info", "Scenario Engine initialized")
    end
end

-- ============================================================================
-- Service Interface
-- ============================================================================

--- Create a new scenario from an AI Director decision.
---@param data table { organizationId, activityId, regionId, activity }
---@return table|nil The created scenario summary
function ScenarioEngine.CreateScenario(data)
    if not data or not data.organizationId or not data.activityId then
        if DCE and DCE.Log then
            DCE.Log("events", "error", "ScenarioEngine.CreateScenario: missing required data")
        end
        return nil
    end

    scenarioCounter = scenarioCounter + 1
    local scenarioId = "scenario-" .. scenarioCounter

    local scenario = nil
    if Scenario.New then
        scenario = Scenario.New(scenarioId, {
            type = data.activityId,
            displayName = data.activity and data.activity.displayName or "Activity",
            organizationId = data.organizationId,
            regionId = data.regionId,
            activityId = data.activityId,
            metadata = {
                score = data.score,
                source = "ai-director",
            },
        })
    end

    if not scenario then
        return nil
    end

    scenarios[scenarioId] = scenario

    if DCE and DCE.Log then
        DCE.Log("events", "info", "Scenario created: %s (%s) for %s in %s",
            scenarioId, scenario.displayName, data.organizationId, data.regionId)
    end

    -- Emit scenario created event
    if DCE and DCE.Emit then
        DCE.Emit("scenario:created", {
            eventName = "scenario:created",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-events",
            correlationId = scenarioId,
            payload = scenario:GetSummary(),
        })
    end

    return scenario:GetSummary()
end

--- Tick all active scenarios (called by scheduler).
---@return table events Processed events from this tick
function ScenarioEngine.Tick()
    if not isInitialized then
        return {}
    end

    -- Collect active scenarios
    local activeScenarios = {}
    for _, scenario in pairs(scenarios) do
        if scenario.status == "Active" then
            table.insert(activeScenarios, scenario)
        end
    end

    if #activeScenarios == 0 then
        return {}
    end

    -- Process state machine
    local stateEvents = {}
    if StateMachine and StateMachine.Tick then
        stateEvents = StateMachine.Tick(activeScenarios)
    end

    -- Process escalation
    local dispatchEvents = {}
    if Escalation and Escalation.ProcessEvents then
        dispatchEvents = Escalation.ProcessEvents(stateEvents)
    end

    -- Emit events
    for _, event in ipairs(stateEvents) do
        if DCE and DCE.Emit then
            if event.type == "scenario:stage:changed" then
                DCE.Emit("scenario:stage:changed", {
                    eventName = "scenario:stage:changed",
                    eventVersion = 1,
                    timestamp = os.time(),
                    source = "dce-events",
                    correlationId = event.scenarioId,
                    payload = event,
                })
            elseif event.type == "scenario:completed" then
                DCE.Emit("scenario:completed", {
                    eventName = "scenario:completed",
                    eventVersion = 1,
                    timestamp = os.time(),
                    source = "dce-events",
                    correlationId = event.scenarioId,
                    payload = event,
                })
            elseif event.type == "scenario:timed_out" then
                DCE.Emit("scenario:timed_out", {
                    eventName = "scenario:timed_out",
                    eventVersion = 1,
                    timestamp = os.time(),
                    source = "dce-events",
                    correlationId = event.scenarioId,
                    payload = event,
                })
            end
        end
    end

    -- Emit dispatch events
    for _, dispatchEvent in ipairs(dispatchEvents) do
        if DCE and DCE.Emit then
            DCE.Emit("dispatch:call:requested", {
                eventName = "dispatch:call:requested",
                eventVersion = 1,
                timestamp = os.time(),
                source = "dce-events",
                correlationId = dispatchEvent.scenarioId,
                payload = dispatchEvent,
            })
        end
    end

    -- Clean up completed scenarios after emitting events
    ScenarioEngine.Cleanup()

    return stateEvents
end

--- Get a scenario by ID.
---@param scenarioId string
---@return table|nil
function ScenarioEngine.GetScenario(scenarioId)
    local scenario = scenarios[scenarioId]
    if not scenario then
        return nil
    end
    return scenario:GetSummary()
end

--- Get all active scenarios.
---@return table Array of scenario summaries
function ScenarioEngine.GetActiveScenarios()
    local active = {}
    for _, scenario in pairs(scenarios) do
        if scenario and scenario.status == "Active" then
            table.insert(active, scenario:GetSummary())
        end
    end
    return active
end

--- Get all scenarios (active and completed).
---@return table Array of scenario summaries
function ScenarioEngine.GetAllScenarios()
    local all = {}
    for _, scenario in pairs(scenarios) do
        if scenario then
            table.insert(all, scenario:GetSummary())
        end
    end
    return all
end

--- Interdict a scenario (e.g., police intervention).
---@param scenarioId string
---@return boolean success
function ScenarioEngine.InterdictScenario(scenarioId)
    local scenario = scenarios[scenarioId]
    if not scenario or scenario.status ~= "Active" then
        return false
    end

    if scenario.Complete then
        scenario:Complete("Interdicted")
    end

    if DCE and DCE.Emit then
        DCE.Emit("scenario:interdicted", {
            eventName = "scenario:interdicted",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-events",
            correlationId = scenarioId,
            payload = scenario:GetSummary(),
        })
    end

    if DCE and DCE.Log then
        DCE.Log("events", "info", "Scenario interdicted: %s", scenarioId)
    end
    return true
end

--- Clean up completed scenarios (remove from active tracking after delay).
function ScenarioEngine.Cleanup()
    local toRemove = {}
    for scenarioId, scenario in pairs(scenarios) do
        if scenario and scenario.status ~= "Active" then
            -- Keep completed scenarios for a while, then remove
            if scenario.completedAt and (os.time() - scenario.completedAt) > 300 then
                table.insert(toRemove, scenarioId)
            end
        end
    end

    for _, scenarioId in ipairs(toRemove) do
        scenarios[scenarioId] = nil
    end
end

-- ============================================================================
-- Shutdown
-- ============================================================================

function ScenarioEngine.Shutdown()
    if DCE and DCE.Log then
        DCE.Log("events", "info", "Scenario Engine shutting down...")
    end
    for scenarioId, _ in pairs(scenarios) do
        scenarios[scenarioId] = nil
    end
    isInitialized = false
    if DCE and DCE.Log then
        DCE.Log("events", "info", "Scenario Engine shutdown complete")
    end
end

_G.DCEScenarioEngine = ScenarioEngine