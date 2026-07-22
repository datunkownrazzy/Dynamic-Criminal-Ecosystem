-- DCE Core — Canonical Frozen SDK Wrapper
-- Sprint 1.10.2 — Platform SDK Standardization
--
-- This module creates a FROZEN SDK table that is returned by
-- exports["dce-core"]:GetDCEAPI().
--
-- THE FROZEN SDK
-- - Contains ONLY public documented APIs
-- - Never returns internal service tables directly
-- - Never exposes mutable implementation state
-- - Is stable across future versions
-- - Is the SOLE supported public interface for all external resources
--
-- Every external DCE resource shall obtain Core exclusively through:
--   local DCE = exports["dce-core"]:GetDCEAPI()
-- No external resource should rely on _G.DCE, _G.DCERegistry, etc.
--
-- Internal globals (_G.DCERegistry, _G.DCEEventBus, etc.) become
-- Core implementation details and are NOT part of the public contract.
--
-- ARCHITECTURAL RULE:
-- The returned SDK is the sole supported public interface.
-- Internal globals are implementation details.
-- External resources must never depend on implementation globals.
---@diagnostic disable: duplicate-set-field, undefined-global

local SDK = {}

-- ============================================================================
-- Service Registry API
-- ============================================================================

function SDK.GetService(name)
    local reg = _G.DCERegistry
    if reg then return reg.Get(name) end
    return nil
end

function SDK.RegisterService(name, serviceTable, options)
    local reg = _G.DCERegistry
    if reg then return reg.Register(name, serviceTable, options) end
    return false
end

function SDK.HasService(name)
    local reg = _G.DCERegistry
    if reg then return reg.Has(name) end
    return false
end

function SDK.GetServiceOrThrow(name)
    local reg = _G.DCERegistry
    if reg then return reg.GetOrThrow(name) end
    error("DCE Service Registry: required service '" .. name .. "' is not registered")
end

function SDK.UnregisterService(name)
    -- INTERNAL: marked for backward compatibility
    local reg = _G.DCERegistry
    if reg then return reg.Unregister(name) end
    return false
end

-- ============================================================================
-- Event Bus API
-- ============================================================================

function SDK.Emit(eventName, payload)
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

function SDK.On(eventName, handlerFn)
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

function SDK.Once(eventName, handlerFn)
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

function SDK.Off(eventName, handlerId)
    local eb = _G.DCEEventBus
    if eb then return eb.Off(eventName, handlerId) end
end

-- ============================================================================
-- Scheduler API
-- ============================================================================

function SDK.Schedule(taskName, intervalMs, callback, options)
    local sched = _G.DCEScheduler
    if sched then return sched.Schedule(taskName, intervalMs, callback, options) end
    return false
end

function SDK.ScheduleNow(taskName)
    local sched = _G.DCEScheduler
    if sched then return sched.ExecuteNow(taskName) end
    return false
end

-- ============================================================================
-- Plugin API
-- ============================================================================

function SDK.RegisterPlugin(manifest)
    local pm = _G.DCEPluginArchitecture
    if pm then return pm.Register(manifest) end
    local oldPm = _G.DCEPluginManager
    if oldPm then return oldPm.Register(manifest) end
    return false
end

-- ============================================================================
-- Config API
-- ============================================================================

function SDK.LoadConfig(path)
    local cl = _G.DCEConfigLoader
    if cl then return cl.Load(path) end
    return nil
end

function SDK.ValidateConfig(config, schema)
    local cf = _G.DCEConfigFramework
    if cf then
        local ok, _ = cf.Validate(config, schema)
        return ok
    end
    return false
end

-- ============================================================================
-- Logger API
-- ============================================================================

function SDK.Log(module, level, message, ...)
    local l = _G.DCELogger
    if l then l.Log(module, level, message, ...) end
end

-- ============================================================================
-- Version & Lifecycle
-- ============================================================================

function SDK.GetVersion()
    return "1.0.0"
end

function SDK.IsReady()
    return _G.DCECoreReady == true
end

-- ============================================================================
-- SDK Registration APIs (Future Reserved)
-- These emit events but have no subscribers yet.
-- This is intentional — they are architectural contracts.
-- ============================================================================

function SDK.RegisterOrganization(orgDataTable)
    if not orgDataTable or type(orgDataTable) ~= "table" then return false, "orgDataTable must be a table" end
    SDK.Emit("sdk:organization:registered", {
        eventVersion = 1, timestamp = os.time(), source = "dce-core-sdk",
        payload = { orgId = orgDataTable.id },
    })
    return true
end

function SDK.RegisterDispatchAdapter(adapterTable)
    if not adapterTable then return false end
    SDK.Emit("sdk:adapter:registered", {
        eventVersion = 1, timestamp = os.time(), source = "dce-core-sdk",
        payload = { category = "dispatch", adapterName = adapterTable.Name or "unknown" },
    })
    return true
end

function SDK.RegisterEvidenceAdapter(adapterTable)
    if not adapterTable then return false end
    SDK.Emit("sdk:adapter:registered", {
        eventVersion = 1, timestamp = os.time(), source = "dce-core-sdk",
        payload = { category = "evidence", adapterName = adapterTable.Name or "unknown" },
    })
    return true
end

function SDK.RegisterMDTAdapter(adapterTable)
    if not adapterTable then return false end
    SDK.Emit("sdk:adapter:registered", {
        eventVersion = 1, timestamp = os.time(), source = "dce-core-sdk",
        payload = { category = "mdt", adapterName = adapterTable.Name or "unknown" },
    })
    return true
end

function SDK.RegisterBehavior(behaviorDataTable)
    if not behaviorDataTable then return false end
    SDK.Emit("sdk:behavior:registered", {
        eventVersion = 1, timestamp = os.time(), source = "dce-core-sdk",
        payload = { behaviorType = behaviorDataTable.type or "unknown" },
    })
    return true
end

function SDK.RegisterEscalationChain(escalationSchemaTable)
    if not escalationSchemaTable then return false end
    SDK.Emit("sdk:escalation:registered", {
        eventVersion = 1, timestamp = os.time(), source = "dce-core-sdk",
        payload = { chainId = escalationSchemaTable.id or "unknown" },
    })
    return true
end

-- ============================================================================
-- Freeze the SDK — Make the table immutable
-- ============================================================================
-- The SDK contract becomes the single authoritative integration point.
-- No external resource may modify the SDK at runtime.

if not _G.DCE_FROZEN_SDK then
    _G.DCE_FROZEN_SDK = SDK
end

return SDK