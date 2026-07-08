-- DCE Core - Resource Entry Point
-- Initializes Service Registry, Event Bus, Scheduler, Logger, Config Loader, Plugin Manager,
-- Profiler, Cache, and Pool services.
-- Registers the DCE global table that all other resources use.
-- Files are loaded in dependency order via fxmanifest.lua, so globals are available.
-- Defensive nil-check patterns are intentional for FiveM resource timing safety per ADR-0001

-- Global DCE Table
-- ===========================================================================
-- This is the single entry point all DCE resources use.
-- It exposes: RegisterService, GetService, HasService, GetServiceOrThrow, UnregisterService,
--             Emit, On, Once, Off, Schedule, Log, and SDK registration functions.

DCE = {}

-- ===========================================================================
-- Initialization Order
-- ===========================================================================
-- 1. Logger (no dependencies)
-- 2. Config (depends on Logger)
-- 3. Registry (depends on Logger)
-- 4. Event Bus (depends on Logger)
-- 5. Scheduler (depends on Logger)
-- 6. Profiler (depends on Logger)
-- 7. Cache (depends on Logger)
-- 8. Pool (depends on Logger)
-- 9. Plugin Manager (depends on Logger, Config)

-- NOTE: _G.DCE is set AFTER InitializeCore() completes (see below)
-- This ensures DCE.On, DCE.Emit, etc. are available before other resources access them

local function InitializeCore()
    local Logger = DCELogger
    local Registry = DCERegistry
    local EventBus = DCEEventBus
    local Scheduler = DCEScheduler
    local ConfigLoader = DCEConfigLoader
    local PluginManager = DCEPluginManager
    local Profiler = DCEProfiler
    local Cache = DCECache
    local Pool = DCEPool
    local AlertHandler = DCEAlertHandler
    local Diagnostics = DCEDiagnostics

-- Step 1: Initialize Logger
    if Logger then
        Logger.Init()
        Logger.Info("core", "=== DCE v1.0.0 Core Initializing ===")
    else
        print("^1[DCE Core] WARNING: Logger not available, using fallback logging^0")
    end

-- Step 2: Initialize core services (only if dependencies exist)
    if Registry then Registry.Init(Logger) end
    if EventBus then EventBus.Init(Logger) end
    if Scheduler then Scheduler.Init(Logger) end
    if Profiler then Profiler.Init(Logger) end
    if Cache then Cache.Init(Logger) end
    if Pool then Pool.Init(Logger) end
    if AlertHandler then AlertHandler.Init(Logger) end
    if ConfigLoader then ConfigLoader.Init(Logger) end
    if PluginManager then PluginManager.Init(Logger) end
    if Diagnostics then Diagnostics.Init(Logger) end
    
    -- Mark startup start for diagnostics
    if Diagnostics and Diagnostics.MarkStartupStart then
        Diagnostics.MarkStartupStart()
    end

