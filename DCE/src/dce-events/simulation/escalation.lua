-- DCE Scenario Escalation
-- Handles Layer 2 -> Layer 3 promotion and dispatch triggering.

local Escalation = {}

--- Process escalation events from the state machine.
---@param events table Array of events from StateMachine.Tick
---@return table dispatchEvents Events that should trigger dispatch calls
function Escalation.ProcessEvents(events)
    local dispatchEvents = {}

    for _, event in ipairs(events) do
        if event.type == "scenario:dispatch_triggered" then
            -- This scenario has reached a dispatch-triggering stage
            table.insert(dispatchEvents, {
                type = "dispatch:call:requested",
                scenarioId = event.scenarioId,
                organizationId = event.organizationId,
                stage = event.stage,
                regionId = event.regionId,
                priority = "high",
                description = string.format("Suspicious activity reported in %s", event.regionId),
            })

            DCE:Log("events", "info", "Escalation: scenario %s triggered dispatch (stage: %s)",
                event.scenarioId, event.stage)
        end

        if event.type == "scenario:completed" then
            -- Scenario completed successfully
            DCE:Log("events", "info", "Escalation: scenario %s completed successfully", event.scenarioId)
        end

        if event.type == "scenario:timed_out" then
            -- Scenario timed out
            DCE:Log("events", "warn", "Escalation: scenario %s timed out", event.scenarioId)
        end
    end

    return dispatchEvents
end

--- Calculate the impact of a scenario on the world state.
---@param scenario table Scenario instance
---@return table { heatDelta, violenceDelta, evidenceCount }
function Escalation.CalculateImpact(scenario)
    local activityConfig = Config.AI.Activity[scenario.type]
    if not activityConfig then
        return { heatDelta = 5, violenceDelta = 0, evidenceCount = 1 }
    end

    return {
        heatDelta = activityConfig.HeatOutput or 5,
        violenceDelta = activityConfig.ViolenceOutput or 0,
        evidenceCount = 1,
    }
end

return Escalation