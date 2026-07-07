# DCE Performance Documentation

**Status:** Accepted
**Version:** 1.0
**Owner:** Architecture
**Dependencies:** ADR-0015, SimulationScheduler.md, SimulationBudget.md

---

## Purpose

This document describes the performance architecture of DCE, including budgets, optimization strategies, monitoring, and best practices for maintaining the target performance envelope.

---

## Performance Budget Structure

### Target Budgets

DCE targets specific CPU budgets per server state:

| Server State | Budget | Description |
|---|---|---|
| Idle | 0.10 ms/tick | Minimal activity, background simulation |
| RP Typical | 0.75 ms/tick | Normal roleplay activity |
| Heavy Activity | 1.5 ms/tick | High criminal/org activity |
| Maximum | 2.5 ms/tick | Hard limit before throttling |

### Per-Service Budgets

Each service receives an allocated budget:

| Service | Budget | Priority Tier |
|---|---|---|
| Scheduler | 0.05 ms | High |
| AI Director | 0.40 ms | Medium |
| Dispatch | 0.20 ms | High |
| Evidence | 0.15 ms | Medium |
| Economy | 0.25 ms | Medium |
| Weather | 0.02 ms | Low |
| Organizations | 0.30 ms | Medium |
| World (Layer 0) | 0.20 ms | Medium |
| World (Layer 1) | 0.30 ms | Medium |

### Budget Enforcement

The Profiler service monitors each service:

```lua
-- Before work
DCEProfiler.RecordStart("dispatch")
-- ... do work ...
-- After work
DCEProfiler.RecordEnd("dispatch")

-- If over budget, emits:
-- performance:budget:exceeded
```

When a service exceeds its budget:

1. Warning logged
2. Throttled/deferred execution applied
3. Admin dashboard notified
4. Work split across multiple ticks if possible

---

## Optimization Strategies

### 1. Service Isolation

Services are isolated to prevent cascading performance issues:

- Each service has independent budget
- Handler errors don't crash other services
- Work can be paused/resumed independently

### 2. Caching

The Cache service provides TTL-based caching:

```lua
-- Cache expensive computations
local result = DCECache.Get("world:region:" .. regionId)
if not result then
    result = ComputeRegionState(regionId)
    DCECache.Set("world:region:" .. regionId, result, { ttl = 30 })
end
```

**Default caches:**
- `world:regions` - Region state (5 min TTL)
- `organization:states` - Org states (5 min TTL)
- `dispatch:calls` - Active calls (2 min TTL)

### 3. Object Pooling

The Pool service minimizes allocations:

```lua
-- Use pooled objects
local npc = DCEPool.Acquire("npc")
if npc then
    npc.state = "active"
    npc.position = GetEntityCoords(entity)
    -- ... use npc ...
    DCEPool.Release("npc", npc)
end
```

**Pooled object types:**
- `npc` - Ambient civilians/criminals (max 50)
- `vehicle` - Scenario vehicles (max 30)
- `evidence` - Evidence items (max 100)
- `incident` - Active incidents (max 50)
- `dispatch_call` - Dispatch calls (max 30)

### 4. Event Bus Optimization

The Event Bus (per ADR-0015) supports optimization features:

| Feature | Purpose | Implementation |
|---|---|---|
| Priority handlers | Critical events first | `DCE.OnPriority("event", fn, "high")` |
| Debouncing | Rate limit high-frequency | `DCE.EmitDebounced("event", data, 100)` |
| Coalescing | Merge similar events | `DCE.EmitCoalesced("event", data, 500)` |
| Batching | Multiple events at once | `DCE.EmitBatch({events})` |
| Delayed | Defer handler execution | `DCE.EmitDelayed("event", data, 5000)` |

### 5. Simulation Layers

DCE uses layered simulation to manage fidelity:

| Layer | Frequency | Scope | CPU Budget |
|---|---|---|---|
| 0 - Statistical | 30s | Whole map | 0.20 ms |
| 1 - Ambient | 5s | Near players | 0.30 ms |
| 2 - Interactive | Event-driven | Active incidents | 0.50 ms |
| 3 - Major Incident | Event-driven | High-priority calls | 1.0 ms |

### 6. Adaptive AI Updates

Organizations update at different frequencies based on relevance:

| State | Frequency | Condition |
|---|---|---|
| Critical | 250 ms | Active incidents, heat spikes |
| Nearby | 500 ms | Near players |
| Active | 1000 ms | Normal operation |
| Passive | 5000 ms | Idle but tracked |
| Dormant | 30000 ms | Sleep until event |
| Sleeping | Never | Event-driven only |

---

## Monitoring

### Profiler API

