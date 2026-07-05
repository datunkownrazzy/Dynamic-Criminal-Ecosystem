-- DCE Core - Resource Entry Point
-- Initializes Service Registry, Event Bus, Scheduler, Logger, Config Loader, and Plugin Manager.
-- Registers the DCE global table that all other resources use.
-- Files are loaded in dependency order via fxmanifest.lua, so globals are available.
-- Defensive nil-check patterns are intentional for FiveM resource timing safety per ADR-0001

-- Global DCE Table
-- ============================================================================
-- This is the single entry point all DCE resources use.
-- It exposes: RegisterService, GetService, HasService, GetServiceOrThrow, UnregisterService,
--             Emit, On, Once, Off, Schedule, Log, and SDK registration functions.

DCE = {}

-- ============================================================================
-- Initialization Order
-- ============================================================================
-- 1. Logger (no dependencies)
-- 2. Config (depends on Logger)
-- 3. Registry (depends on Logger)
-- 4. Event Bus (depends on Logger)
-- 5. Scheduler (depends on Logger)
-- 6. Plugin Manager (depends on Logger, Config)

-- Export DCE table globally so other resources can use it without require()
-- This MUST be before initialization so dependent resources can access it
_G.DCE = DCE

local function InitializeCore()
    local Logger = DCELogger
    local Registry = DCERegistry
    local EventBus = DCEEventBus
    local Scheduler = DCEScheduler
    local ConfigLoader = DCEConfigLoader
    local PluginManager = DCEPluginManager

    -- Step 1: Initialize Logger
    Logger.Init()
    Logger.Info("core", "=== DCE v1.0.0 Core Initializing ===")

    -- Step 2: Initialize sub-systems
    Registry.Init(Logger)
    EventBus.Init(Logger)
    Scheduler.Init(Logger)
    ConfigLoader.Init(Logger)
    PluginManager.Init(Logger)

    -- Step 3: Register DCE global API
    -- Service Registry
    DCE.RegisterService = function(name, serviceTable, options)
        return Registry.Register(name, serviceTable, options)
    end

    DCE.GetService = function(name)
        return Registry.Get(name)
    end

    DCE.HasService = function(name)
        return Registry.Has(name)
    end

    DCE.GetServiceOrThrow = function(name)
        return Registry.GetOrThrow(name)
    end

    DCE.UnregisterService = function(name)
        return Registry.Unregister(name)
    end

    -- Event Bus
    DCE.Emit = function(eventName, payload)
        EventBus.Emit(eventName, payload)
    end

    DCE.On = function(eventName, handlerFn)
        return EventBus.On(eventName, handlerFn)
    end

    DCE.Once = function(eventName, handlerFn)
        return EventBus.Once(eventName, handlerFn)
    end

    DCE.Off = function(eventName, handlerId)
        EventBus.Off(eventName, handlerId)
    end

    -- Scheduler
    DCE.Schedule = function(taskName, intervalMs, callback, options)
        return Scheduler.Schedule(taskName, intervalMs, callback, options)
    end

    DCE.ScheduleNow = function(taskName)
        return Scheduler.ExecuteNow(taskName)
    end

    -- Plugin Manager
    DCE.RegisterPlugin = function(manifest)
        return PluginManager.Register(manifest)
    end

    -- Config Loader
    DCE.LoadConfig = function(path)
        return ConfigLoader.Load(path)
    end

    DCE.ValidateConfig = function(config, schema)
        return ConfigLoader.Validate(config, schema)
    end

    -- Logger convenience
    DCE.Log = function(module, level, message, ...)
        Logger.Log(module, level, message, ...)
    end

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
        ListServices = function() return Registry.List() end,
        ListPlugins = function() return PluginManager.List() end,
        ListTasks = function() return Scheduler.ListTasks() end,
        ListEvents = function() return EventBus.ListEvents() end,
        GetDCEVersion = function() return "1.0.0" end,
    })

    -- Step 5: Emit core ready event
    DCE.Emit("core:initialized", {
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-core",
        payload = { version = "1.0.0" },
    })

    Logger.Info("core", "DCE v1.0.0 Core Initialized")
    Logger.Info("core", "Registered services: %s", table.concat(Registry.List(), ", "))
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

    Logger.Info("core", "=== DCE Core Shutting Down ===")

    -- 1. Clear all scheduled tasks (this stops all running timers)
    Scheduler.ClearAll()

    -- 2. Clear all event handlers
    EventBus.ClearAll()

    -- 3. Unregister all services
    Registry.Clear()

    -- 4. Clear plugin registrations
    PluginManager.Clear()

    Logger.Info("core", "DCE Core Shutdown Complete")
end

-- ============================================================================
-- Export Function for Dependent Resources
-- ============================================================================
-- FiveM resources run in isolated environments. DCE global is set per-resource,
-- but we need to explicitly export the DCE API for other resources to use it.

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
            Logger.Info("core", "Resource restarted: %s", resourceName)
        end
    end)
end