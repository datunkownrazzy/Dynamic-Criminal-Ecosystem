# DCE Public SDK — Sprint 1.10.2 Canonicalization

**Version:** 1.0.0
**Status:** FROZEN
**Date:** Sprint 1.10.2

After Sprint 1.9, no public API may be added without an ADR.
Architectural changes to dce-core are breaking changes.

---

## Platform Access

### Canonical Entry Point (ONLY supported method)

> **`exports['dce-core']:GetDCEAPI()`** is the **only** supported SDK entry point for external resources.
>
> `_G.DCE` is **NOT** part of the public platform contract.
> No production resource may depend on `_G.DCE`.
> The global interface is considered internal and may change without notice.
>
> **Sprint 1.10.2:** `GetDCEAPI()` now returns a **frozen SDK table** that:
> - Contains ONLY public documented APIs
> - Never returns internal service tables directly
> - Never exposes mutable implementation state
> - Is stable across future versions
> - Is the SOLE supported public interface for all external resources

### exports['dce-core']:GetDCEAPI()

| Property | Value |
|----------|-------|
| Purpose | Retrieve the canonical DCE SDK from another resource |
| Owner | dce-core |
| Runtime | server + client |
| Returns | `table` — The **frozen** DCE API table |
| Version | 1.0.0 |
| Implementation | `sdk/sdk-wrapper.lua` |
| Note | This is the **only** reliable cross-resource access method. FiveM Lua globals are per-resource. |

### exports['dce-core']:IsReady()

| Property | Value |
|----------|-------|
| Purpose | Check if DCE Core has completed the five-stage boot pipeline |
| Owner | dce-core |
| Runtime | server + client |
| Returns | `boolean` — true if Core has reached READY state |
| Version | 1.0.0 |
| Lifecycle | Available immediately (returns false until READY) |

### exports['dce-core']:DCE_Subscribe(dceEvent, fivemEvent)

| Property | Value |
|----------|-------|
| Purpose | Bridge a DCE event to a FiveM event |
| Owner | dce-core |
| Runtime | server + client |
| Parameters | `dceEvent: string`, `fivemEvent: string|nil` |
| Returns | `string|false` |
| Version | 1.0.0 |

---

## Service Registry API

### DCE.GetService(name)

| Property | Value |
|----------|-------|
| Purpose | Retrieve a registered service by name |
| Owner | dce-core |
| Parameters | `name: string` — Service name |
| Returns | `table|nil` — Service instance or nil if not found |
| Lifecycle | Available after REGISTRATION phase |
| Thread Safety | Safe — registry is read-only after registration |
| Version | 1.0.0 |

### DCE.RegisterService(name, serviceTable, options)

| Property | Value |
|----------|-------|
| Purpose | Register a new service with the registry |
| Owner | dce-core |
| Parameters | `name: string`, `serviceTable: table`, `options?: table` |
| Returns | `boolean` |
| Lifecycle | Available during BOOT/REGISTRATION phases |
| Thread Safety | Safe during boot; not thread-safe during runtime |
| Version | 1.0.0 |

### DCE.HasService(name)

| Property | Value |
|----------|-------|
| Purpose | Check if a service is registered |
| Owner | dce-core |
| Parameters | `name: string` |
| Returns | `boolean` |
| Lifecycle | Available after REGISTRATION phase |
| Version | 1.0.0 |

### DCE.GetServiceOrThrow(name)

| Property | Value |
|----------|-------|
| Purpose | Retrieve a service or throw if not found |
| Owner | dce-core |
| Parameters | `name: string` |
| Returns | `table` |
| Throws | Error if service not registered |
| Lifecycle | Available after REGISTRATION phase |
| Version | 1.0.0 |

### DCE.UnregisterService(name)

| Property | Value |
|----------|-------|
| Purpose | Unregister a service (internal use) |
| Owner | dce-core |
| Parameters | `name: string` |
| Returns | `boolean` |
| Classification | INTERNAL (marked internal=true in verifier) |
| Version | 1.0.0 |

---

## Event Bus API

### DCE.On(eventName, handlerFn)

