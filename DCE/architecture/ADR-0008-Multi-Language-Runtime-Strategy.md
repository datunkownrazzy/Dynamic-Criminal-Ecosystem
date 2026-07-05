# ADR-0008: Multi-Language Runtime Strategy

**Status:** Accepted
**Date:** 2026-07-04
**Author:** Architecture
**Dependencies:** ADR-0004 (Simulation Tick Model), ADR-0007 (Hybrid Tech Stack)

---

## Problem

DCE needs predictable performance characteristics as simulation complexity grows. Without defined budgets and thresholds, service authors cannot make informed decisions about when to optimize or migrate to C#. This ADR establishes concrete performance targets and the profile-driven optimization policy.

---

## Decision

### Service Performance Budgets

Each DCE service must define a target execution budget. These are per-tick targets for server-side Lua execution, measured in milliseconds.

| Service | Target Budget | Notes |
|---------|---------------|-------|
| Event Bus | < 0.10 ms | Event dispatch should be nearly instantaneous |
| AI Director | < 0.50 ms | Organization scoring and decision making |
| World Engine | < 0.50 ms | Time, weather, region updates |
| Territory Manager | < 0.25 ms | Territory influence calculations |
| Economy | < 0.20 ms | Financial transfers, procurement |
| Dispatch | < 0.10 ms | Call creation and updates |
| Evidence | < 0.15 ms | Evidence registration |
| Admin | < 0.10 ms | Dashboard data aggregation |
| **Total Simulation** | **< 2.0 ms average** | Under realistic load |

**Budget Violation Protocol:**
1. Log warning via shared logger
2. Emit `scheduler:tier:budget_exceeded` event
3. Consider degradation or migration to C#

### Profile-First Optimization Policy

DCE operates on a **Profile -> Optimize -> Consider Migration** pipeline:

#### Step 1: Profile (Mandatory)
Before any optimization work:
```lua
local startTime = os.clock()
-- ... code to measure ...
local elapsed = (os.clock() - startTime) * 1000  -- ms
```

Or use the Scheduler's built-in timing:
```lua
DCE:Schedule("service:tick", interval, function()
    local result = MyService.DoWork()
    DCE:GetSchedulerStats()  -- Available for profiling
end, { priority = "Medium" })
```

#### Step 2: Optimize in Lua (Try First)
Common Lua optimizations:
- Localize global lookups (`local table = table` at top)
- Avoid string concatenation in loops
- Use `ipairs` for arrays, `pairs` for tables
- Cache service references: `local Orgs = DCE.GetService("Organizations")`
- Replace O(n²) algorithms with indexed lookups

#### Step 3: Consider C# Migration (Only After Profiling)
A subsystem is eligible for C# migration when:
- Consistently exceeds its budget under production-like conditions
- Profiling identifies the Lua code as a primary bottleneck
- Algorithmic optimization within Lua has been exhausted
- Moving the computation will not complicate the service architecture

### Integration Patterns

#### Lua → C# Communication

C# modules communicate via exports, never directly invoking service internals:

```lua
-- In a Lua service
local compute = exports['dce-compute']

function MyService.ExpensiveCalculation(data)
    local success, result = pcall(function()
        return compute:CalculateTerritoryInfluence(data)
    end)
    
    if not success or not result then
        -- Graceful fallback to Lua implementation
        return CalculateTerritoryInfluenceLua(data)
    end
    
    return result
end
```

#### Service Budget Configuration

Each service's config should include its budget for observability:

```lua
-- In service config.lua
Config.SimulationBudget = {
    TargetMs = 0.25,
    WarningThreshold = 0.20,  -- Warn at 80%
    DegradationAction = "skip_tick",  -- or "reduce_quality"
}
```

---

## Consequences

### Positive
- Predictable degradation behavior
- Clear signal when C# is justified
- Contributors can self-evaluate performance
- Server owners understand resource impact

### Architectural Requirements
- All services must declare their budgets
- Budget violations emit standardized events
- C# modules must gracefully fallback to Lua
- The Admin UI surfaces budget status (per `Admin_UI.md`)

### Implementation Notes
- These budgets are targets, not hard limits
- Real servers may exceed budgets temporarily under load
- The degradation system (ADR-0004) handles sustained violations
- Per-tier budgets in ADR-0004 cascade to service-level budgets