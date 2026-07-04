# DCE Lifecycle & Dependency Resolution

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** DCE-0001 (Service Registry), DCE-0002 (Event Bus)


---

## Purpose

The Service Registry (`DCE-0001`) explains *how* modules find each other. This document explains *when* — what order resources start in, how a module should behave before its dependencies exist yet, and how shutdown/restart is handled without leaving stale state behind.

FiveM does not guarantee resource start order beyond what's declared in `fxmanifest`/`server.cfg`, so DCE cannot assume `dce-dispatch` is ready before `dce-ai` just because it "usually" starts first.

---

## Startup Phases

Every DCE resource should structure its startup into distinct phases rather than doing everything in one block at file load:

1. **Declare** — define the module's own data structures, config defaults, local state. No dependency resolution yet.
2. **Register** — call `DCE:RegisterService(...)` for anything this module provides. This should happen as early as possible so other modules can depend on it.
3. **Resolve** — look up services this module depends on, via `DCE:GetService(...)`. See "Handling Missing Dependencies" below for what to do if they're not there yet.
4. **Subscribe** — register Event Bus handlers (`DCE:On(...)`).
5. **Activate** — begin actual simulation/ticking. This should be the last step, so a module never starts producing events or expecting services before it has finished its own setup.

A module resource file should make these phases visually obvious (e.g., grouped under comments or separate functions) so a contributor can tell at a glance which phase an issue belongs to.

## Handling Missing Dependencies

Because start order isn't guaranteed, a module resolving a dependency during its own `Resolve` phase may get `nil` back. Two acceptable patterns:

**Pattern A — Lazy resolution.** Don't resolve at startup at all; resolve inside the function that actually needs the service, every time. Simple, slightly less efficient, always correct.

```lua
local function CreateDispatchCall(data)
    local Dispatch = DCE:GetService("Dispatch")
    if not Dispatch then return end
    Dispatch.CreateCall(data)
end
```

**Pattern B — Reactive resolution.** Subscribe to `service:registered:<name>` and cache the reference once it appears.

```lua
DCE:Once("service:registered:Dispatch", function()
    cachedDispatch = DCE:GetService("Dispatch")
end)
```

Pattern A is preferred for services called infrequently. Pattern B is preferred for services called very frequently (e.g., every tick), where repeated `GetService` lookups would be wasteful.

**Not acceptable:** resolving once at load time, getting `nil`, and never checking again. This is the most common source of "it works if I restart resources in the right order" bugs.

## Shutdown

Every module must clean up on `onResourceStop`:

- Unregister any services it provided (`DCE:UnregisterService`), so dependents don't hold stale references.
- Unsubscribe any Event Bus handlers it registered (`DCE:Off`).
- Flush any pending persistence writes if applicable (see the future Persistence spec).

```lua
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DCE:UnregisterService("Dispatch")
    -- unsubscribe handlers, flush state, etc.
end)
```

Failing to unregister on stop is what causes "ghost service" bugs after a `restart dce-dispatch` where a stale table is still technically resolvable but no longer actively maintained.

## Restart Behavior

A `restart <resource>` should be treated as stop-then-start, not a special case. If a module's shutdown and startup phases are both implemented correctly per this document, restarting any individual DCE resource independently should be safe and should not require restarting the rest of the framework. This is worth testing explicitly for each module — "can I restart this alone without breaking anything else" is a reasonable acceptance check before merging a new service.

## No Central Boot Orchestrator (By Design)

DCE deliberately does not have a central "boot sequencer" that starts modules in a hardcoded order. This is consistent with Principle #4 — a central orchestrator that knows about every module's startup order is itself a hidden coupling point, and it would need to be updated every time a plugin added a new resource. Instead, correctness comes from every module tolerating out-of-order startup via the patterns above. This is more work per-module but keeps the framework genuinely open to plugins that core has no knowledge of.

## Relationship to the State Machine

The richer runtime lifecycle in StateMachine.md is the authoritative model for service state transitions once a module is running. This document remains the authoritative guidance for startup ordering, dependency resolution, and shutdown behavior. In practice, a module should use the startup phases here and then transition through the states defined in StateMachine.md once it becomes active.

## Open Question (flag for an ADR if resolved)

Whether a minimal "wait for these named services before activating" helper belongs in `dce-core` (e.g., `DCE:WaitForServices({"Dispatch","Evidence"}, callback)`) as sugar over Pattern B, versus leaving every module to implement its own reactive resolution. Worth revisiting once a few real modules have been built and the actual pain points are known, rather than guessing now.
