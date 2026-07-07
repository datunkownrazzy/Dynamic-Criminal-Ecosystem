# DCE API Reference

**Status:** Draft — in progress
**Version:** 1.0
**Owner:** Architecture
**Applies To:** All DCE modules and plugins

---

## Purpose

This document provides the authoritative reference for all DCE public APIs. Every function, method, and interface is documented with its purpose, parameters, return values, and side effects.

---

## Core Framework API

### DCE Global Functions

These functions are available globally after DCE core initializes.

#### RegisterService

```lua
DCE:RegisterService(name, serviceTable, options)
```

Register a service with the DCE Service Registry.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Unique service identifier (e.g., "Dispatch", "Evidence") |
| `serviceTable` | table | Yes | Service's public interface table |
| `options` | table | No | `{ override = boolean }` to replace existing service |

**Returns:** `boolean` - success status

**Side Effects:**
- Registers service in global registry
- Emits `service:registered:<name>` event (if EventBus available)

**Errors:**
- Returns `false` if name or serviceTable is invalid
- Returns `false` if service exists and override not specified

**Example:**
```lua
DCE:RegisterService("MyService", {
    DoSomething = function(data)
        return data and "processed" or nil
    end,
}, { override = false })
```

---

#### GetService

```lua
DCE:GetService(name)
```

Resolve a service by name from the registry.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Service identifier to look up |

**Returns:** `table|nil` - service table or nil if not registered

**Side Effects:** None

**Example:**
```lua
local Dispatch = DCE:GetService("Dispatch")
if Dispatch then
    Dispatch.CreateCall({ description = "Test call" })
end
```

---

#### HasService

```lua
DCE:HasService(name)
```

Check if a service is registered.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Service identifier to check |

**Returns:** `boolean` - true if service exists

**Side Effects:** None

---

#### UnregisterService

```lua
DCE:UnregisterService(name)
```

Unregister a service from the registry.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Service identifier to unregister |

**Returns:** `boolean` - success status

**Side Effects:**
- Unregisters service
- Emits `service:unregistered:<name>` event

---

#### Emit

```lua
DCE:Emit(eventName, payload)
```

Emit an event to all subscribers.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `eventName` | string | Yes | Event identifier (e.g., "dispatch:call:created") |
| `payload` | table | Yes | Event envelope with domain data |

**Returns:** `nil`

**Side Effects:**
- Calls all registered handlers for the event
- Errors in handlers are logged but don't stop delivery

**Example:**
```lua
DCE:Emit("dispatch:call:created", {
    eventName = "dispatch:call:created",
    eventVersion = 1,
    timestamp = os.time(),
    source = "dce-events",
    correlationId = "call-001",
    payload = {
        callId = "call-001",
        description = "Drug deal reported",
        priority = "medium",
    },
})
```

---

#### On

```lua
DCE:On(eventName, handlerFn)
```

Subscribe to an event.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `eventName` | string | Yes | Event identifier to subscribe to |
| `handlerFn` | function | Yes | Function called when event is emitted |

**Returns:** `number|nil` - handler ID for unsubscription, or nil on error

**Side Effects:**
- Registers handler for future events
- Handler called synchronously when event emits

**Example:**
```lua
local handlerId = DCE:On("evidence:item:created", function(payload)
    local data = payload.payload
    print("Evidence created: " .. data.evidenceId)
end)

-- Later: DCE:Off("evidence:item:created", handlerId)
```

---

#### Once

```lua
DCE:Once(eventName, handlerFn)
```

Subscribe to an event for one-time handling.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `eventName` | string | Yes | Event identifier |
| `handlerFn` | function | Yes | One-time handler |

**Returns:** `number|nil` - handler ID

**Side Effects:** Handler auto-unsubscribes after first call

---

#### Off

```lua
DCE:Off(eventName, handlerId)
```

Unsubscribe from an event.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `eventName` | string | Yes | Event identifier |
| `handlerId` | number | Yes | Handler ID from On/Once |

**Returns:** `nil`

---

#### Schedule

```lua
DCE:Schedule(taskName, intervalMs, callback, options)
```

Schedule a recurring task.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `taskName` | string | Yes | Unique task identifier |
| `intervalMs` | number | Yes | Interval in milliseconds (min 50) |
| `callback` | function | Yes | Function to execute each tick |
| `options` | table | No | `{ immediate = boolean }` start immediately |

**Returns:** `boolean` - success status

**Side Effects:**
- Creates repeating timer
- Task added to scheduler registry

**Example:**
```lua
DCE:Schedule("world:layer0:tick", 30000, function()
    WorldService.Layer0Tick()
end, { immediate = true })
```

