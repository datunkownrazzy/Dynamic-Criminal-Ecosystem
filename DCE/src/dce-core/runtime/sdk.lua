-- DCE SDK Builder — Sprint 1.11.4
--
-- Builds the single canonical immutable SDK.
-- The SDK is frozen after creation.
-- No consumer may ever receive nil, {}, partial, or temporary SDK.
-- There is only one SDK.
--
-- CRITICAL FIX: RuntimeState methods require a state instance, not the module table.
-- The state instance is passed as the first argument to RuntimeState:IsReady(state).
---@diagnostic disable: undefined-global

local SDKBuilder = {}

function SDKBuilder:Build(runtimeState, registry, eventBus, scheduler, pluginManager, configManager, logger)
    local sdk = {}

    -- ============================================================================
    -- Registry API
    -- ============================================================================

    function sdk:RegisterService(name, serviceTable, options)
        return registry:Register(name, serviceTable, options)
    end

    function sdk:GetService(name)
        return registry:Get(name)
    end

    function sdk:HasService(name)
        return registry:Has(name)
    end

    function sdk:UnregisterService(name)
        return registry:Unregister(name)
    end

    function sdk:ListServices()
        return registry:List()
    end

    -- ============================================================================
    -- Event Bus API
    -- ============================================================================

    function sdk:On(eventName, handlerFn)
        return eventBus:On(eventName, handlerFn)
    end

    function sdk:Once(eventName, handlerFn)
        return eventBus:Once(eventName, handlerFn)
    end

    function sdk:Off(eventName, handlerId)
        return eventBus:Off(eventName, handlerId)
    end

    function sdk:Emit(eventName, payload)
        return eventBus:Emit(eventName, payload)
    end

    -- ============================================================================
    -- Scheduler API
    -- ============================================================================

    function sdk:Schedule(taskName, intervalMs, callback, options)
        if not scheduler then
            if logger then logger:LogWarn("sdk", "Schedule: Scheduler unavailable on this VM") end
            return false
        end
        return scheduler:Schedule(taskName, intervalMs, callback, options)
    end

    function sdk:ScheduleNow(taskName)
        if not scheduler then
            if logger then logger:LogWarn("sdk", "ScheduleNow: Scheduler unavailable on this VM") end
            return false
        end
        return scheduler:ExecuteNow(taskName)
    end

    -- ============================================================================
    -- Plugin API
    -- ============================================================================

    function sdk:RegisterPlugin(manifest)
        if not pluginManager then
            if logger then logger:LogWarn("sdk", "RegisterPlugin: PluginManager unavailable on this VM") end
            return false
        end
        return pluginManager:Register(manifest)
    end

    -- ============================================================================
    -- Config API
    -- ============================================================================

    function sdk:GetConfig(key, default)
        if not configManager then return default end
        return configManager:Get(key, default)
    end

    function sdk:LoadConfig(path)
        if not configManager then return nil end
        return configManager:Load(path)
    end

    -- ============================================================================
    -- Logger API — ONE canonical method
    -- ============================================================================
    -- Investigation 3: The Logger exposes exactly one canonical surface:
    --   sdk:Log(module, level, msg, ...)
    -- The obsolete aliases (LogError/LogInfo/LogWarn/LogDebug/Debug) are
    -- REMOVED. Every caller must use sdk:Log(module, level, msg, ...).
    -- The Logger service itself retains LogError/LogWarn/LogInfo/LogDebug as
    -- internal severity helpers, but the SDK surface is a single method.

    function sdk:Log(module, level, msg, ...)
        return logger:Log(module, level, msg, ...)
    end

    -- ============================================================================
    -- Version & Lifecycle
    -- ============================================================================

    function sdk:GetVersion()
        return "1.0.0"
    end

    function sdk:IsReady()
        -- CRITICAL: runtimeState is the state instance created by RuntimeState:New()
        -- RuntimeState:IsReady(state) expects the state instance as first arg
        return runtimeState.isReady == true
    end

    function sdk:GetRuntimeStatus()
        return runtimeState.phase
    end

    function sdk:GetBootID()
        return runtimeState.bootID
    end

    -- ============================================================================
    -- Runtime State Queries (read-only)
    -- ============================================================================

    function sdk:GetSnapshot()
        return {
            id = runtimeState.id,
            version = runtimeState.version,
            creationTime = runtimeState.creationTime,
            bootID = runtimeState.bootID,
            phase = runtimeState.phase,
            isReady = runtimeState.isReady,
            hasFailed = runtimeState.hasFailed,
            failureMessage = runtimeState.failureMessage,
            phaseTimestamps = runtimeState.phaseTimestamps,
            serviceCount = SDKBuilder:CountKeys(runtimeState.services),
            moduleCount = SDKBuilder:CountKeys(runtimeState.modules),
            pluginCount = SDKBuilder:CountKeys(runtimeState.plugins),
            listenerCount = SDKBuilder:CountKeys(runtimeState.eventListeners),
            taskCount = SDKBuilder:CountKeys(runtimeState.scheduledTasks),
            errorCount = #(runtimeState.errors or {}),
            warningCount = #(runtimeState.warnings or {}),
        }
    end

    function sdk:ListPlugins()
        if not pluginManager then return {} end
        return pluginManager:List()
    end

    -- ============================================================================
    -- Freeze the SDK
    -- ============================================================================

    local sdkMeta = {
        __newindex = function(t, key, value)
            local existing = rawget(t, key)
            if existing ~= nil then
                error(("DCE SDK[%s] is immutable and cannot be overwritten"):format(tostring(key)), 2)
            end
            rawset(t, key, value)
        end,
        __metatable = "DCE_SDK_METATABLE",
    }
    setmetatable(sdk, sdkMeta)

    -- SDK identity markers
    sdk.__sdk_id = "DCE_SDK_v1.0.0"
    sdk.__sdk_version = "1.0.0"
    sdk.__sdk_api_list = {
        "RegisterService", "GetService", "HasService", "UnregisterService", "ListServices",
        "On", "Once", "Off", "Emit",
        "Schedule", "ScheduleNow",
        "RegisterPlugin",
        "GetConfig", "LoadConfig",
        "Log",
        "GetVersion", "IsReady", "GetRuntimeStatus", "GetBootID",
        "GetSnapshot", "ListPlugins",
    }

    return sdk
end

function SDKBuilder:CountKeys(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- Registered on the server-only DCE_INTERNAL namespace.
DCE_INTERNAL = DCE_INTERNAL or {}
DCE_INTERNAL.SDKBuilder = SDKBuilder
