# DCE Type System

**Status:** Accepted
**Version:** 1.0
**Owner:** Architecture
**Dependencies:** DCE-0001 (Service Registry), DCE-0002 (Event Bus)

---

## Purpose

The DCE Type System provides Lua type declarations for IDE integration and static analysis. It enables developers to get accurate autocomplete and type checking when working with DCE services, events, and data structures.

This document explains how the type system is organized and how to use it effectively.

---

## Type System Architecture

### Entry Point

The type system is loaded through `types/index.lua`:

```lua
require "types"  -- Loads all type declarations
```

### Organization

Types are organized into categories:

```
types/
├── index.lua                    -- Entry point, loads all types
├── runtime/                     -- FiveM/Citizen runtime types
│   ├── citizen.lua
│   └── fivem.lua
├── framework/                   -- Core framework types
│   ├── core.lua                 -- DCE global table
│   ├── core-services.lua        -- Composite core service types
│   ├── alert-handler.lua
│   ├── profiler.lua
│   └── sdk.lua
├── services/                    -- Service interface types
│   ├── base.lua                 -- Base service interface
│   ├── logger.lua
│   ├── registry.lua
│   ├── eventbus.lua
│   ├── scheduler.lua
│   ├── cache.lua
│   ├── pool.lua
│   └── plugin-manager.lua
├── domains/                     -- Domain data types
│   ├── world.lua
│   ├── organizations.lua
│   ├── dispatch.lua
│   ├── evidence.lua
│   └── scenario.lua
├── models/                      -- Entity model types
│   ├── region.lua
│   ├── organization.lua
│   └── dispatch-call.lua
├── events/                      -- Event payload types
│   ├── envelope.lua             -- Base event envelope
│   ├── organization.lua
│   ├── dispatch.lua
│   ├── evidence.lua
│   ├── scenario.lua
│   ├── world.lua
│   ├── admin.lua
│   └── sdk.lua
└── adapters/                    -- Adapter interface types
    ├── dispatch.lua
    ├── evidence.lua
    ├── mdt.lua
    ├── analytics.lua
    └── scenario.lua
```

---

## Core Types

### DCEFramework (types/framework/core.lua)

The main DCE global table available in all resources:

```lua
--- @class DCEFramework
--- DCE Core API - The single entry point for all DCE interactions
---@field RegisterService fun(name: string, serviceTable: table, options?: table): boolean
---@field GetService fun(name: string): table|nil
---@field HasService fun(name: string): boolean
---@field GetServiceOrThrow fun(name: string): table
---@field UnregisterService fun(name: string): boolean
---@field Emit fun(eventName: string, payload: IEventEnvelope): nil
---@field On fun(eventName: string, handlerFn: fun(payload: IEventEnvelope)): number|nil
---@field Once fun(eventName: string, handlerFn: fun(payload: IEventEnvelope)): number|nil
---@field Off fun(eventName: string, handlerId: number): nil
---@field Schedule fun(taskName: string, intervalMs: number, callback: fun(): nil, options?: table): boolean
---@field ScheduleNow fun(taskName: string): boolean
---@field RegisterPlugin fun(manifest: IPluginManifest): boolean
---@field LoadConfig fun(path: string): table|nil
---@field ValidateConfig fun(config: table, schema: string): boolean
---@field Log fun(module: string, level: string, message: string, ...: any): nil
```

---

## Service Types

### Logger (types/services/logger.lua)

```lua
--- @class DCELogger
--- DCE Logger service type declarations
---@field Init fun(cfg: table|nil): nil
---@field Log fun(module: string, level: string, message: string, ...: any): nil
---@field Debug fun(module: string, message: string, ...: any): nil
---@field Info fun(module: string, message: string, ...: any): nil
---@field Warn fun(module: string, message: string, ...: any): nil
---@field Error fun(module: string, message: string, ...: any): nil
---@field SetLevel fun(level: string): nil
```

### EventBus (types/services/eventbus.lua)

```lua
--- @class DCEEventBus
--- Event Bus: Pub/sub mechanism for all cross-module communication
---@field Init fun(log: ILogger|nil): nil
---@field Emit fun(eventName: string, payload: table): nil
---@field On fun(eventName: string, handlerFn: function): number|nil
---@field Once fun(eventName: string, handlerFn: function): number|nil
---@field Off fun(eventName: string, handlerId: number): nil
---@field OnPriority fun(eventName: string, handlerFn: function, priority: string): number|nil
---@field ClearAll fun(): nil
---@field ClearEvent fun(eventName: string): nil
---@field ListEvents fun(): string[]
---@field HandlerCount fun(eventName: string): number
---@field EmitBatch fun(eventList: table): nil
---@field EmitDebounced fun(eventName: string, payload: table, debounceMs: number): nil
---@field EmitCoalesced fun(eventName: string, payload: table, coalesceMs: number): nil
---@field EmitDelayed fun(eventName: string, payload: table, delayMs: number): nil
---@field GetAsyncQueueDepth fun(eventName: string): number
---@field GetStats fun(): table
---@field GetMetrics fun(): IEventBusMetrics
---@field ResetMetrics fun(): nil
```

### Scheduler (types/services/scheduler.lua)

