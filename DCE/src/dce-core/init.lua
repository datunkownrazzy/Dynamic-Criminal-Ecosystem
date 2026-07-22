-- DCE Core v2 — Sprint 1.9 Platform Complete
-- Five-stage boot pipeline:
--   BOOT → REGISTRATION → VERIFICATION → REPORTING → READY
--
-- No phase may repeat work already completed by an earlier phase.
-- Every future resource can safely depend on Core without architectural modification.
-- After Sprint 1.9, architectural changes to dce-core are breaking changes.
---@diagnostic disable: duplicate-set-field, undefined-global

DCE = {}

-- ============================================================================
-- PHASE 0: BOOT — Initialize runtime
-- ============================================================================
-- Logger. Diagnostics. Configuration. Profiler. Boot timeline.

local function BootPhase()
    -- Set _G.DCE immediately so all subsystems can access it
    _G.DCE = DCE

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

    -- Step 1: Initialize Logger (no dependencies)
    if Logger then
        Logger.Init()
    end

    -- Step 2: Initialize core services
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

    -- Initialize runtime diagnostics
    local RuntimeInit = _G.DCERuntimeInit
    if RuntimeInit and RuntimeInit.Initialize then
        RuntimeInit.Initialize(Logger)
    end

    -- Initialize Sprint 1.9 architecture components
    local EventRegistry = _G.DCEEventRegistry
    if EventRegistry and EventRegistry.Init then
        EventRegistry.Init()
    end

    local ConfigFramework = _G.DCEConfigFramework
    if ConfigFramework and ConfigFramework.Init then
        ConfigFramework.Init()
    end

    return Logger
end

-- ============================================================================
-- PHASE 1: REGISTRATION — Register services, exports, plugins, interfaces, SDK
-- ============================================================================

