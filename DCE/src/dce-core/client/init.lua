-- DCE Core - Client Entry Point
-- Initializes DCE API services (Logger, Registry, EventBus, Scheduler) client-side.
-- This is REQUIRED for client-side exports['dce-core']:GetDCEAPI() to work.
-- Without this file, all client-side calls to dce-core exports fail with "No such export".
-- Root cause of Sprint 1.5 DEFECT-001

-- NOTE: The "duplicate-set-field" diagnostics are false positives from LuaLS.
-- This file (client/init.lua) and init.lua (server) run in completely separate
-- FiveM runtimes. They never execute in the same process.
-- The DCE table here is the client-side singleton; server/init.lua has its own.
---@diagnostic disable: duplicate-set-field

-- Global DCE Table (client-side singleton)
-- Note: shared/globals.lua sets DCE = DCE or {} in shared_scripts, but init.lua
-- on the server populates it. On the client, we need our own initialization.

-- ============================================================================
-- Client-side Core Service References
-- ============================================================================
-- All core modules set _G globals at module load time via fxmanifest client_scripts.
-- We reference those globals here to build the DCE API.

local function InitializeCore()
    local Logger = DCELogger
    local Registry = DCERegistry
    local EventBus = DCEEventBus
    local Scheduler = DCEScheduler
    local Profiler = DCEProfiler
    local Cache = DCECache
    local Pool = DCEPool
    local AlertHandler = DCEAlertHandler
    local Diagnostics = DCEDiagnostics

    -- Step 1: Initialize Logger
    if Logger then
        Logger.Init()
        Logger.Info("core", "=== DCE v1.0.0 Client Core Initializing ===")
    else
        print("^1[DCE Core Client] WARNING: Logger not available, using fallback logging^0")
    end

    -- Step 2: Initialize core services
    if Registry then Registry.Init(Logger) end
    if EventBus then EventBus.Init(Logger) end
    if Scheduler then Scheduler.Init(Logger) end
    if Profiler then Profiler.Init(Logger) end
    if Cache then Cache.Init(Logger) end
    if Pool then Pool.Init(Logger) end
    if AlertHandler then AlertHandler.Init(Logger) end
    if Diagnostics then Diagnostics.Init(Logger) end

    -- Sprint 1.8: Initialize Runtime Diagnostic Framework (client-side)
    -- Matches server-side init.lua:82-97 for runtime symmetry.
    -- NOTE: BootTimeline.Init() is called inside RuntimeInit.Initialize(),
    -- so BootTimeline.Record() calls must come AFTER this point.
    local RuntimeInit = _G.DCERuntimeInit
    if RuntimeInit and RuntimeInit.Initialize then
        RuntimeInit.Initialize(Logger)
    end

    -- Now BootTimeline is initialized, so Record() calls will work
    local BootTimeline = _G.DCEBootTimeline
    if BootTimeline and BootTimeline.Record then
        BootTimeline.Record("Core Loading", "Runtime diagnostics initialized (client)")
    end

    -- Run framework self-validation (Phase 7)
    local SelfValidation = _G.DCESelfValidation
    if SelfValidation and SelfValidation.RunAll then
        SelfValidation.RunAll()
    end

    -- Mark startup start for diagnostics
    if Diagnostics and Diagnostics.MarkStartupStart then
        Diagnostics.MarkStartupStart()
    end

    -- Step 3: Register DCE global API (client-side)
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

    -- Event Bus
    DCE.Emit = function(eventName, payload)
        if EventBus then
            if Diagnostics and Diagnostics.OnEventEmit then
                Diagnostics.OnEventEmit(eventName, "dce-core-client")
            end
            return EventBus.Emit(eventName, payload)
        end
    end

    DCE.On = function(eventName, handlerFn)
        if not handlerFn or type(handlerFn) ~= "function" then
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
        print("[DCE] WARNING: EventBus is nil for event=" .. tostring(eventName))
        return nil
    end

    DCE.Once = function(eventName, handlerFn)
        if not handlerFn or type(handlerFn) ~= "function" then
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

    -- Logger convenience
    DCE.Log = function(module, level, message, ...)
        if Logger then
            Logger.Log(module, level, message, ...)
        end
    end

    -- Version
    DCE.GetVersion = function()
        return "1.0.0"
    end

    -- READY state query (client-side)
    DCE.IsReady = function()
        return DCE._ready == true
    end

    -- Register core services
    DCE.RegisterService("CoreRegistry", {
        ListServices = function() if Registry then return Registry.List() end return {} end,
        ListPlugins = function() return {} end,
        ListTasks = function() if Scheduler then return Scheduler.ListTasks() end return {} end,
        ListEvents = function() if EventBus then return EventBus.ListEvents() end return {} end,
        GetDCEVersion = function() return "1.0.0" end,
    })

    -- Register Logger service (so DCE.GetService("Logger") works client-side)
    DCE.RegisterService("Logger", Logger or DCELogger)

    -- Register EventBus service (so DCE.GetService("EventBus") works client-side)
    DCE.RegisterService("EventBus", EventBus or DCEEventBus)

    -- Register Scheduler service
    DCE.RegisterService("Scheduler", Scheduler or DCEScheduler)

    -- Initialize default object pools
    if Pool then Pool.InitializeDefaultPools() end

    -- Setup alert handler for performance events
    if AlertHandler then AlertHandler.Setup() end

    -- Mark ready
    DCE._ready = true
    _G.DCECoreReady = true

    -- Emit core ready event
    DCE.Emit("core:initialized", {
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-core-client",
        payload = { version = "1.0.0" },
    })

    if Logger then
        Logger.Info("core", "DCE v1.0.0 Client Core Initialized")
        if Registry then
            Logger.Info("core", "Registered services: %s", table.concat(Registry.List(), ", "))
        end
    end

    if Diagnostics and Diagnostics.MarkStartupComplete then
        Diagnostics.MarkStartupComplete()
    end