| Property | Value |
|----------|-------|
| Purpose | Subscribe to a DCE event |
| Owner | dce-core |
| Parameters | `eventName: string`, `handlerFn: function(payload)` |
| Returns | `string|nil` — Handler ID or nil on failure |
| Lifecycle | Available after REGISTRATION phase |
| Thread Safety | Safe — EventBus is thread-safe |
| Version | 1.0.0 |

### DCE.Once(eventName, handlerFn)

| Property | Value |
|----------|-------|
| Purpose | Subscribe to a single event emission |
| Owner | dce-core |
| Parameters | `eventName: string`, `handlerFn: function(payload)` |
| Returns | `string|nil` |
| Lifecycle | Available after REGISTRATION phase |
| Version | 1.0.0 |

### DCE.Off(eventName, handlerId)

| Property | Value |
|----------|-------|
| Purpose | Unsubscribe from an event |
| Owner | dce-core |
| Parameters | `eventName: string`, `handlerId: string` |
| Returns | `nil` |
| Lifecycle | Available after REGISTRATION phase |
| Version | 1.0.0 |

### DCE.Emit(eventName, payload)

| Property | Value |
|----------|-------|
| Purpose | Emit an event to all subscribers |
| Owner | dce-core |
| Parameters | `eventName: string`, `payload: table` |
| Returns | `nil` |
| Payload Validation | Validated against EventRegistry contract if defined |
| Lifecycle | Available after REGISTRATION phase |
| Version | 1.0.0 |

---

## Scheduler API

### DCE.Schedule(taskName, intervalMs, callback, options)

| Property | Value |
|----------|-------|
| Purpose | Schedule a recurring task |
| Owner | dce-core |
| Parameters | `taskName: string`, `intervalMs: number`, `callback: function`, `options?: table` |
| Returns | `boolean` |
| Lifecycle | Available after REGISTRATION phase |
| Version | 1.0.0 |

### DCE.ScheduleNow(taskName)

| Property | Value |
|----------|-------|
| Purpose | Execute a scheduled task immediately |
| Owner | dce-core |
| Parameters | `taskName: string` |
| Returns | `boolean` |
| Lifecycle | Available after REGISTRATION phase |
| Version | 1.0.0 |

---

## Plugin API

### DCE.RegisterPlugin(manifest)

| Property | Value |
|----------|-------|
| Purpose | Register a plugin with the plugin architecture |
| Owner | dce-core |
| Parameters | `manifest: table` — Plugin manifest (name, version, description, author required) |
| Returns | `boolean` |
| Lifecycle | Available after REGISTRATION phase |
| Version | 1.0.0 |

---

## Config API

### DCE.LoadConfig(path)

| Property | Value |
|----------|-------|
| Purpose | Load a configuration file |
| Owner | dce-core |
| Parameters | `path: string` |
| Returns | `table|nil` |
| Lifecycle | Available after REGISTRATION phase |
| Version | 1.0.0 |

### DCE.ValidateConfig(config, schema)

| Property | Value |
|----------|-------|
| Purpose | Validate a config against a schema |
| Owner | dce-core |
| Parameters | `config: table`, `schema: table` |
| Returns | `boolean` |
| Lifecycle | Available after REGISTRATION phase |
| Version | 1.0.0 |

---

## Logger API

### DCE.Log(module, level, message, ...)

| Property | Value |
|----------|-------|
| Purpose | Log a message through DCE's logger |
| Owner | dce-core |
| Parameters | `module: string`, `level: string`, `message: string`, `...: any` |
| Returns | `nil` |
| Lifecycle | Available after BOOT phase |
| Version | 1.0.0 |

### DCE.GetVersion()

| Property | Value |
|----------|-------|
| Purpose | Get the DCE Core version string |
| Owner | dce-core |
| Parameters | none |
| Returns | `string` — "1.0.0" |
| Lifecycle | Available after REGISTRATION phase |
| Version | 1.0.0 |

### DCE.IsReady()

| Property | Value |
|----------|-------|
| Purpose | Check if DCE Core has reached READY state |
| Owner | dce-core |
| Parameters | none |
| Returns | `boolean` — true if READY |
| Lifecycle | Available after REGISTRATION phase |
| Version | 1.0.0 |
| Implementation | Checks `_G.DCECoreReady` which is set in the READY phase |

---

## SDK Registration APIs (Future Reserved)