```lua
-- Get current metrics
local metrics = DCEProfiler.GetMetrics("dispatch")

-- Get historical data (for graphs)
local history = DCEProfiler.GetHistory("dispatch", 60)

-- Get aggregate statistics
local stats = DCEProfiler.GetStats()
```

### Event Bus Metrics

```lua
-- Get bus-wide metrics
local busMetrics = DCE:GetService("CoreRegistry"):GetEventBusMetrics()

-- Get specific event metrics
local eventMetrics = DCE:GetService("CoreRegistry"):GetEventMetrics("dispatch:call:created")
```

### Scheduler Inspection

```lua
-- List all scheduled tasks
local tasks = DCE:GetService("CoreRegistry"):GetTasks()

-- Get task details
local task = DCE:GetService("CoreRegistry"):GetTask("world:layer0:tick")
```

---

## Admin Dashboard Integration

The Admin service exposes performance data:

```lua
-- Get dashboard metrics
local data = Admin.GetPerformanceMetrics()

-- Returns:
{
    totalCpuMs = 0.45,
    services = {
        dispatch = { cpuMs = 0.15, budgetMs = 0.20, status = "ok" },
        evidence = { cpuMs = 0.10, budgetMs = 0.15, status = "ok" },
    },
    eventsPerSecond = 42,
    queueDepths = {
        dispatch = 0,
        evidence = 0,
    },
}
```

---

## Debugging Performance Issues

### Console Commands

```
# List services and their budgets
dce.debug services --budgets

# Monitor specific service
dce.debug service dispatch --watch

# Check cache hit rates
dce.debug cache world:regions

# Check pool utilization
dce.debug pool npc

# Reset metrics
dce.debug profiler reset

# Set custom budget
dce.debug budget set dispatch 0.25
```

### Performance Events

| Event | Payload | When Emitted |
|---|---|---|
| `performance:budget:exceeded` | `{ serviceId, actualMs, budgetMs }` | Service exceeds budget |
| `admin:performance:alert` | `{ serviceId, actualMs, budgetMs }` | Admin dashboard warning |
| `admin:debug:mode:changed` | `{ mode, previousMode }` | Debug mode changed |

---

## Performance Anti-Patterns

### ❌ Don't Do This

```lua
-- Blocking SQL in event handler
DCE.On("evidence:item:created", function(payload)
    MySQL.Async.fetchAll("SELECT * FROM evidence WHERE ...", function(result)
        -- Heavy DB work in tick
    end)
end)

-- Unbounded iteration
for _, org in pairs(AllOrganizations) do
    UpdateOrganization(org) -- No budget check
end

-- Direct cross-module state mutation
local Org = DCE:GetService("Organizations")
Org.internalState.money = Org.internalState.money + 1000 -- Violates DataOwnership
```

### ✅ Do This Instead

```lua
-- Queue DB work
DCE.On("evidence:item:created", function(payload)
    -- Quick processing only
    EnqueueEvidenceForDB(payload)
end)

-- Time-slice heavy work
DCE.Schedule("economy:process", 5000, function()
    ProcessEconomyBatch(10) -- Process 10 items per tick
end)

-- Request state change via service
DCE:GetService("Economy").AddMoney(orgId, 1000)
```

---

## Benchmarking

### Running Benchmarks

```lua
-- Stress test mode
Config.Performance.StressTest = true

-- Run benchmark
exports['dce-core']:RunBenchmark("layer0:tick", 1000)
-- Returns: { avgMs, maxMs, minMs, samples }
```

### Expected Benchmarks (v1.0)

| Operation | Target (ms) | Maximum (ms) |
|---|---|---|
| Scheduler tick overhead | 0.01 | 0.05 |
| Event bus emit (10 handlers) | 0.05 | 0.20 |
| Cache get (hit) | 0.001 | 0.01 |
| Cache get (miss) | 0.01 | 0.05 |
| Pool acquire/release | 0.005 | 0.02 |
| World Layer 0 tick | 0.15 | 0.30 |
| Organization evaluation | 0.25 | 0.50 |

---

## Memory Management

### Leak Prevention

- Pools clean up on shutdown
- Caches respect TTL
- Event handlers cleared on shutdown
- Service references not cached long-term

### GC Pressure

- Minimize string concatenation
- Reuse tables where possible
- Use numeric keys in hot paths
- Avoid closures in loops

---

## FiveM-Specific Considerations

### Thread Safety

- All DCE code runs on main thread
- Citizen.CreateThread for background work
- No coroutine-based async

### Export Marshalling

- FiveM exports marshal function arguments to proxy tables
- Use `DCE_Subscribe` bridge for cross-resource events (ADR-0020)
- Don't pass functions across resource boundary

### Resource Timing

- Resources may start in any order
- Services use defensive nil checks
- Event subscriptions deferred until ready