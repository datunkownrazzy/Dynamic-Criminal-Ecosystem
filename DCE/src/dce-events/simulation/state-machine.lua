-- DCE Scenario State Machine
-- Manages stage progression for active scenarios.

local StateMachine = {}

--- Tick all active scenarios, advancing stages as needed.
---@param scenarios table Array of active Scenario instances
---@return table events Array of stage change events
function StateMachine.Tick(scenarios)
    local events = {}

    for _, scenario in ipairs(scenarios) do
        if scenario.status ~= "Active" then
            goto continue
        end

        -- Check for timeout
        if scenario:HasTimedOut() then
            scenario:Complete("Timed Out")
            table.insert(events, {
                type = "scenario:timed_out",
                scenarioId = scenario.id,
                organizationId = scenario.organizationId,
            })
            goto continue
        end

        -- Check if current stage is complete
        if scenario:IsStageComplete() then
            local newStage = scenario:AdvanceStage()
            if newStage then
                -- Stage advanced
                table.insert(events, {
                    type = "scenario:stage:changed",
                    scenarioId = scenario.id,
                    organizationId = scenario.organizationId,
                    fromStage = scenario.stages[scenario.currentStageIndex - 1],
                    toStage = newStage,
                    stageIndex = scenario.currentStageIndex,
                })

                -- Check if this triggers dispatch
                if scenario:IsDispatchTriggered() then
                    table.insert(events, {
                        type = "scenario:dispatch_triggered",
                        scenarioId = scenario.id,
                        organizationId = scenario.organizationId,
                        stage = newStage,
                        regionId = scenario.regionId,
                    })
                end
            else
                -- Scenario completed all stages successfully
                scenario:Complete("Completed")
                table.insert(events, {
                    type = "scenario:completed",
                    scenarioId = scenario.id,
                    organizationId = scenario.organizationId,
                    regionId = scenario.regionId,
                    heatGenerated = scenario.heatGenerated,
                    violenceGenerated = scenario.violenceGenerated,
                    evidenceGenerated = scenario.evidenceGenerated,
                })
            end
        end

        ::continue::
    end

    return events
end

_G.DCEStateMachine = StateMachine
