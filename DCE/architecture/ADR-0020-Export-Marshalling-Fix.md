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