---

## Core Service API Reference

### Logger Service

```lua
DCELogger.Log(module, level, message, ...)
DCELogger.Debug(module, message, ...)
DCELogger.Info(module, message, ...)
DCELogger.Warn(module, message, ...)
DCELogger.Error(module, message, ...)
DCELogger.SetLevel(level)
```

**Log Levels:** `"debug"`, `"info"`, `"warn"`, `"error"`, `"off"`

---

### EventBus Service

```lua
DCEEventBus.Emit(eventName, payload)
DCEEventBus.On(eventName, handlerFn) -> handlerId
DCEEventBus.Once(eventName, handlerFn) -> handlerId
DCEEventBus.Off(eventName, handlerId)
DCEEventBus.OnPriority(eventName, handlerFn, priority) -> handlerId
DCEEventBus.ClearAll()
DCEEventBus.ClearEvent(eventName)
DCEEventBus.ListEvents() -> string[]
DCEEventBus.HandlerCount(eventName) -> number
DCEEventBus.EmitBatch(eventList)
DCEEventBus.EmitDebounced(eventName, payload, debounceMs)
DCEEventBus.EmitCoalesced(eventName, payload, coalesceMs)
DCEEventBus.EmitDelayed(eventName, payload, delayMs)
DCEEventBus.GetAsyncQueueDepth(eventName) -> number
DCEEventBus.GetMetrics() -> table
DCEEventBus.GetStats() -> table
DCEEventBus.ResetMetrics()
```

---

### Cache Service

```lua
DCECache.Create(cacheName, options) -> table|nil
DCECache.Set(cacheName, key, value) -> boolean
DCECache.Get(cacheName, key) -> any|nil
DCECache.Has(cacheName, key) -> boolean
DCECache.Remove(cacheName, key)
DCECache.InvalidatePattern(cacheName, pattern)
DCECache.Clear(cacheName)
DCECache.GetStats(cacheName) -> table
DCECache.ExpireEntries(cacheName)
DCECache.Shutdown()
```

**Options:** `{ ttl = 300, maxSize = 1000, evictionPolicy = "lru" }`

---

### Pool Service

```lua
DCEPool.Create(poolName, createFn, resetFn, options) -> table|nil
DCEPool.Acquire(poolName) -> any|nil
DCEPool.Release(poolName, obj)
DCEPool.GetStats(poolName) -> table
DCEPool.Configure(poolName, options) -> boolean
DCEPool.Clear(poolName)
DCEPool.Shutdown()
DCEPool.InitializeDefaultPools()
```

---

### Profiler Service

```lua
DCEProfiler.Init(log)
DCEProfiler.RecordStart(serviceId)
DCEProfiler.RecordEnd(serviceId)
DCEProfiler.SetBudget(serviceId, budgetMs)
DCEProfiler.EmitBudgetExceeded(serviceId, actualMs, budgetMs)
DCEProfiler.IncrementEventCount(serviceId)
DCEProfiler.SetQueueDepth(serviceId, depth)
DCEProfiler.SetExecutionFrequency(serviceId, frequency)
DCEProfiler.GetMetrics(serviceId) -> table|nil
DCEProfiler.GetAllMetrics() -> table
DCEProfiler.GetHistory(serviceId, limit) -> table[]
DCEProfiler.ListServices() -> string[]
DCEProfiler.GetStats() -> table
DCEProfiler.Reset(serviceId)
DCEProfiler.SetEnabled(enabled)
DCEProfiler.Shutdown()
```

---

## Domain Service API Reference

### Evidence Service

```lua
Evidence.CreateEvidence(data) -> table|nil
Evidence.GetEvidence(evidenceId) -> table|nil
Evidence.GetAllEvidence() -> table[]
Evidence.GetEvidenceByScenario(scenarioId) -> table[]
Evidence.GetEvidenceByOrganization(orgId) -> table[]
Evidence.TransferEvidence(evidenceId, from, to, reason) -> boolean
Evidence.GetCustodyChain(evidenceId) -> table[]
Evidence.VerifyEvidence(evidenceId) -> boolean
Evidence.LinkToCase(evidenceId, caseId) -> boolean
Evidence.SetAdapter(adapter)
Evidence.GetAdapter() -> table|nil
Evidence.Shutdown()
```

**CreateEvidence data:**
```lua
{
    type = "casing" | "dna" | "fingerprint" | "item" | "photo",
    description = string,
    source = string,
    organizationId = string?,
    scenarioId = string?,
    confidence = number?,
}
```

---

### Dispatch Service