-- Step 3: Register DCE global API (must be before AlertHandler.Setup)
    -- Service Registry
    DCE.RegisterService = function(name, serviceTable, options)
        if Registry then
            return Registry.Register(name, serviceTable, options)
        end
        return false
    end

    DCE.GetService = function(name)
        if Registry then
            return Registry.Get(name)
        end
        return nil
    end

    DCE.HasService = function(name)
        if Registry then
            return Registry.Has(name)
        end
        return false
    end

    DCE.GetServiceOrThrow = function(name)
        if Registry then
            return Registry.GetOrThrow(name)
        end
        error("DCE Service Registry: required service '" .. name .. "' is not registered")
    end

    DCE.UnregisterService = function(name)
        if Registry then
            return Registry.Unregister(name)
        end
        return false
    end

    -- Event Bus (must be available before AlertHandler.Setup)
    DCE.Emit = function(eventName, payload)
        if EventBus then
            -- Diagnostic trace
            if Diagnostics and Diagnostics.OnEventEmit then
                Diagnostics.OnEventEmit(eventName, "dce-core")
            end
            return EventBus.Emit(eventName, payload)
        end
    end

    DCE.On = function(eventName, handlerFn)
        -- Validation at DCE API boundary prevents invalid callbacks reaching EventBus.On
        -- Per Architecture rules: "Defensive nil-check patterns are intentional for FiveM timing safety"
        if not handlerFn or type(handlerFn) ~= "function" then
            local Logger = DCELogger
            local msg = ("EventBus.On: handlerFn must be a function for event '%s'"):format(
                type(eventName) == "string" and eventName or tostring(eventName)
            )
            if Logger and Logger.Log then
                Logger.Log("core", "error", msg)
            else
                print(("[DCE] %s"):format(msg))
            end
            return nil
        end
        
        if EventBus then
            return EventBus.On(eventName, handlerFn)
        end
        
        -- EventBus not initialized - likely race condition
        print("[DCE] WARNING: EventBus is nil for event=" .. tostring(eventName))
        return nil
    end

    DCE.Once = function(eventName, handlerFn)
        if not handlerFn or type(handlerFn) ~= "function" then
            local Logger = DCELogger
            local msg = ("EventBus.Once: handlerFn must be a function for event '%s'"):format(
                type(eventName) == "string" and eventName or tostring(eventName)
            )
            if Logger and Logger.Log then
                Logger.Log("core", "error", msg)
            else
                print(("[DCE] %s"):format(msg))
            end
            return nil
        end
        if EventBus then
            return EventBus.Once(eventName, handlerFn)
        end
        return nil
    end

    DCE.Off = function(eventName, handlerId)
        if EventBus then
            return EventBus.Off(eventName, handlerId)
        end
    end

    -- Scheduler
    DCE.Schedule = function(taskName, intervalMs, callback, options)
        if Scheduler then
            return Scheduler.Schedule(taskName, intervalMs, callback, options)
        end
        return false
    end

    DCE.ScheduleNow = function(taskName)
        if Scheduler then
            return Scheduler.ExecuteNow(taskName)
        end
        return false
    end

    -- Plugin Manager
    DCE.RegisterPlugin = function(manifest)
        if PluginManager then
            return PluginManager.Register(manifest)
        end
        return false
    end

    -- Config Loader
    DCE.LoadConfig = function(path)
        if ConfigLoader then
            return ConfigLoader.Load(path)
        end
        return nil
    end

    DCE.ValidateConfig = function(config, schema)
        if ConfigLoader then
            return ConfigLoader.Validate(config, schema)
        end
        return false
    end

    -- Logger convenience
    DCE.Log = function(module, level, message, ...)
        if Logger then
            Logger.Log(module, level, message, ...)
        end
    end

    -- Setup alert handler for performance events (now DCE.On is available)
    if AlertHandler then AlertHandler.Setup() end

    -- Initialize default object pools
    if Pool then Pool.InitializeDefaultPools() end

    -- SDK Wrapper Functions (Plugin_SDK.md)
    -- These provide a thin wrapper over the Service Registry/Event Bus for plugin authors.

    --- Register a new organization from a plugin.
    -- Emits sdk:organization:registered event for the Organizations service to handle.
    ---@param orgDataTable table Organization data following Organizations.md schema
    ---@return boolean success, string|nil errorMessage
    DCE.RegisterOrganization = function(orgDataTable)
        if not orgDataTable or type(orgDataTable) ~= "table" then
            return false, "orgDataTable must be a table"
        end
        if not orgDataTable.id then
            return false, "orgDataTable.id is required"
        end

        DCE.Emit("sdk:organization:registered", {
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-core-sdk",
            payload = {
                orgId = orgDataTable.id,
            },
        })
        return true
    end

    --- Register a dispatch adapter from a plugin.
    ---@param adapterTable table Adapter configuration
    ---@return boolean success
    DCE.RegisterDispatchAdapter = function(adapterTable)
        if not adapterTable then
            return false
        end
        DCE.Emit("sdk:adapter:registered", {
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-core-sdk",
            payload = {
                category = "dispatch",
                adapterName = adapterTable.Name or "unknown",
            },
        })
        return true
    end

    --- Register an evidence/inventory adapter from a plugin.
    ---@param adapterTable table Adapter configuration
    ---@return boolean success
    DCE.RegisterEvidenceAdapter = function(adapterTable)
        if not adapterTable then
            return false
        end
        DCE.Emit("sdk:adapter:registered", {
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-core-sdk",
            payload = {
                category = "evidence",
                adapterName = adapterTable.Name or "unknown",
            },
        })
        return true
    end

    --- Register an MDT adapter from a plugin.
    ---@param adapterTable table Adapter configuration
    ---@return boolean success
    DCE.RegisterMDTAdapter = function(adapterTable)
        if not adapterTable then
            return false
        end
        DCE.Emit("sdk:adapter:registered", {
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-core-sdk",
            payload = {
                category = "mdt",
                adapterName = adapterTable.Name or "unknown",
            },
        })
        return true
    end

    --- Register a behavior/scenario extension from a plugin.
    ---@param behaviorDataTable table Behavior definition
    ---@return boolean success
    DCE.RegisterBehavior = function(behaviorDataTable)
        if not behaviorDataTable then
            return false
        end
        DCE.Emit("sdk:behavior:registered", {
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-core-sdk",
            payload = {
                behaviorType = behaviorDataTable.type or "unknown",
            },
        })
        return true
    end

    --- Register an escalation chain from a plugin.
    ---@param escalationSchemaTable table Escalation chain definition
    ---@return boolean success
    DCE.RegisterEscalationChain = function(escalationSchemaTable)
        if not escalationSchemaTable then
            return false
        end
        DCE.Emit("sdk:escalation:registered", {
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-core-sdk",
            payload = {
                chainId = escalationSchemaTable.id or "unknown",
            },
        })
        return true
    end

    -- Step 4: Register core services
    -- Defensive patterns: return nil OR actual value for service timing safety
    DCE.RegisterService("CoreRegistry", {
        ListServices = function() if Registry then return Registry.List() end return {} end,
        ListPlugins = function() if PluginManager then return PluginManager.List() end return {} end,
        ListTasks = function() if Scheduler then return Scheduler.ListTasks() end return {} end,
        ListEvents = function() if EventBus then return EventBus.ListEvents() end return {} end,
        GetDCEVersion = function() return "1.0.0" end,
    })

    -- Step 5: Emit core ready event
    DCE.Emit("core:initialized", {
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-core",
        payload = { version = "1.0.0" },
    })

    if Logger then
        Logger.Info("core", "DCE v1.0.0 Core Initialized")
        if Registry then
            Logger.Info("core", "Registered services: %s", table.concat(Registry.List(), ", "))
        end
    end
    
    -- Print startup summary at the end
    if Diagnostics and Diagnostics.MarkStartupComplete then
        Diagnostics.MarkStartupComplete()
    end