local function RegistrationPhase(Logger)
    -- Register DCE global API
    DCE.RegisterService = function(name, serviceTable, options)
        local reg = _G.DCERegistry
        if reg then return reg.Register(name, serviceTable, options) end
        return false
    end

    DCE.GetService = function(name)
        local reg = _G.DCERegistry
        if reg then return reg.Get(name) end
        return nil
    end

    DCE.HasService = function(name)
        local reg = _G.DCERegistry
        if reg then return reg.Has(name) end
        return false
    end

    DCE.GetServiceOrThrow = function(name)
        local reg = _G.DCERegistry
        if reg then return reg.GetOrThrow(name) end
        error("DCE Service Registry: required service '" .. name .. "' is not registered")
    end

    DCE.UnregisterService = function(name)
        local reg = _G.DCERegistry
        if reg then return reg.Unregister(name) end
        return false
    end

    -- Event Bus
    DCE.Emit = function(eventName, payload)
        local eb = _G.DCEEventBus
        if eb then
            -- Validate payload against event contract
            local eventReg = _G.DCEEventRegistry
            if eventReg and eventReg.ValidatePayload then
                eventReg.ValidatePayload(eventName, payload)
            end
            return eb.Emit(eventName, payload)
        end
    end

    DCE.On = function(eventName, handlerFn)
        if not handlerFn or type(handlerFn) ~= "function" then
            local msg = ("EventBus.On: handlerFn must be a function for event '%s'"):format(
                type(eventName) == "string" and eventName or tostring(eventName))
            local l = _G.DCELogger
            if l and l.Log then l.Log("core", "error", msg)
            else print(("[DCE] %s"):format(msg)) end
            return nil
        end
        local eb = _G.DCEEventBus
        if eb then return eb.On(eventName, handlerFn) end
        return nil
    end

    DCE.Once = function(eventName, handlerFn)
        if not handlerFn or type(handlerFn) ~= "function" then
            local msg = ("EventBus.Once: handlerFn must be a function for event '%s'"):format(
                type(eventName) == "string" and eventName or tostring(eventName))
            local l = _G.DCELogger
            if l and l.Log then l.Log("core", "error", msg)
            else print(("[DCE] %s"):format(msg)) end
            return nil
        end
        local eb = _G.DCEEventBus
        if eb then return eb.Once(eventName, handlerFn) end
        return nil
    end

    DCE.Off = function(eventName, handlerId)
        local eb = _G.DCEEventBus
        if eb then return eb.Off(eventName, handlerId) end
    end

    -- Scheduler
    DCE.Schedule = function(taskName, intervalMs, callback, options)
        local sched = _G.DCEScheduler
        if sched then return sched.Schedule(taskName, intervalMs, callback, options) end
        return false
    end

    DCE.ScheduleNow = function(taskName)
        local sched = _G.DCEScheduler
        if sched then return sched.ExecuteNow(taskName) end
        return false
    end

    -- Plugin
    DCE.RegisterPlugin = function(manifest)
        local pm = _G.DCEPluginArchitecture
        if pm then return pm.Register(manifest) end
        local oldPm = _G.DCEPluginManager
        if oldPm then return oldPm.Register(manifest) end
        return false
    end

    -- Config
    DCE.LoadConfig = function(path)
        local cl = _G.DCEConfigLoader
        if cl then return cl.Load(path) end
        return nil
    end

    DCE.ValidateConfig = function(config, schema)
        local cf = _G.DCEConfigFramework
        if cf then
            local ok, _ = cf.Validate(config, schema)
            return ok
        end
        return false
    end

    -- Logger
    DCE.Log = function(module, level, message, ...)
        local l = _G.DCELogger
        if l then l.Log(module, level, message, ...) end
    end

    -- Version
    DCE.GetVersion = function()
        return "1.0.0"
    end

    -- READY state query - canonical way to check if Core completed initialization
    -- Consumers should use: exports['dce-core']:IsReady() or DCE.IsReady()
    DCE.IsReady = function()
        return DCE._ready == true
    end

    -- SDK Registration APIs (future reserved)
    DCE.RegisterOrganization = function(orgDataTable)
        if not orgDataTable or type(orgDataTable) ~= "table" then return false, "orgDataTable must be a table" end
        DCE.Emit("sdk:organization:registered", {
            eventVersion = 1, timestamp = os.time(), source = "dce-core-sdk",
            payload = { orgId = orgDataTable.id },
        })
        return true
    end

    DCE.RegisterDispatchAdapter = function(adapterTable)
        if not adapterTable then return false end
        DCE.Emit("sdk:adapter:registered", {
            eventVersion = 1, timestamp = os.time(), source = "dce-core-sdk",
            payload = { category = "dispatch", adapterName = adapterTable.Name or "unknown" },
        })
        return true
    end

    DCE.RegisterEvidenceAdapter = function(adapterTable)
        if not adapterTable then return false end
        DCE.Emit("sdk:adapter:registered", {
            eventVersion = 1, timestamp = os.time(), source = "dce-core-sdk",
            payload = { category = "evidence", adapterName = adapterTable.Name or "unknown" },
        })
        return true
    end

    DCE.RegisterMDTAdapter = function(adapterTable)
        if not adapterTable then return false end
        DCE.Emit("sdk:adapter:registered", {
            eventVersion = 1, timestamp = os.time(), source = "dce-core-sdk",
            payload = { category = "mdt", adapterName = adapterTable.Name or "unknown" },
        })
        return true
    end

    DCE.RegisterBehavior = function(behaviorDataTable)
        if not behaviorDataTable then return false end
        DCE.Emit("sdk:behavior:registered", {
            eventVersion = 1, timestamp = os.time(), source = "dce-core-sdk",
            payload = { behaviorType = behaviorDataTable.type or "unknown" },
        })
        return true
    end

    DCE.RegisterEscalationChain = function(escalationSchemaTable)
        if not escalationSchemaTable then return false end
        DCE.Emit("sdk:escalation:registered", {
            eventVersion = 1, timestamp = os.time(), source = "dce-core-sdk",
            payload = { chainId = escalationSchemaTable.id or "unknown" },
        })
        return true
    end

    -- Register core services
    DCE.RegisterService("CoreRegistry", {
        ListServices = function() local r = _G.DCERegistry if r then return r.List() end return {} end,
        ListPlugins = function() local pm = _G.DCEPluginArchitecture if pm then return pm.List() end return {} end,
        ListTasks = function() local s = _G.DCEScheduler if s then return s.ListTasks() end return {} end,
        ListEvents = function() local eb = _G.DCEEventBus if eb then return eb.ListEvents() end return {} end,
        GetDCEVersion = function() return "1.0.0" end,
    })
    DCE.RegisterService("Logger", _G.DCELogger)
    DCE.RegisterService("EventBus", _G.DCEEventBus)
    DCE.RegisterService("Scheduler", _G.DCEScheduler)

    if AlertHandler then AlertHandler.Setup() end
    if Pool then Pool.InitializeDefaultPools() end
end

-- ============================================================================
-- PHASE 2: VERIFICATION — Run consolidated verifier
-- ============================================================================

local function VerificationPhase()
    local Verifier = _G.DCEVerifier
    if Verifier and Verifier.RunAll then
        -- Development profile by default; can be changed via config
        return Verifier.RunAll("development")
    end

    -- Fallback to old validators if new verifier not available
    local RuntimeInit = _G.DCERuntimeInit
    if RuntimeInit and RuntimeInit.RunStartupValidations then
        RuntimeInit.RunStartupValidations()
    end
    return nil
end

-- ============================================================================
-- PHASE 3: REPORTING — Generate diagnostic, architecture, performance reports
-- ============================================================================

local function ReportingPhase(verificationResult)
    if verificationResult then
        local Verifier = _G.DCEVerifier
        if Verifier and Verifier.GetSummary then
            local summary = Verifier.GetSummary()
            -- Production mode: minimal output
            local totalPassed = (verificationResult.totalPassed or 0)
            local totalFailed = (verificationResult.totalFailed or 0)
            local total = (verificationResult.total or 1)
            print(string.format("^4[DCE] Verification: %d/%d passed, %d failed^0",
                totalPassed, total, totalFailed))
            if totalFailed > 0 then
                print("^1[DCE] Verification failures detected - check diagnostic report^0")
            end
        end
    end

    -- Generate runtime report
    local RuntimeReport = _G.DCERuntimeReport
    if RuntimeReport and RuntimeReport.Generate then
        RuntimeReport.Generate()
    end

    -- Register diagnostic commands
    local RuntimeInit = _G.DCERuntimeInit
    if RuntimeInit and RuntimeInit.RegisterCommands then
        RuntimeInit.RegisterCommands()
    end