```lua
--- @class DCEScheduler
--- DCE Scheduler service type declarations
---@field Init fun(log: ILogger|nil): nil
---@field Schedule fun(taskName: string, intervalMs: number, callback: fun(): nil, options?: table): boolean
---@field ExecuteNow fun(taskName: string): boolean
---@field GetTask fun(taskName: string): table|nil
---@field ListTasks fun(): table[]
---@field Reschedule fun(taskName: string, newIntervalMs: number): boolean
---@field Pause fun(taskName: string): nil
---@field Resume fun(taskName: string): nil
---@field Unschedule fun(taskName: string): nil
---@field ClearAll fun(): nil
```

### Cache (types/services/cache.lua)

```lua
--- @class DCECache
--- DCE Cache service type declarations
---@field Init fun(log: ILogger|nil): nil
---@field Create fun(cacheName: string, options?: table): table|nil
---@field Set fun(cacheName: string, key: string, value: any): boolean
---@field Get fun(cacheName: string, key: string): any|nil
---@field Has fun(cacheName: string, key: string): boolean
---@field Remove fun(cacheName: string, key: string): nil
---@field InvalidatePattern fun(cacheName: string, pattern: string): nil
---@field Clear fun(cacheName: string): nil
---@field GetStats fun(cacheName: string): table
---@field ExpireEntries fun(cacheName?: string): nil
---@field Shutdown fun(): nil
```

### Pool (types/services/pool.lua)

```lua
--- @class DCEPool
--- DCE Object Pool service type declarations
---@field Init fun(log: ILogger|nil): nil
---@field Create fun(poolName: string, createFn: fun(): any, resetFn: fun(obj: any): nil, options?: table): table|nil
---@field Acquire fun(poolName: string): any|nil
---@field Release fun(poolName: string, obj: any): nil
---@field GetStats fun(poolName: string): table
---@field Configure fun(poolName: string, options: table): boolean
---@field Clear fun(poolName: string): nil
---@field Shutdown fun(): nil
---@field InitializeDefaultPools fun(): nil
```

---

## Adapter Types

### IDispatchAdapter (types/adapters/dispatch.lua)

```lua
--- @class IDispatchAdapter
--- Dispatch Adapter Interface: Integrates with external CAD/MDT systems
---@field Name string
---@field Priority number
---@field IsAvailable fun(self: IDispatchAdapter): boolean
---@field CreateCall fun(self: IDispatchAdapter, data: table): nil
---@field UpdateCall fun(self: IDispatchAdapter, data: table): nil
---@field ResolveCall fun(self: IDispatchAdapter, data: table): nil
---@field CancelCall fun(self: IDispatchAdapter, data: table): nil
---@field GetDiagnostics fun(self: IDispatchAdapter): table
---@field HealthCheck fun(self: IDispatchAdapter): boolean
```

### IEvidenceAdapter (types/adapters/evidence.lua)

```lua
--- @class IEvidenceAdapter
--- Evidence/Inventory Adapter Interface
---@field Name string
---@field Priority number
---@field IsAvailable fun(self: IEvidenceAdapter): boolean
---@field CreateEvidence fun(self: IEvidenceAdapter, data: table): nil
---@field TransferEvidence fun(self: IEvidenceAdapter, data: table): nil
---@field VerifyEvidence fun(self: IEvidenceAdapter, data: table): nil
---@field LinkToCase fun(self: IEvidenceAdapter, evidenceId: string, caseId: string): nil
---@field GetDiagnostics fun(self: IEvidenceAdapter): table
---@field HealthCheck fun(self: IEvidenceAdapter): boolean
```

---

## Event Types

### IEventEnvelope (types/events/envelope.lua)

All DCE events follow this envelope structure:

```lua
--- @class IEventEnvelope
--- DCE Event Envelope - All events follow this structure
---@field eventName string
---@field eventVersion number
---@field timestamp number
---@field source string
---@field correlationId? string
---@field payload table
```

---

## Model Types

### Organization (types/models/organization.lua)

```lua
--- @class IOrganization
--- DCE Organization model
---@field id string
---@field displayName string
---@field archetype string
---@field state string
---@field personality table
---@field resources table
---@field heat number
---@field money number
---@field members number
---@field leadership table
```

### DispatchCall (types/models/dispatch-call.lua)

```lua
--- @class IDispatchCall
--- DCE Dispatch Call model
---@field callId string
---@field incidentId string
---@field description string
---@field priority string
---@field status string
---@field regionId string
---@field organizationId? string
---@field scenarioId? string
---@field created timestamp
---@field updated? timestamp
```

---

## Usage in Development

### IDE Setup

For LuaLS (Lua Language Server) integration, ensure `.luarc.json` includes:

```json
{
  "runtime.version": "LuaJIT",
  "runtime.path": ["?.lua", "/?.lua"],
  "workspace.library": ["./DCE/src/types"],
  "Lua.diagnostics.globals": ["DCE", "Config", "Citizen", "exports"]
}
```

### Type Reference

When writing code, use types as reference:

```lua
---@param dispatch IDispatchAdapter
---@return boolean
local function processCall(dispatch)
    if not dispatch.IsAvailable(dispatch) then
        return false
    end
    dispatch:CreateCall({ callId = "123", description = "Test" })
    return true
end
```

---

## Type Validation

Types are for documentation and IDE assistance only. They do not enforce runtime validation. For runtime validation, see:

- Service contract validation in `ServiceContracts.md`
- Event payload validation in `EventContracts.md`
- Configuration validation in `Configuration_Philosophy.md`

---

## Extending Types

To add new types:

1. Create a new file in the appropriate category directory under `types/`
2. Add the `require` statement to `types/index.lua`
3. Use `@class` and `@field` annotations
4. Reference the type in relevant service documentation