end

-- ============================================================================
-- Shutdown
-- ============================================================================
-- Clean up all registrations and subscriptions on resource stop.
-- This is required per AGENTS.md: "Clean up all registrations and subscriptions on onResourceStop."

local function ShutdownCore()
    local Logger = DCELogger
    local Registry = DCERegistry
    local EventBus = DCEEventBus
    local Scheduler = DCEScheduler
    local PluginManager = DCEPluginManager
    local Profiler = DCEProfiler
    local Cache = DCECache
    local Pool = DCEPool
    local AlertHandler = DCEAlertHandler
    local Diagnostics = DCEDiagnostics

    if Logger then
        Logger.Info("core", "=== DCE Core Shutting Down ===")
    end
    
    -- Diagnostic shutdown trace
    if Diagnostics and Diagnostics.OnShutdown then
        Diagnostics.OnShutdown()
    end

    -- 1. Clear all scheduled tasks (this stops all running timers)
    if Scheduler then Scheduler.ClearAll() end

    -- 2. Clear all event handlers
    if EventBus then EventBus.ClearAll() end

    -- 3. Unregister all services
    if Registry then Registry.Clear() end

    -- 4. Clear plugin registrations
    if PluginManager then PluginManager.Clear() end

    -- 5. Shutdown profiler
    if Profiler then Profiler.Shutdown() end

    -- 6. Shutdown cache (clear all caches)
    if Cache then Cache.Shutdown() end

    -- 7. Shutdown pool (clear all pools)
    if Pool then Pool.Shutdown() end

    -- 8. Shutdown alert handler
    if AlertHandler then AlertHandler.Shutdown() end

    if Logger then
        Logger.Info("core", "DCE Core Shutdown Complete")
    end