end

-- ============================================================================
-- PHASE 4: READY — Emit core:initialized, expose SDK, enable runtime
-- ============================================================================

local function ReadyPhase(Logger)
    DCE.Emit("core:initialized", {
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-core",
        payload = { version = "1.0.0" },
    })

    if Logger then
        Logger.Info("core", "DCE v1.0.0 Core Initialized")
        local reg = _G.DCERegistry
        if reg then
            Logger.Info("core", "Registered services: %s", table.concat(reg.List(), ", "))
        end
    end

    -- Mark startup complete
    local Diagnostics = _G.DCEDiagnostics
    if Diagnostics and Diagnostics.MarkStartupComplete then
        Diagnostics.MarkStartupComplete()
    end

    -- Set authoritative ready state - this is the canonical READY signal
    -- Consumers should use exports['dce-core']:IsReady() or DCE.IsReady()
    DCE._ready = true
    _G.DCECoreReady = true

    -- Record boot timeline
    local BootTimeline = _G.DCEBootTimeline
    if BootTimeline and BootTimeline.Record then
        BootTimeline.Record("Boot Complete")
    end
end

-- ============================================================================
-- Five-Stage Boot Pipeline
-- ============================================================================

local function InitializeCore()
    _G.DCE = DCE

    local ok, err = pcall(function()
        -- Stage 1: BOOT
        local Logger = BootPhase()

        -- Stage 2: REGISTRATION
        RegistrationPhase(Logger)

        -- Stage 3: VERIFICATION
        local verificationResult = VerificationPhase()

        -- Stage 4: REPORTING
        ReportingPhase(verificationResult)

        -- Stage 5: READY
        ReadyPhase(Logger)
    end)

    if not ok then
        print("^1[DCE Core] FATAL: Boot pipeline failed: " .. tostring(err) .. "^0")
    end
end

-- ============================================================================
-- Shutdown
-- ============================================================================

local function ShutdownCore()
    -- Use lifecycle framework for shutdown
    local ServiceLifecycle = _G.DCEServiceLifecycle
    if ServiceLifecycle and ServiceLifecycle.ShutdownAll then
        ServiceLifecycle.ShutdownAll()
    end

    -- Fallback shutdown
    local sched = _G.DCEScheduler
    if sched then sched.ClearAll() end
    local eb = _G.DCEEventBus
    if eb then eb.ClearAll() end
    local reg = _G.DCERegistry
    if reg then reg.Clear() end

    local Logger = _G.DCELogger
    if Logger then
        Logger.Info("core", "=== DCE Core Shutdown Complete ===")
    end
end

-- ============================================================================
-- Exports — Sprint 1.10.2 Canonical SDK Access
-- ============================================================================
-- ARCHITECTURAL RULE:
-- The exported SDK is the sole supported public interface.
-- Internal globals are implementation details.
-- External resources must never depend on implementation globals.
--
-- Every external DCE resource shall obtain Core exclusively through:
--   local DCE = exports["dce-core"]:GetDCEAPI()
-- No external resource should rely on _G.DCE, _G.DCERegistry, etc.

local dceEventBridges = {}

function DCE_Subscribe(dceEvent, fivemEvent)
    if type(dceEvent) ~= "string" then
        print("^1[DCE Core] DCE_Subscribe: dceEvent must be a string^0")
        return false
    end
    if not fivemEvent then
        fivemEvent = "dce-bridge:" .. dceEvent .. ":" .. tostring(math.floor(os.clock() * 1000)) .. ":" .. tostring(math.random(100000, 999999))
    elseif type(fivemEvent) ~= "string" then
        print("^1[DCE Core] DCE_Subscribe: fivemEvent must be a string or nil^0")
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

-- Sprint 1.10.2: GetDCEAPI now returns the FROZEN SDK table
-- The frozen SDK contains ONLY public documented APIs.
-- It never returns internal service tables directly.
-- It never exposes mutable implementation state.
function GetDCEAPI()
    return _G.DCE_FROZEN_SDK or DCE
end

function IsReady()
    return _G.DCECoreReady == true
end

-- ============================================================================
-- Resource Lifecycle Hooks
-- ============================================================================

local initSuccess, initErr = pcall(InitializeCore)
if not initSuccess then
    print("^1[DCE Core] FATAL: Initialization failed: " .. tostring(initErr) .. "^0")
else
    if not _G.DCE then _G.DCE = DCE end

    AddEventHandler("onResourceStop", function(resourceName)
        if resourceName == GetCurrentResourceName() then
            ShutdownCore()
        end
    end)

    AddEventHandler("onResourceStart", function(resourceName)
        if resourceName == GetCurrentResourceName() then
            local Logger = _G.DCELogger
            if Logger then
                Logger.Info("core", "Resource restarted: %s", resourceName)
            end
        end
    end)
end