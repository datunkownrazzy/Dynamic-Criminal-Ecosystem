# AI Director Service

## Overview

The AI Director is DCE's operational logic center. It evaluates world state and organization state, scores activities, and selects what organizations do. The Director operates on a time-sliced model to distribute CPU load across ticks.

## Resource Location

`src/dce-ai/services/ai-director.lua`

## Service Registration

```lua
DCE.RegisterService("AIDirector", {
    Tick = function() return DCEAIDirectorService.Tick() end,
    EvaluateOrganization = function(orgId) return DCEAIDirectorService.EvaluateOrganization(orgId) end,
    GetActiveDecision = function(orgId) return DCEAIDirectorService.GetActiveDecision(orgId) end,
    ClearDecision = function(orgId) DCEAIDirectorService.ClearDecision(orgId) end,
})
```

## Dependencies

- **World** - For time/weather state and region context
- **Organizations** - For organization state and identity

## Public API

### Tick()

Executes the AI Director's scoring pass for one organization (time-sliced).

```lua
local decision = DCE.GetService("AIDirector").Tick()
-- Returns: nil or { organizationId, activityId, regionId, score }
```

**Behavior:**
- Processes one organization per call (round-robin)
- Decays perception pressure for the organization
- Evaluates eligible activities based on state
- Returns decision data or nil if no suitable activity found

### EvaluateOrganization(orgId)

Evaluates a single organization for possible activity decisions.

```lua
local decision = DCE.GetService("AIDirector").EvaluateOrganization("ballas")
-- Returns: nil or { organizationId, activityId, regionId, score }
```

**Parameters:**
- `orgId` (string) - Organization identifier

**Behavior:**
- Checks activity availability based on organization state
- Scores each available activity against all regions
- Selects from candidates using weighted lottery
- Emits `organization:activity:started` event on decision

### GetActiveDecision(orgId)

Gets the active decision for an organization.

```lua
local decision = DCE.GetService("AIDirector").GetActiveDecision("ballas")
-- Returns: nil or { activityId, regionId, score, startedAt }
```

### ClearDecision(orgId)

Clears the active decision for an organization (when scenario completes).

```lua
DCE.GetService("AIDirector").ClearDecision("ballas")
```

## Configuration

Configuration path: `Config.AI.DirectorTickInterval`

```lua
Config.AI = {
    DirectorTickInterval = 5000,  -- ms between evaluation ticks
    Scoring = {
        MinimumScore = 20,        -- Minimum score to create scenario
    },
}
```

## Events Emitted

| Event | Payload |
|-------|---------|
| `organization:activity:started` | { organizationId, activity, location, layer, score } |
| `ai:director:decision:executed` | { organizationId, activityId, regionId, score } |

## Architecture Notes

Per ADR-0004, the AI Director uses a time-sliced evaluation model:
- Each organization is evaluated once per tick interval
- CPU budgets ensure the evaluation doesn't block the main thread
- Perception pressure decay is applied during each organization's tick

Per ADR-0015, the Director integrates with the Profiler for performance monitoring:
- All decisions are tracked with timestamps
- Historical data enables trend analysis
- Budget alerts trigger when CPU exceeds threshold