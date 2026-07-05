-- DCE Scenario Event Payload Type Declarations
-- This file contains ONLY type declarations for scenario domain event payloads.
-- All events from Event_Catalog_v1.md are defined here.
-- No runtime logic, no business logic.

--- @class ScenarioStartedPayload
--- Payload for organization:activity:started (also emitted as scenario:created internally)
---@field id string Scenario identifier
---@field type string Activity type
---@field displayName string Human-readable name
---@field organizationId string Owning organization
---@field regionId string Region where active
---@field activityId string Activity type ID
---@field priority string Priority level
---@field metadata table Additional metadata
---@field createdAt number Unix timestamp

--- @class ScenarioEscalatedPayload
--- Payload for organization:activity:escalated
---@field scenarioId string Scenario identifier
---@field fromStage string Previous stage
---@field toStage string New stage
---@field trigger string What triggered escalation

--- @class ScenarioResolvedPayload
--- Payload for scenario:lifecycle:resolved
---@field id string Scenario identifier
---@field status string Final status (Completed|Failed|Interdicted|TimedOut)
---@field completedAt number Unix timestamp
---@field heatGenerated number Total heat impact
---@field violenceGenerated number Total violence impact
---@field evidenceGenerated number Total evidence created

--- @class ScenarioStageChangedPayload
--- Payload for scenario:stage:changed
---@field scenarioId string Scenario identifier
---@field fromStage string Previous stage
---@field toStage string New stage
---@field stageIndex number New stage index
---@field progress number Stage progress 0-1.0

--- @class ScenarioTimedOutPayload
--- Payload for scenario:timed_out
---@field scenarioId string Scenario identifier
---@field elapsed number Elapsed seconds
---@field timeoutThreshold number Configured threshold

--- @class ScenarioInterdictedPayload
--- Payload for scenario:interdicted
---@field id string Scenario identifier
---@field organizationId string Organization that owned scenario
---@field regionId string Region where scenario was active