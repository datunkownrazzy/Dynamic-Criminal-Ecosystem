# ADR-0020: Cross-Resource Function Marshalling Fix

## Status
Accepted

## Context
When `exports['dce-core']:GetDCEAPI()` returns the DCE table, FiveM creates a **proxy table** in the calling resource's VM. Function members of the returned table (like `DCE.On`) become proxy tables with `__call` metamethods. When called, the proxy marshals arguments to dce-core — but **function arguments are also wrapped into proxy tables**, so the receiving function sees `type(handlerFn) == "table"` instead of `"function"`.

## Decision
Replace cross-resource `DCE.On(event, callback)` calls with a **FiveM event bridge pattern**:

1. Each non-core resource registers a local `AddEventHandler` for a unique event name
2. dce-core provides a `DCE_Subscribe(dceEvent, fivemEvent)` export
3. dce-core stores the bridge and fires `TriggerEvent(fivemEvent, payload)` when the DCE event is emitted

No function references cross resource boundaries. Callbacks remain real functions in their owning VM.

## Consequences
- `DCE.On()` inside dce-core continues to work unchanged
- `DCE.On()` is removed from the exported API (no longer available cross-resource)
- Each non-core resource must subscribe via the event bridge
- `_G.DCE = DCEAPI` can be removed from non-core resources (they use exports directly)

## Migration Guide

### Before (Broken)
```lua
-- In dce-evidence/init.lua or other non-core resources
if DCE and DCE.On then
    DCE.On("some:event", function(payload)
        -- This callback becomes a proxy table when marshalled
        -- DCE.EventBus will see type(handlerFn) == "table", not "function"
    end)
end
```

### After (Correct)
```lua
-- Step 1: Register local FiveM event handler (stays real function in this VM)
AddEventHandler("dce-evidence:on:some:event", function(payload)
    -- Handle event
end)

-- Step 2: Bridge DCE event to FiveM event via export
if exports and exports['dce-core'] and exports['dce-core'].DCE_Subscribe then
    local bridgeEvent = exports['dce-core']:DCE_Subscribe("some:event", "dce-evidence:on:some:event")
end
```

## Implementation Log

| Date | Resource | Event | Status |
|------|----------|-------|--------|
| 2024-07-07 | dce-evidence | scenario:completed | Fixed - migrated to bridge pattern |
| 2024-07-07 | dce-admin | admin:action:executed | Already using bridge pattern |
