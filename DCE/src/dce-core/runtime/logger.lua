-- DCE Logger — Sprint 1.11.7 Contract Reconciliation
--
-- Single canonical logger.
-- No duplicate implementations.
-- No wrappers.
--
-- CANONICAL API (Investigation 3):
--   logger:Log(module, level, msg, ...)
--   logger:LogError(module, msg, ...)
--   logger:LogWarn(module, msg, ...)
--   logger:LogInfo(module, msg, ...)
--   logger:LogDebug(module, msg, ...)
--
-- The obsolete aliases (Error/Warn/Info/Debug) are REMOVED. There is exactly
-- one method per severity level. Every caller must use the canonical names.
--
-- CRITICAL FIX (Logger.LogError() is nil):
-- The previous implementation captured the state INSTANCE in a variable named
-- `runtimeState` and called `runtimeState:LogError(...)`. The state instance
-- has no such method — only the RuntimeState MODULE does. This produced
-- "Logger.LogError() is nil" at runtime.
--
-- The logger now resolves the RuntimeState module from DCE_INTERNAL and
-- invokes RuntimeState:LogError(state, ...) with the module as `self` and the
-- state instance as the first argument. This matches the canonical
-- RuntimeState contract exactly.
---@diagnostic disable: undefined-global

local Logger = {}

function Logger:New(runtimeState)
    local logger = {}

    local state = runtimeState
    -- The RuntimeState MODULE (not the instance) owns LogError/LogWarning.
    -- It is registered on DCE_INTERNAL by runtime/state.lua before this file
    -- executes (manifest ordering is the dependency graph).
    local RuntimeState = DCE_INTERNAL and DCE_INTERNAL.RuntimeState

    function logger:Log(module, level, msg, ...)
        if not msg then return end
        local formatted = string.format(msg, ...)
        local prefix = string.format("[DCE][%s][%s]", module, level)
        print(string.format("%s %s", prefix, formatted))
    end

    function logger:LogInfo(module, msg, ...)
        self:Log(module, "info", msg, ...)
    end

    function logger:LogWarn(module, msg, ...)
        self:Log(module, "warn", msg, ...)
        if state and RuntimeState and RuntimeState.LogWarning then
            RuntimeState:LogWarning(state, module, string.format(msg, ...))
        end
    end

    function logger:LogError(module, msg, ...)
        self:Log(module, "error", msg, ...)
        if state and RuntimeState and RuntimeState.LogError then
            RuntimeState:LogError(state, module, string.format(msg, ...))
        end
    end

    function logger:LogDebug(module, msg, ...)
        self:Log(module, "debug", msg, ...)
    end

    function logger:GetState()
        return state
    end

    return logger
end

-- Registered on the DCE_INTERNAL namespace (server and client VMs).
DCE_INTERNAL = DCE_INTERNAL or {}
DCE_INTERNAL.Logger = Logger