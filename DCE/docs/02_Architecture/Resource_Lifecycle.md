# DCE Resource Lifecycle

**Status:** Accepted
**Version:** 1.0
**Owner:** Architecture
**Applies To:** All DCE resources and modules

---

## Purpose

This document defines the startup and shutdown order for all DCE resources, the initialization sequence, and the dependency relationships that must be respected to ensure stable operation.

The Resource Lifecycle is critical for FiveM deployment, where resources start in a non-deterministic order and must gracefully handle missing dependencies.

---

## Core Startup Sequence

### Resource Load Order (deterministic)

FiveM loads resources based on `fxmanifest.lua` dependency declarations. DCE follows this order:

```
1. dce-core (no dependencies)
   ├── Config loaded via shared_scripts
   ├── Logger, Registry, EventBus, Scheduler, Profiler, Cache, Pool initialized
   ├── DCE global table exported
   └── "core:initialized" event emitted

2. dce-world (depends on dce-core)
   ├── World service registered
   ├── Simulation ticks scheduled
   └── Layer 0/1 simulations begin

3. dce-ai (depends on dce-core)
   ├── Organizations service registered
   ├── AI Director service registered
   └── Decision ticks begin

4. dce-events (depends on dce-core)
   └── Scenario engine service registered

5. dce-dispatch (depends on dce-core)
   └── Dispatch service registered

6. dce-evidence (depends on dce-core)
   └── Evidence service registered

7. dce-admin (depends on dce-core)
   └── Admin service registered
```

### Within dce-core: Initialization Order

The dce-core resource initializes its services in a specific order to satisfy dependencies:

| Order | Service | Dependencies | Purpose |
|---|---|---|---|
| 1 | Logger | None | Logging infrastructure |
| 2 | Config Loader | Logger | Configuration management |
| 3 | Service Registry | Logger | Service discovery |
| 4 | Event Bus | Logger | Cross-module communication |
| 5 | Scheduler | Logger | Timed task execution |
| 6 | Profiler | Logger | Performance monitoring |
| 7 | Cache | Logger | Data caching |
| 8 | Pool | Logger | Object pooling |
| 9 | Alert Handler | Logger | Performance alerting |
| 10 | Plugin Manager | Logger, Config | Plugin lifecycle |

This order is defined in `dce-core/fxmanifest.lua` and implemented in `dce-core/init.lua`.

---

## Resource Startup Lifecycle

Each DCE resource follows a standard lifecycle pattern:

```lua
-- 1. Wait for dependencies
local function GetDCEAPI()
    local DCEAPI = nil
    local attempts = 0
    while not DCEAPI and attempts < 50 do
        attempts = attempts + 1
        Citizen.Wait(100)
        DCEAPI = exports['dce-core']:GetDCEAPI()
    end
    return DCEAPI
end

-- 2. On resource start
local function OnResourceStart()
    local DCEAPI = GetDCEAPI()
    if not DCEAPI then
        print("^1[FATAL] Could not obtain DCE API^0")
        return
    end
    
    -- Initialize service
    MyService.Initialize()
    
    -- Register with Service Registry
    DCE.RegisterService("MyService", MyService)
    
    -- Subscribe to events
    DCE.On("service:registered:Dependency", function()
        -- React to dependency becoming available
    end)
    
    -- Schedule recurring tasks
    DCE.Schedule("service:tick", interval, function()
        MyService.Tick()
    end, { immediate = true })
end

-- 3. On resource stop
local function OnResourceStop()
    DCE.UnregisterService("MyService")
    MyService.Shutdown()
    DCE.On and DCE.On handlers are cleaned automatically (DCE clears all handlers on shutdown)
end

-- 4. Register lifecycle hooks
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnResourceStart()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnResourceStop()
    end
end)
```

---

## Service Lifecycle Contract

All DCE services must implement these lifecycle methods:

### Required Methods

```lua
--- Initialize the service (one-time setup on resource start)
function Service.Initialize()
    -- Register with Service Registry
    -- Set up subscriptions
    -- Initialize internal state
    -- Pre-populate caches/pools
end

--- Shutdown the service (cleanup on resource stop)
function Service.Shutdown()
    -- Clean up timers
    -- Clear subscriptions
    -- Release resources
    -- Persist state if needed
end

--- Get service metrics for monitoring (required for ADR-0015)
function Service.GetMetrics()
    return {
        cpuMs = 0,
        memoryBytes = 0,
        eventCount = 0,
        queueDepth = 0,
        execFrequency = 0,
    }
end
```

