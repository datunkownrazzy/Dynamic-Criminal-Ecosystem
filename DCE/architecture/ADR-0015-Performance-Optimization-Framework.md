# ADR-0015: Performance Optimization Framework

**Status:** Proposed
**Date:** 2026-07-06
**Author:** Architecture
**Dependencies:** ADR-0004 (Simulation Tick Model), DCE-0002 (Event Bus), DCE-0003 (Plugin Manifest)

---

## Problem

The DCE framework currently lacks systematic performance instrumentation and optimization controls. As more organizations, territories, and active scenarios are added, the system will eventually exceed the target performance budgets (idle <0.10ms, typical RP 0.25-0.75ms, heavy activity <1.5ms). Without measurable metrics and automatic alerts, performance degradation will be invisible until it becomes critical.

## Decision

### Performance Measurement Architecture

Every service, plugin, and adapter must expose standardized performance metrics through a central Profiler service. This enables:

1. **Real-time monitoring** in the Admin Panel
2. **Automatic alerts** when budgets are exceeded
3. **Historical analysis** for optimization decisions
4. **Hot profiling** without server restart

### Service Lifecycle Extension

Services must support a full lifecycle including Sleep/Wake for inactive periods:

```lua
-- Extended lifecycle methods (required on all services)
function Service.Initialize() -- One-time setup
function Service.Start()      -- Begin operations
function Service.Pause()      -- Temporarily suspend
function Service.Resume()     -- Resume from pause
function Service.Stop()       -- Graceful shutdown
function Service.Sleep()      -- Zero-CPU idle state
function Service.Wake()       -- Wake from sleep on event
function Service.Destroy()      -- Cleanup resources
function Service.GetMetrics()   -- Return { cpuMs, memoryBytes, eventCount, queueDepth, execFrequency }
```

### Tick Budget System

Each service receives a configurable CPU budget. The Scheduler enforces these budgets:

| Service | Budget (ms) | Priority Tier |
|---------|-------------|---------------|
| Scheduler | 0.05 | High |
| AI | 0.40 | Medium |
| Dispatch | 0.20 | High |
| Evidence | 0.15 | Medium |
| Economy | 0.25 | Medium |
| Weather | 0.02 | Low |
| Organizations | 0.30 | Medium |

When a service exceeds its budget:
1. Emit `performance:budget:exceeded`
2. Throttle/deferred execution
3. Split work across multiple ticks
4. Never stall the server

### Cache Strategy

All services support configurable caches with:
- **TTL** (time-to-live) expiration
- **Maximum size** limits
- **Invalidation** by key or pattern
- **Statistics** (hits, misses, evictions)

### Object Pooling

Common temporary objects are pooled:
- NPCs (ambient civilians, criminals)
- Vehicles (scenario vehicles)
- Evidence items
- Markers (temporary blips, draw texts)
- Any frequently-allocated temporary objects

### EventBus Optimization

The Event Bus supports:
- **Priority** - High/Low priority handlers
- **Batching** - Multiple events in single emit
- **Debouncing** - Rate limit same event type
- **Coalescing** - Merge similar events within window
- **Delayed execution** - Schedule handler for later
- **Async queues** - Queue for slow handlers
- **Filtering** - Scope events by region/player
- **Listener pooling** - Reuse handler closures
- **Weak references** - Allow GC of orphaned handlers

### AI Update Frequencies

Organizations use adaptive update frequencies:
- **Critical**: 250ms (active incidents, heat spikes)
- **Nearby**: 500ms (near players)
- **Active**: 1000ms (normal operation)
- **Passive**: 5000ms (idle but not dormant)
- **Dormant**: 30000ms (sleep until event)
- **Sleeping**: Never (event-driven only)

### Plugin Performance Declaration

Plugins declare in their manifest:
```lua
{
    DCE = {
        Min = "1.0.0",
        Max = "2.0.0",
        EstimatedCPU = 0.15,     -- ms per tick
        EstimatedMemory = 10240,  -- bytes
        TickRequirement = "medium", -- high|medium|low
        Dependencies = { "Dispatch" }
    }
}
```

The Plugin Manager validates these declarations and the Profiler tracks actual vs estimated usage.

### Performance Dashboard

The Admin Panel includes:
- CPU per service (real-time graph)
- CPU per plugin
- CPU per adapter
- Thread count
- Memory usage
- Network usage
- Scheduler queue depth
- Database queue depth
- Event counts per second
- Average/Max tick time

### Alert System

Automatic alerts when:
- Service exceeds CPU budget
- Memory grows beyond threshold
- Event rate spikes abnormally
- Queue depths grow unbounded
- Adapter latency increases

Alerts include call stack and optimization recommendations.

### Background Processing

Large jobs split incrementally:
- Relationship recalculation
- Territory updates
- Economy balancing
- Evidence cleanup
- Scenario generation

Each job reports progress and can be paused/resumed.

### Debug Modes

- **Production**: Minimal logging, full performance
- **Development**: Verbose logging, no performance impact
- **Verbose**: Debug traces, stack traces
- **Profiler**: Detailed metrics, minimal overhead
- **Stress Test**: Simulate heavy load
- **Simulation**: Deterministic timing
- **Benchmark**: Run performance tests

Development logging auto-disabled in production.

---

## Implementation Checklist

- [ ] Create Profiler service in dce-core
- [ ] Extend Scheduler with priority tiers and budgets
- [ ] Extend EventBus with optimization features
- [ ] Create Caching service
- [ ] Create Object Pooling service
- [ ] Update all services with GetMetrics()
- [ ] Extend Plugin Manifest spec with performance fields
- [ ] Update Admin Service performance dashboard
- [ ] Create Benchmark suite
- [ ] Create Debug mode manager

---

## Consequences

- Every feature addition requires performance impact analysis
- Services must be designed for budget compliance from start
- Plugins cannot hide expensive operations
- Admins can tune performance without restart
- Performance degrades gracefully under load