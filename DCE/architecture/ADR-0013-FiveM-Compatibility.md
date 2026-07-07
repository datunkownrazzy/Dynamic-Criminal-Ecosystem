# ADR-0013: FiveM Compatibility Strategy

**Status:** Accepted
**Date:** 2026-07-07
**Author:** Architecture
**Dependencies:** DCE-0001, ADR-0020 (Export Marshalling)

---

## Problem

FiveM has several constraints that affect DCE architecture:

1. **Resource isolation** - Each resource runs in its own Lua VM
2. **Export marshalling** - Functions passed across resources become proxy tables
3. **No true sandboxing** - Plugins cannot be truly isolated
4. **Synchronous by default** - All code runs on main thread
5. **Limited error handling** - Stack traces truncated across resource boundaries

Without explicit handling, these constraints would:

- Prevent DCE events from crossing resource boundaries
- Cause plugins to accidentally break core functionality
- Create performance bottlenecks in the main thread

---

## Decision

### Resource Isolation Handling

DCE uses the single-global-DCE pattern:

```lua
-- dce-core sets the canonical DCE table
_G.DCE = DCE  -- After all methods are set up

-- Other resources get DCE via export
local DCEAPI = exports['dce-core']:GetDCEAPI()
```

This ensures only one DCE instance exists, but creates marshalling issues for functions.

### FiveM Export Bridge

For cross-resource event subscriptions, DCE implements `DCE_Subscribe` (ADR-0020):

```lua
--- Register a FiveM event as handler for a DCE event
function DCE_Subscribe(dceEvent, fivemEvent)
    -- Handler registered inside dce-core VM
    -- FiveM event triggered in subscriber VM
end
```

### Plugin Safety

Plugins use a restricted SDK surface:

```lua
-- Plugins can only use documented SDK functions
exports.dce:RegisterOrganization(data)
exports.dce:RegisterDispatchAdapter(adapter)
exports.dce:RegisterEvidenceAdapter(adapter)

-- Plugins CANNOT access core internals
exports.dce:GetService("InternalService")  -- NOT EXPOSED
exports.dce:On("internal:event", fn)      -- May be restricted
```

### Main Thread Discipline

All DCE services must be designed for single-threaded execution:

- No blocking operations in event handlers
- Scheduler handles delayed/background work
- Heavy operations split across ticks

### Error Isolation

EventBus catches all handler errors:

```lua
local success, err = pcall(handlerFn, payload)
if not success then
    DCE.Emit("eventbus:handler:error", { error = err })
    -- Other handlers still execute
end
```

---

## Consequences

### Positive

- Works within FiveM constraints
- Plugins cannot accidentally break core
- Events reliably cross resource boundaries
- Performance remains predictable

### Negative

- Cannot use async/await patterns
- Function closures cannot cross resource boundary
- True plugin sandboxing impossible

### Mitigations

- DCE_Subscribe bridge for events (ADR-0020)
- Clear SDK documentation
- Runtime warnings for plugin misbehavior
- Performance throttling per ADR-0015