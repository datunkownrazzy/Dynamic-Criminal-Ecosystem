# ADR-0012: Resource Lifecycle and Initialization

**Status:** Accepted
**Date:** 2026-07-07
**Author:** Architecture
**Dependencies:** DCE-0001 (Service Registry), DCE-0002 (Event Bus), ADR-0004 (Simulation Tick Model)

---

## Problem

DCE resources must initialize in a specific order to satisfy dependencies, but FiveM loads resources in a non-deterministic order. Without a documented lifecycle contract, resources could:

- Call `DCE.On` before EventBus is ready
- Call `DCE:GetService` before dependent services register
- Access configuration before it's loaded
- Leave stale references after resource restart

This creates race conditions and hard-to-debug initialization failures.

---

## Decision

### Resource Load Order

DCE defines a strict dependency chain in `fxmanifest.lua`:

```
dce-core (no dependencies)
    ↓
dce-world (depends on dce-core)
    ↓
dce-ai (depends on dce-core)
    ↓
dce-events (depends on dce-core)
    ↓
dce-dispatch (depends on dce-core, triggers dce-events)
    ↓
dce-evidence (depends on dce-core, triggers dce-events)
    ↓
dce-admin (depends on dce-core)
```

### Initialization Sequence

Within `dce-core`, services initialize in dependency order:

1. Logger → no dependencies
2. Config → depends on Logger for logging
3. Registry → depends on Logger
4. EventBus → depends on Logger
5. Scheduler → depends on Logger
6. Profiler → depends on Logger, emits to EventBus
7. Cache → depends on Logger
8. Pool → depends on Logger
9. AlertHandler → depends on EventBus
10. PluginManager → depends on Config, Registry

### Service Lifecycle Methods

All services must implement:

```lua
function Service.Initialize()  -- Called once on resource start
function Service.Shutdown()    -- Called once on resource stop
function Service.GetMetrics()  -- Called for performance monitoring (ADR-0015)
```

### Cross-Resource Communication Pattern

Resources communicate through the DCE API, never through direct `_G.DCE` overwrite:

```lua
-- Correct: Get DCE from export
local DCEAPI = exports['dce-core']:GetDCEAPI()
DCEAPI.On("event", handler)

-- Incorrect: Overwriting global (causes race conditions)
_G.DCE = something  -- DO NOT DO THIS in non-core resources
```

### Event Handler Lifecycle

Resources must clean up subscriptions:

```lua
-- On shutdown, DCE core clears all handlers
-- Individual resources don't need to unsubscribe manually
-- BUT they should not cache handler IDs expecting them to persist
```

---

## Consequences

### Positive

- Deterministic startup behavior
- No race conditions in initialization
- Clear dependency model for new developers
- Admin UI can observe startup order

### Negative

- More boilerplate in resource startup
- Must remember to implement lifecycle methods

### Mitigations

- Template code in `dce-core/init.lua`
- Generated code snippets for new resources
- Linting rules to enforce lifecycle methods