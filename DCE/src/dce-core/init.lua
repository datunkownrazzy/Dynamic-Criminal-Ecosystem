-- DCE Core - Resource Entry Point
-- Initializes Service Registry, Event Bus, Scheduler, Logger, Config Loader, and Plugin Manager.
-- Registers the DCE global table that all other resources use.
-- Files are loaded in dependency order via fxmanifest.lua, so globals are available.

-- ============================================================================
-- Global DCE Table
-- ============================================================================
-- This is the single entry point all DCE resources use.
-- It exposes: RegisterService, GetService, HasService, GetServiceOrThrow, UnregisterService,
--             Emit, On, Once, Off, Schedule, Log, etc.

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

    -- Step 4: Register core services
    DCE:RegisterService("CoreRegistry", {
        ListServices = function() return Registry.List() end,
        ListPlugins = function() return PluginManager.List() end,
        ListTasks = function() return Scheduler.ListTasks() end,
        ListEvents = function() return EventBus.ListEvents() end,
        GetDCEVersion = function() return "1.0.0" end,
    })

    -- Step 5: Emit core ready event
    DCE:Emit("core:initialized", {
        eventName = "core:initialized",
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

-- Export DCE table globally so other resources can use it without require()
_G.DCE = DCE