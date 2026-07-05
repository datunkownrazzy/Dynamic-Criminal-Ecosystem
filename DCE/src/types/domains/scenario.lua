-- DCE Scenario Domain Type Declarations
-- This file contains ONLY type declarations for the Scenario domain.
-- No runtime logic, no business logic.

--- @class IScenario
--- Scenario Model: Represents an active organizational activity.
---@field id string Unique scenario identifier
---@field type string Activity type
---@field displayName string Human-readable name
---@field organizationId string Owning organization
---@field regionId string Region where active
---@field activityId string Activity type ID
---@field status string Current status (Active, Completed, Failed, Interrupted)
---@field createdAt number Unix timestamp
---@field startedAt number Unix timestamp
---@field completedAt number|nil Unix timestamp
---@field currentStage string Current escalation stage
---@field priority string Priority level (low|medium|high)
---@field metadata table Additional metadata
---@field stages string[] Stage progression order
---@field currentStageIndex number Current stage index (1-based)
---@field stageStartedAt number Timestamp when current stage started
---@field stageDurations table Stage duration configuration
---@field layer number Simulation layer (0 or 1)
---@field heatGenerated number Heat impact
---@field violenceGenerated number Violence impact
---@field evidenceGenerated number Evidence count
---@field dispatchTriggered boolean Has dispatch been triggered
---@field dispatchCallId string|nil Associated dispatch call
---@field GetCurrentStage fun(self:IScenario):string
---@field GetStageIndex fun(self:IScenario):number
---@field GetStageCount fun(self:IScenario):number
---@field GetStageProgress fun(self:IScenario):number
---@field IsStageComplete fun(self:IScenario):boolean
---@field AdvanceStage fun(self:IScenario):string|nil
---@field IsDispatchTriggered fun(self:IScenario):boolean
---@field HasTimedOut fun(self:IScenario):boolean
---@field Complete fun(self:IScenario, status:string):nil

--- @class IScenarioEngine
--- Scenario Engine Service: Manages scenario lifecycle.
---@field Initialize fun(self:IScenarioEngine):nil
---@field CreateScenario fun(self:IScenarioEngine, data:table):ScenarioSummary|nil
---@field Tick fun(self:IScenarioEngine):table
---@field GetScenario fun(self:IScenarioEngine, scenarioId:string):ScenarioSummary|nil
---@field GetActiveScenarios fun(self:IScenarioEngine):ScenarioSummary[]
---@field GetAllScenarios fun(self:IScenarioEngine):ScenarioSummary[]
---@field InterdictScenario fun(self:IScenarioEngine, scenarioId:string):boolean
---@field Cleanup fun(self:IScenarioEngine):nil
---@field Shutdown fun(self:IScenarioEngine):nil

--- @class IStateMachine
--- State Machine: Processes scenario stage transitions.
---@field Tick fun(self:IStateMachine, scenarios:table[]):table[]

--- @class IEscalation
--- Escalation Engine: Processes state events and may request dispatch calls.
---@field ProcessEvents fun(self:IEscalation, events:table[]):table[]

--- @class ScenarioStages
--- Scenario stage names.
ScenarioStages = {
    Planning = "Planning",
    Travel = "Travel",
    Preparation = "Preparation",
    Execution = "Execution",
    Reaction = "Reaction",
    Escape = "Escape",
    Resolution = "Resolution",
}

--- @class ScenarioStatuses
--- Scenario status enum values.
ScenarioStatuses = {
    Active = "Active",
    Completed = "Completed",
    Failed = "Failed",
    Interdicted = "Interdicted",
    TimedOut = "Timed Out",
}