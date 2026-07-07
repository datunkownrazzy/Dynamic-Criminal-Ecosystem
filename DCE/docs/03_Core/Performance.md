# DCE Performance Framework

**Status:** Proposed
**Version:** 1.0
**Owner:** Architecture
**Dependencies:** ADR-0015

---

## Overview

The DCE Performance Framework provides systematic performance monitoring, optimization, and alerting capabilities. Every component is designed to meet the target performance budgets:

- **Idle Server:** < 0.10 ms
- **Typical RP Server:** 0.25–0.75 ms
- **Heavy Criminal Activity:** < 1.5 ms
- **Absolute Maximum:** 2.5 ms

## Core Components

### Profiler Service (`dce-core/core/profiler.lua`)

Measures and tracks performance metrics for all services:

```lua
-- Start measuring a task
DCEProfiler.RecordStart("ai:director:tick")

-- Do work...

-- End measurement
DCEProfiler.RecordEnd("ai:director:tick")

-- Get metrics
local metrics = DCEProfiler.GetMetrics("ai:director:tick")
-- Returns: { cpuMs, memoryBytes, eventCount, queueDepth, execFrequency, lastUpdate }
```

### Cache Service (`dce-core/core/cache.lua`)

Configurable caching with TTL, max size, and invalidation:

```lua
-- Create a cache
DCECache.Create("organizations", { ttl = 300, maxSize = 1000 })

-- Set a value
DCECache.Set("organizations", "org:123", orgData)

-- Get a value (respects TTL)
local data = DCECache.Get("organizations", "org:123")

-- Invalidate by pattern
DCECache.InvalidatePattern("organizations", "org:%d+")

-- Get statistics
local stats = DCECache.GetStats("organizations")
-- Returns: { hits, misses, evictions, size, maxSize, ttl }
```

### Pool Service (`dce-core/core/pool.lua`)

Object pooling to minimize allocations:

```lua
-- Acquire a pooled object
local npc = DCEPool.Acquire("npc")

-- Release back to pool
DCEPool.Release("npc", npc)

-- Get pool statistics
local stats = DCEPool.GetStats("npc")
-- Returns: { available, inUse, totalCreated, totalReused, maxSize }
```

### Alert Handler (`dce-core/core/alert-handler.lua`)

Automatic performance alerts when budgets are exceeded:

```lua
-- Listens to performance:budget:exceeded events
-- Emits admin:performance:alert for dashboard display

-- Get recent alerts
local alerts = DCEAdminService.GetPerformanceAlerts()
```

## Configuration

Performance settings are configured in `dce-core/config.lua`:

```lua
Config.Performance = {
    IdleBudget = 0.10,
    RPBudget = 0.75,
    HeavyBudget = 1.5,
    MaxBudget = 2.5,
    AlertThreshold = 1.25,
    ProfilerEnabled = true,
    MaxHistorySize = 600,
}

Config.SimulationBudget = {
    Scheduler = 0.05,
    AI = 0.40,
    Dispatch = 0.20,
    Evidence = 0.15,
}
```

## Event Bus Optimizations

The Event Bus supports several performance optimizations:

### Priority Handlers

```lua
-- Register high-priority handler (runs before low-priority)
DCE.OnPriority("organization:activity:started", handlerFn, "high")
```

### Batching

```lua
-- Emit multiple events at once
DCE.EmitBatch({
    { eventName = "evidence:item:created", payload = {...} },
    { eventName = "dispatch:call:requested", payload = {...} },
})
```

### Debouncing

```lua
-- Rate-limit event emission
DCE.EmitDebounced("world:tick:event", payload, 100) -- 100ms minimum between emits
```

### Delayed Execution

```lua
-- Emit after delay (async)
DCE.EmitDelayed("cleanup:finished", payload, 5000) -- 5 second delay
```

## Service Integration

All services should implement `GetMetrics()`:

```lua
function Service:GetMetrics()
    return {
        cpuMs = self.lastCpuTime or 0,
        memoryBytes = self.memoryUsage or 0,
        eventCount = self.eventsProcessed or 0,
        queueDepth = #self.taskQueue,
        execFrequency = self.currentInterval or 1000,
    }
end
```

## Debug Modes

Set debug mode via config or runtime:

- **production:** Minimal logging, full performance
- **development:** Verbose logging, profiler enabled
- **verbose:** Debug traces, stack traces
- **profiler:** Detailed metrics collection
- **stress_test:** Simulate heavy load
- **benchmark:** Run performance tests

## Benchmark Suite

```lua
-- Run benchmarks programmatically
BenchmarkSuite.RunAll()

-- Get report
local report = BenchmarkSuite.GenerateReport()
```

## Best Practices

1. **Always use the Profiler** when implementing new services
2. **Cache frequently accessed data** with appropriate TTL
3. **Pool temporary objects** (NPCs, vehicles, evidence)
4. **Use priority handlers** for time-sensitive events
5. **Debounce high-frequency events** to prevent spam
6. **Monitor alerts** and respond to budget warnings