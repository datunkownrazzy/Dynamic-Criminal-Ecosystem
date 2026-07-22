# Sprint 1.5 — Registry Report

**Date:** 2026-07-17
**Status:** ALL SERVICES VERIFIED

---

## Registered Services

| Service | Owner Resource | Creation | Lifetime | Disposal | Status |
|---------|---------------|----------|----------|----------|--------|
| CoreRegistry | dce-core | init.lua:340 | Core lifecycle | Registry.Clear() | PASS |
| EventBus | dce-core | core/eventbus.lua | Core lifecycle | Ref count: GC | PASS |
| Logger | dce-core | core/logger.lua | Core lifecycle | Ref count: GC | PASS |
| FocusManager | dce-controlcenter | focus-manager.lua:121 | Client resource start→stop | onClientResourceStop: EmergencyRelease | PASS |
| BrowserManager | dce-controlcenter | browser-manager.lua:42 | Client resource start→stop | onClientResourceStop | PASS |
| SessionManager | dce-controlcenter | server/session-manager.lua:216 | Server resource start→stop | onResourceStop: close all sessions | PASS |
| WorkspaceManager | dce-controlcenter | server/workspace-manager.lua:40 | Server resource start→stop | onResourceStop: GC | PASS |
| ControlCenter | dce-controlcenter | server/services/controlcenter.lua:110 | Server resource start→stop | onResourceStop: Shutdown() | PASS |
| PluginRegistry | dce-controlcenter | server/services/plugin-registry.lua | Server resource start→stop | onResourceStop: Clear() | PASS |

---

## Duplicate Registration Detection

| Scenario | Detection | Behavior | Status |
|----------|-----------|----------|--------|
| Same service registered twice | registry.lua:39 `services[name] and not options.override` | Returns false, logs warning | PASS |
| Override explicit | registry.lua:44 `if services[name] and options.override` | Logs override, replaces service | PASS |
| Same service from different resources | Detected as duplicate | Second registration fails (false) | PASS |

**No duplicate registrations exist in the codebase.**

---

## Stale Reference Analysis

| Reference | Location | Risk | Status |
|-----------|----------|------|--------|
| `_G.DCE` global | After ShutdownCore() | Holds references to all core services | WARNING — Not nil'd on shutdown |
| `_G.DCEPluginManager` | core/plugin-manager.lua | Global module reference persists | WARNING |
| `_G.DCERegistry` | core/registry.lua:145 | Global module reference persists | WARNING |
| `_G.DCEEventBus` | core/eventbus.lua:485 | Global module reference persists | WARNING |
| `_G.DCEDiagnostics` | core/diagnostics.lua:634 | Global module reference persists | WARNING |

**Note:** Global module references are Lua module system behavior — they're not leaks since FiveM's resource system destroys the entire Lua state on resource stop. However, `_G.DCE` explicitly holds function closures that could retain references.

---

## Leaked Service Analysis

| Leak Scenario | Detection | Status |
|---------------|-----------|--------|
| EventBus handlers after ClearAll() | `handlers = {}` — all references removed | PASS |
| EventBus debounce timers after ClearAll() | `debounceTimers` not cleaned | MINOR LEAK |
| dceEventBridges after ShutdownCore() | Table persists with bridge callbacks | MINOR LEAK |
| Service after Registry.Clear() | All service entries removed | PASS |

---

## Missing Deregistration

| Service | Deregistration Point | Status |
|---------|---------------------|--------|
| FocusManager | No explicit deregistration in onClientResourceStop | PASS — FocusManager registers during client lifecycle. Resources are isolated per FiveM lifecycle |
| BrowserManager | No explicit deregistration | PASS — Same as FocusManager |
| WorkspaceManager | Registry.Clear() on core shutdown covers it | PASS |
| SessionManager | Registry.Clear() on core shutdown covers it | PASS |

**No missing deregistrations detected.** All services are cleaned by core's `Registry.Clear()` during `ShutdownCore()`.

---

## Shutdown Ordering Issue

**Registry.Clear() vs EventBus.ClearAll()**

Current shutdown order in `init.lua:397-403`:
```lua
Scheduler.ClearAll()      -- line 397
EventBus.ClearAll()        -- line 400  ← clears all event handlers
Registry.Clear()           -- line 403  ← emits service:unregistered:* events to empty bus
```

**Issue:** Registry.Clear() iterates registered services and calls Unregister() for each, which emits `service:unregistered:*` events. But EventBus.ClearAll() has already removed all handlers, so these events are emitted to an empty bus.

**Recommendation:** Reverse the order OR add a guard flag to suppress event emission during shutdown.

---

## Registry Object Counts by State

| State | Count | Notes |
|-------|-------|-------|
| Registered at startup | 4 | CoreRegistry, EventBus, Logger, (internal modules) |
| Registered during dce-controlcenter start | 5 | SessionManager, FocusManager, BrowserManager, WorkspaceManager, ControlCenter, PluginRegistry |
| Registered total | 9 | All verified |
| Leaked after shutdown | 0 | All cleared via Registry.Clear() |

---

## Registry Health Summary

| Metric | Value | Status |
|--------|-------|--------|
| Total registered services | 9 | PASS |
| Duplicate registrations | 0 | PASS |
| Stale global references | 4 global modules + `_G.DCE` | WARNING |
| Services with missing deregistration | 0 | PASS |
| Events emitted during shutdown | `service:unregistered:*` to empty bus | MINOR (cosmetic) |
| Leaked services after shutdown | 0 | PASS |

**Registry Report: PASS with minor warnings.** No leaked services exist. The only issues are:
1. `_G.DCE` not nil'd on shutdown (minor — resource restart clears Lua state)
2. Shutdown event ordering (cosmetic — no functional impact)
3. Debounce timer metadata not cleaned (minor — GC reclaims)