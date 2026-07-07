# Scenario Engine Service

## Overview

The Scenario Engine manages scenario lifecycle: creation, progression, and resolution. Scenarios represent criminal activities that have materialized from the simulation. The engine processes state machine transitions and triggers dispatch calls when appropriate.

## Resource Location

`src/dce-events/services/scenario-engine.lua`

## Service Registration

```lua
DCE.RegisterService("ScenarioEngine", {
    CreateScenario = function(data) return DCEScenarioEngine.CreateScenario(data) end,
    Tick = function() return DCEScenarioEngine.Tick() end,
    GetScenario = function(scenarioId) return DCEScenarioEngine.GetScenario(scenarioId) end,
    GetActiveScenarios = function() return DCEScenarioEngine.GetActiveScenarios() end,
    GetAllScenarios = function() return DCEScenarioEngine.GetAllScenarios() end,
    InterdictScenario = function(scenarioId) return DCEScenarioEngine.InterdictScenario(scenarioId) end,
})
```

## Dependencies

- **dce-ai** - For organization and AI Director events
- **dce-dispatch** - For dispatch call creation
- **dce-evidence** - For evidence creation on scenario completion

## Public API

### CreateScenario(data)

Creates a new scenario from an AI Director decision.

```lua
local scenario = DCE.GetService("ScenarioEngine").CreateScenario({
    organizationId = "ballas",
    activityId = "deal_drugs",
    regionId = "vinewood",
    score = 45
})
-- Returns: { id, type, displayName, organizationId, regionId, status, currentStage } or nil
```

**Parameters:**
- `data` (table) - { organizationId, activityId, regionId, activity, score }

### Tick()

Ticks all active scenarios (called by scheduler).

```lua
local events = DCE.GetService("ScenarioEngine").Tick()
-- Returns: Array of processed state events
```

**Behavior:**
- Processes state machine transitions
- Handles escalation to dispatch
- Emits stage change and completion events

### GetScenario(scenarioId)

Gets a scenario by ID.

```lua
local scenario = DCE.GetService("ScenarioEngine").GetScenario("scenario-1")
-- Returns: Scenario summary or nil
```

### GetActiveScenarios()

Gets all active scenarios.

```lua
local active = DCE.GetService("ScenarioEngine").GetActiveScenarios()
-- Returns: { { id, status, ... }, ... }
```

### GetAllScenarios()

Gets all scenarios (active and completed).

```lua
local all = DCE.GetService("ScenarioEngine").GetAllScenarios()
-- Returns: { { id, status, ... }, ... }
```

### InterdictScenario(scenarioId)

Interdicts a scenario (e.g., police intervention).

```lua
local success = DCE.GetService("ScenarioEngine").InterdictScenario("scenario-1")
-- Returns: true if scenario was interdicted
```

## Scheduled Tasks

| Task | Interval | Function |
|------|----------|----------|
| `events:scenario:tick` | 5 seconds | Tick - Process active scenarios |

## Events Emitted

| Event | Payload |
|-------|---------|
| `scenario:created` | { id, type, organizationId, regionId, status, ... } |
| `scenario:stage:changed` | { scenarioId, fromStage, toStage } |
| `scenario:completed` | { scenarioId, outcome } |
| `scenario:timed_out` | { scenarioId } |
| `scenario:interdicted` | { scenarioId, outcome } |
| `dispatch:call:requested` | { incidentId, description, regionId, priority, organizationId, scenarioId } |

## State Machine

Scenarios follow a state machine progression:

```
pending → Active → [stage transitions] → Completed
                    ↓
                Interdicted
                    ↓
                   Timed Out
```

## Configuration

```lua
Config.Scenario = {
    TickInterval = 5000,  -- ms between scenario ticks
}
```

## Architecture Notes

Per ADR-0004, the Scenario Engine processes scenarios on a tick model:
- Each scenario progresses through stages independently
- Escalation rules determine when dispatch is called
- Evidence is automatically generated on completion

Per ADR-0015, the engine integrates with:
- EventBus for state change notifications
- Profiler for performance tracking
- Cache for scenario data retention