These APIs are **future reserved** for plugin consumption. They emit events but have no subscribers yet. This is intentional — they are architectural contracts.

### DCE.RegisterOrganization(orgDataTable)
### DCE.RegisterDispatchAdapter(adapterTable)
### DCE.RegisterEvidenceAdapter(adapterTable)
### DCE.RegisterMDTAdapter(adapterTable)
### DCE.RegisterBehavior(behaviorDataTable)
### DCE.RegisterEscalationChain(escalationSchemaTable)

| Property | Value |
|----------|-------|
| Classification | FUTURE_RESERVED |
| Purpose | Plugin SDK registration for future subsystems |
| Owner | dce-core |
| Version | 1.0.0 |
| Note | Do NOT fabricate subscribers for these events |

---

## Core Services (accessible via DCE:GetService())

| Service Name | Description | Registered By |
|-------------|-------------|---------------|
| CoreRegistry | Lists services, plugins, tasks, events | dce-core |
| Logger | Logger instance | dce-core |
| EventBus | EventBus instance | dce-core |
| Scheduler | Scheduler instance | dce-core |

---

## Consumer Best Practices

### Detecting Core READY
```lua
-- CANONICAL METHOD (recommended):
while not exports['dce-core']:IsReady() do
    Citizen.Wait(100)
end

-- ALTERNATIVE via SDK:
local DCE = exports['dce-core']:GetDCEAPI()
while not DCE.IsReady() do
    Citizen.Wait(100)
end
```

### Accessing the SDK (CANONICAL)
```lua
-- CANONICAL METHOD (MANDATORY for all external resources):
-- Returns a FROZEN SDK table — NEVER internal service tables
local DCE = exports['dce-core']:GetDCEAPI()
local logger = DCE:GetService("Logger")
local eventBus = DCE:GetService("EventBus")
```

### What NOT to do (FORBIDDEN)
```lua
-- FORBIDDEN: globals are per-resource, these will be nil in consumer scripts
-- _G.DCE is NOT part of the public platform contract
-- No production resource may depend on _G.DCE

-- WRONG:
local DCE = _G.DCE         -- nil in consumer scripts
local registry = _G.DCERegistry  -- nil in consumer scripts

-- WRONG (Sprint 1.10.2):
-- Do NOT modify or depend on internal implementation globals
-- _G.DCERegistry, _G.DCEEventBus, _G.DCEScheduler, etc. are INTERNAL
-- They are UNSUPPORTED and may change without notice
```

---

## Frozen APIs (Historical, Not Implemented)

The following APIs were historically listed in validators but were never architecturally designed for DCE. They are classified as HISTORICAL and should not be implemented.

| API | Replacement | Rationale |
|-----|-------------|-----------|
| GetRegistry | DCE.GetService('CoreRegistry'):ListServices() | Never existed on DCE table |
| GetLogger | DCE.GetService('Logger') | Never existed on DCE table |
| Cancel | Call:Cancel() on dispatch call objects | Domain-specific, not DCE-level |
| ListServices | DCE.GetService('CoreRegistry'):ListServices() | Always on CoreRegistry, not DCE |
| ListEvents | DCE.GetService('CoreRegistry'):ListEvents() | Always on CoreRegistry, not DCE |
| ListTasks | DCE.GetService('CoreRegistry'):ListTasks() | Always on CoreRegistry, not DCE |
| _G.DCERegistry | exports['dce-core']:GetDCEAPI():GetService('CoreRegistry') | Globals are per-resource |
| _G.DCEEventBus | exports['dce-core']:GetDCEAPI():GetService('EventBus') | Globals are per-resource |
| _G.DCEScheduler | exports['dce-core']:GetDCEAPI():GetService('Scheduler') | Globals are per-resource |
| _G.DCEPluginArchitecture | exports['dce-core']:GetDCEAPI():RegisterPlugin() | Use SDK method |
| _G.DCEConfigLoader | exports['dce-core']:GetDCEAPI():LoadConfig() | Use SDK method |
| _G.DCEVerifier | N/A | Internal only, not public SDK |
| **_G.DCE** | **exports['dce-core']:GetDCEAPI()** | **Globals are per-resource. _G.DCE is NOT part of the public platform contract** |