end

-- ============================================================================
-- Shutdown
-- ============================================================================
local function ShutdownCore()
    local Logger = DCELogger
    local Registry = DCERegistry
    local EventBus = DCEEventBus
    local Scheduler = DCEScheduler
    local Profiler = DCEProfiler
    local Cache = DCECache
    local Pool = DCEPool
    local AlertHandler = DCEAlertHandler
    local Diagnostics = DCEDiagnostics

    if Logger then
        Logger.Info("core", "=== DCE Client Core Shutting Down ===")
    end

    if Diagnostics and Diagnostics.OnShutdown then
        Diagnostics.OnShutdown()
    end

    if Scheduler then Scheduler.ClearAll() end
    if EventBus then EventBus.ClearAll() end
    if Registry then Registry.Clear() end
    if Profiler then Profiler.Shutdown() end
    if Cache then Cache.Shutdown() end
    if Pool then Pool.Shutdown() end
    if AlertHandler then AlertHandler.Shutdown() end

    if Logger then
        Logger.Info("core", "DCE Client Core Shutdown Complete")
    end
end

-- ============================================================================
-- Export: GetDCEAPI
-- ============================================================================
-- This export is REQUIRED for client-side scripts to access the DCE API.
-- Without this, exports['dce-core']:GetDCEAPI() throws "No such export".

function GetDCEAPI()
    return DCE
end

-- ============================================================================
-- Export: IsReady
-- ============================================================================
-- This export allows consumers to check if Core has finished initializing.
-- Consumers should use: exports['dce-core']:IsReady() which returns boolean.

function IsReady()
    return DCE._ready == true
end

-- ============================================================================
-- Export: DCE_Subscribe (FiveM event bridge)
-- ============================================================================
---@type table<string, table<string, true>>
local dceEventBridges = {}

function DCE_Subscribe(dceEvent, fivemEvent)
    if type(dceEvent) ~= "string" then
        print("^1[DCE Core Client] DCE_Subscribe: dceEvent must be a string^0")
        return false
    end

    if not fivemEvent then
        fivemEvent = "dce-bridge:" .. dceEvent .. ":" .. tostring(math.floor(os.clock() * 1000)) .. ":" .. tostring(math.random(100000, 999999))
    elseif type(fivemEvent) ~= "string" then
        print("^1[DCE Core Client] DCE_Subscribe: fivemEvent must be a string or nil^0")
        return false
    end

    if not dceEventBridges[dceEvent] then
        dceEventBridges[dceEvent] = {}
        if DCE and DCE.On then
            DCE.On(dceEvent, function(payload)
                local bridges = dceEventBridges[dceEvent]
                if bridges then
                    for fivemEventName in pairs(bridges) do
                        TriggerEvent(fivemEventName, payload)
                    end
                end
            end)
        end
    end

    dceEventBridges[dceEvent][fivemEvent] = true
    return fivemEvent
end

-- ============================================================================
-- Resource Lifecycle Hooks
-- ============================================================================

-- Startup: Initialize client core systems
local initSuccess, initErr = pcall(InitializeCore)
if not initSuccess then
    print("^1[DCE Core Client] FATAL: Initialization failed: " .. tostring(initErr) .. "^0")
else
    -- Export DCE globally
    _G.DCE = DCE

    -- Register shutdown handler
    AddEventHandler("onResourceStop", function(resourceName)
        if resourceName == GetCurrentResourceName() then
            ShutdownCore()
        end
    end)

    AddEventHandler("onResourceStart", function(resourceName)
        if resourceName == GetCurrentResourceName() then
            local Logger = DCELogger
            if Logger then
                Logger.Info("core", "Client resource restarted: %s", resourceName)
            end
        end
    end)
end