### Optional Lifecycle Extensions (Performance)

For services participating in the performance framework (ADR-0015):

```lua
--- Pause the service (temporarily suspended)
function Service.Pause()
    -- Stop processing (keep state)
end

--- Resume the service (from pause)
function Service.Resume()
    -- Resume processing
end

--- Sleep the service (zero-CPU idle)
function Service.Sleep()
    -- Enter low-power state
end

--- Wake the service (from sleep)
function Service.Wake()
    -- Exit low-power state
end
```

---

## Cross-Resource Communication

### Service Registry Pattern

Resources never directly reference another resource's internals. All communication uses:

```lua
-- Get a service (may be nil if not available)
local Dispatch = DCE.GetService("Dispatch")
if Dispatch then
    Dispatch.CreateCall(data)
end
```

### Event Bus Pattern

Cross-module events use the Event Bus:

```lua
-- Emit events for other modules to react to
DCE.Emit("dispatch:call:created", {
    eventName = "dispatch:call:created",
    eventVersion = 1,
    timestamp = os.time(),
    source = "dce-events",
    payload = callData,
})

-- Subscribe to events from other modules
DCE.On("scenario:completed", function(payload)
    -- Process scenario completion
end)
```

### FiveM Export Bridge (ADR-0020)

When resources need to subscribe to DCE events from outside the core VM:

```lua
-- In subscribing resource (e.g., dce-admin)
AddEventHandler("my:event:handler", function(payload)
    -- Handle the event
end)

-- Bridge to DCE event
if exports['dce-core']:DCE_Subscribe("admin:action:executed", "my:event:handler") then
    -- Subscription established
end
```

---

## Shutdown Order

Resources must shut down in reverse order of startup:

```
1. dce-admin → Admin service unregistered, commands cleaned
2. dce-evidence → Evidence service unregistered, registry cleared
3. dce-dispatch → Dispatch service unregistered, calls cleaned
4. dce-events → Scenario engine stopped
5. dce-ai → Organizations and AI Director unregistered
6. dce-world → World service unregistered, ticks stopped
7. dce-core → All services unregistered, EventBus cleared, Scheduler cleared
```

The `dce-core` shutdown triggers cleanup in all other resources via the `onResourceStop` event chain.

---

## Dependency Handling

### Missing Service Pattern

Services that may be optional must gracefully handle `nil`:

```lua
local function GetDependencyOrDefer()
    local Dep = DCE.GetService("Dependency")
    if Dep then
        return Dep
    end
    
    -- Defer until available
    DCE.On("service:registered:Dependency", function()
        -- Dependency is now available
    end)
    return nil
end
```

### Blocking Startup Pattern

When a service is required before startup can proceed:

```lua
-- Wait for specific resource
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == "dce-core" then
        OnDCEStart()
    end
end)

-- Wait for specific service
AddEventHandler("onResourceStart", function()
    local World = DCE.GetService("World")
    if World then
        OnWorldAvailable()
    else
        DCE.On("service:registered:World", OnWorldAvailable)
    end
end)
```

---

## Resource Configuration Lifecycle

Resources may modify configuration at runtime:

```lua
-- Read configuration
local Config = _G.Config or {}

-- Hot reload support
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == "config-resource" then
        -- Merge new config
        -- Validate changes
        -- Adjust behavior accordingly
    end
end)
```

Configuration hot reload is handled per-resource and must be defensive against invalid values.

---

## Performance Considerations

### Startup Performance

- All resources must initialize within 5 seconds
- Service registration is synchronous (no async during startup)
- Events are safe to emit immediately after registration

### Shutdown Performance

- All resources must shut down within 2 seconds
- No blocking operations during shutdown
- State must be persisted before cleanup

### Tick Performance

- Layer 0 ticks: Every 30 seconds (map-wide statistical)
- Layer 1 ticks: Every 5 seconds (near-player ambient)
- Layer 2/3 ticks: Event-driven or 1-second intervals (player-interactable)

---

## Debugging Lifecycle Issues

Use the developer console to inspect:

```
# Check which services are registered
dce.debug services

# Check which events have handlers
dce.debug events

# Check scheduled tasks
dce.debug tasks
```

All lifecycle events are traceable through the Event Bus and can be instrumented for debugging.