```lua
Dispatch.CreateCall(data) -> table|nil
Dispatch.GetCallDetails(callId) -> table|nil
Dispatch.GetActiveCalls() -> table[]
Dispatch.GetAllCalls() -> table[]
Dispatch.ActivateCall(callId) -> boolean
Dispatch.UpdateCall(callId, updateText) -> boolean
Dispatch.ResolveCall(callId, disposition) -> boolean
Dispatch.IsIncidentReported(incidentId) -> boolean
Dispatch.SetAdapter(adapter)
Dispatch.Shutdown()
```

---

### World Service

```lua
World.GetRegionState(regionId) -> table|nil
World.GetAdjacentRegions(regionId) -> string[]
World.GetAllRegionIds() -> string[]
World.GetRegionLayer(regionId) -> number
World.GetTime() -> table
World.GetWeather() -> table
World.GetAllRegionStates() -> table[]
World.Shutdown()
```

---

### Organizations Service

```lua
Organizations.GetState(orgId) -> table|nil
Organizations.GetIdentity(orgId) -> table|nil
Organizations.GetLeadership(orgId) -> table|nil
Organizations.GetAllOrgIds() -> string[]
Organizations.GetOrgState(orgId) -> string|nil
Organizations.GetAllOrgStates() -> table[]
Organizations.SetOrganizationState(orgId, newState) -> boolean
Organizations.AddHeat(orgId, amount)
Organizations.AddMoney(orgId, amount)
Organizations.Shutdown()
```

---

### AI Director Service

```lua
AIDirector.Tick()
AIDirector.EvaluateOrganization(orgId)
AIDirector.GetActiveDecision(orgId) -> table|nil
AIDirector.ClearDecision(orgId)
AIDirector.Shutdown()
```

---

### Scenario Engine Service

```lua
ScenarioEngine.CreateScenario(data) -> table|nil
ScenarioEngine.Tick()
ScenarioEngine.GetScenario(scenarioId) -> table|nil
ScenarioEngine.GetActiveScenarios() -> table[]
ScenarioEngine.GetAllScenarios() -> table[]
ScenarioEngine.InterdictScenario(scenarioId) -> boolean
ScenarioEngine.Shutdown()
```

---

### Admin Service

```lua
Admin.HasPermission(source) -> boolean
Admin.GetOrganizationOverview() -> table[]
Admin.GetActiveIncidents() -> table[]
Admin.GetPerformanceMetrics() -> table
Admin.GetIntegrationHealth() -> table
Admin.ExecuteDebugCommand(source, command, args) -> table
Admin.GetAuditLog(limit) -> table[]
Admin.GetDebugHistory(limit) -> table[]
Admin.GetDashboardData() -> table
Admin.LogAction(adminId, action, target)
Admin.GetAllConfigs() -> table
Admin.UpdateConfig(resource, key, value) -> boolean, string?
Admin.GetConfig() -> table
Admin.GetServicesList() -> table[]
Admin.GetTasksList() -> table[]
Admin.Shutdown()
```

---

## Adapter API Reference

See `types/adapters/` for interface definitions:

- `IDispatchAdapter` - for CAD/MDT integrations
- `IEvidenceAdapter` - for evidence/inventory integrations
- `IMDTAdapter` - for MDT integrations
- `IAnalyticsAdapter` - for analytics integrations
- `IScenarioAdapter` - for scenario integrations

---

## SDK Functions

These functions are available for plugin authors:

```lua
DCE:RegisterOrganization(orgDataTable) -> boolean, string?
DCE:RegisterDispatchAdapter(adapterTable) -> boolean
DCE:RegisterEvidenceAdapter(adapterTable) -> boolean
DCE:RegisterMDTAdapter(adapterTable) -> boolean
DCE:RegisterBehavior(behaviorDataTable) -> boolean
DCE:RegisterEscalationChain(escalationSchemaTable) -> boolean
DCE:RegisterPlugin(pluginManifest) -> boolean
```

---

## Export Functions

dce-core exports:

```lua
exports['dce-core']:GetDCEAPI() -> table
exports['dce-core']:DCE_Subscribe(dceEvent, fivemEvent) -> string|false
```

---

## Error Handling

All DCE APIs handle errors gracefully:

- Invalid arguments return `nil` or `false` with logged warning
- Missing dependencies return `nil` from GetService
- Handler errors in EventBus are caught and logged
- Services check for nil before operations

---

## Version Compatibility

The API is versioned with the DCE core. Breaking changes require:

- Version bump in `DCE:GetDCEVersion()`
- ADR documenting the change
- Backward-compatibility layer where feasible

Current version: `"1.0.0"`