end

-- ============================================================================
-- Export Function for Dependent Resources
-- ============================================================================
-- FiveM resources run in isolated environments. DCE global is set per-resource,
-- but we need to explicitly export the DCE API for other resources to use it.

-- ============================================================================
-- Export: Subscribe to a DCE event via FiveM event bridge
-- ============================================================================
-- When DCE.On is called from another resource, the callback function is
-- marshalled into a proxy table by FiveM's export system (see ADR-0020).
-- Instead, resources subscribe by providing a FiveM event name:
--   exports['dce-core']:DCE_Subscribe("dce:event", "my:event")
-- When the DCE event fires, dce-core triggers the FiveM event with payload.
-- The handler in the subscribing resource stays a real function.
-- ============================================================================

---@type table<string, table<string, true>>  -- dceEvent -> { [fivemEvent] = true }
local dceEventBridges = {}

--- Subscribe a FiveM event to a DCE event.
--- When the DCE event fires, the FiveM event is triggered with the payload.
---@param dceEvent string The DCE event name to subscribe to
---@param fivemEvent string|nil The FiveM event to trigger when the DCE event fires. If nil, a unique event name is auto-generated.
---@return string|false The FiveM event name used for the bridge, or false on failure
function DCE_Subscribe(dceEvent, fivemEvent)
    if type(dceEvent) ~= "string" then
        print("^1[DCE Core] DCE_Subscribe: dceEvent must be a string^0")
        return false
    end
    
    -- Auto-generate a unique FiveM event name if not provided
    if not fivemEvent then
        fivemEvent = "dce-bridge:" .. dceEvent .. ":" .. tostring(math.floor(os.clock() * 1000)) .. ":" .. tostring(math.random(100000, 999999))
    elseif type(fivemEvent) ~= "string" then
        print("^1[DCE Core] DCE_Subscribe: fivemEvent must be a string or nil^0")
        return false
    end
    
    -- Register a handler for the DCE event if not already done
    if not dceEventBridges[dceEvent] then
        dceEventBridges[dceEvent] = {}
        
        -- Subscribe to the DCE event (runs in dce-core's VM, no proxy issue)
        if DCE and DCE.On then
            DCE.On(dceEvent, function(payload)
                -- Forward to all bridged FiveM events
                local bridges = dceEventBridges[dceEvent]
                if bridges then
                    for fivemEventName in pairs(bridges) do
                        TriggerEvent(fivemEventName, payload)
                    end
                end
            end)
        end
    end
    
    -- Register this FiveM event as a bridge target
    dceEventBridges[dceEvent][fivemEvent] = true
    return fivemEvent
end

function GetDCEAPI()
    return DCE
end

-- ============================================================================
-- Resource Lifecycle Hooks
-- ============================================================================

-- Startup: Initialize core systems
local initSuccess, initErr = pcall(InitializeCore)
if not initSuccess then
    -- If core fails to initialize, log the error and don't proceed
    print("^1[DCE Core] FATAL: Initialization failed: " .. tostring(initErr) .. "^0")
else
    -- Export DCE globally ONLY after all methods are set up
    -- This prevents race conditions where DCE.On, DCE.Emit, etc. are nil
    _G.DCE = DCE

    -- Register shutdown handler
    AddEventHandler("onResourceStop", function(resourceName)
        if resourceName == GetCurrentResourceName() then
            ShutdownCore()
        end
    end)

    -- Register restart handler
    AddEventHandler("onResourceStart", function(resourceName)
        if resourceName == GetCurrentResourceName() then
            local Logger = DCELogger
            if Logger then
                Logger.Info("core", "Resource restarted: %s", resourceName)
            end
        end
    end)
end