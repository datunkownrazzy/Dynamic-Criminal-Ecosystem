-- DCE Runtime State — Sprint 1.11.7 FiveM Runtime Compatibility
--
-- Single canonical runtime state.
-- Everything reads from it.
-- Nothing mirrors it.
-- Nothing caches it.
-- Nothing duplicates it.
--
-- This is the ONE source of truth for the entire platform.
--
-- FIVEM COMPATIBILITY (Investigation 1):
-- This module is loaded by the FiveM CLIENT VM via client_scripts. The FiveM
-- client Lua runtime does NOT provide the `os` library (os.time/os.date/os.clock
-- are server-only). Per the FiveM scripting reference, the platform-safe clock
-- is the GetGameTimer() native, available on BOTH the server and client VMs.
--
-- All timestamps in shared runtime modules use the FiveM-safe clock below.
-- No `os.time()` call may ever be load-bearing in a client-visible module.
---@diagnostic disable: undefined-global

local RuntimeState = {}
local State = {}

-- ============================================================================
-- Platform-safe clock (FiveM client/server compatible)
-- ============================================================================
-- GetGameTimer() is the documented FiveM native returning milliseconds since
-- game start. It exists on both VMs. This guarded accessor is NOT a polyfill:
-- it calls the documented native when available, and only falls back in
-- non-FiveM (development LSP) environments.
local function now()
    if GetGameTimer then return GetGameTimer() end
    if os and os.time then return os.time() * 1000 end
    return 0
end

-- ============================================================================
-- State Initialization
-- ============================================================================

function RuntimeState:New()
    local state = {
        -- Identity
        id = nil,
        version = "1.11.7",
        creationTime = nil,
        bootID = nil,

        -- Bootstrap Pipeline
        phase = nil,          -- nil | BOOT | REGISTRATION | SERVICES | SDK | FREEZE | EXPORTS | READY | RUNNING | FAILED
        phaseTimestamps = {},
        isReady = false,
        hasFailed = false,
        failureMessage = nil,

        -- Services (owned by Registry)
        services = {},

        -- Event listeners (owned by EventBus)
        eventListeners = {},

        -- Scheduled tasks (owned by Scheduler)
        scheduledTasks = {},

        -- Plugins (owned by PluginManager)
        plugins = {},

        -- Modules that have registered
        modules = {},

        -- Sticky lifecycle events (replayable)
        stickyEvents = {},

        -- Error log
        errors = {},
        warnings = {},
    }

    state.creationTime = now()
    local randomSuffix = math.random(100000, 999999)
    state.id = string.format("%08x-%06x", state.creationTime, randomSuffix)
    state.bootID = state.id
    state.phase = "BOOT"
    state.phaseTimestamps["BOOT"] = now()

    return state
end

-- ============================================================================
-- Phase Management
-- ============================================================================

function RuntimeState:SetPhase(state, phase)
    if not state then return end
    state.phase = phase
    state.phaseTimestamps[phase] = now()
    if phase == "RUNNING" then
        state.isReady = true
    end
end

function RuntimeState:SetFailed(state, msg)
    if not state then return end
    state.hasFailed = true
    state.failureMessage = msg
    state.phase = "FAILED"
    state.phaseTimestamps["FAILED"] = now()
end

function RuntimeState:GetPhase(state)
    if not state then return nil end
    return state.phase
end

function RuntimeState:IsReady(state)
    if not state then return false end
    return state.isReady
end

function RuntimeState:HasFailed(state)
    if not state then return false end
    return state.hasFailed
end

-- ============================================================================
-- Error/Warning Logging
-- ============================================================================
-- These are the CANONICAL state recorders. The Logger service invokes these
-- with the STATE INSTANCE as the first argument (module as `self`, instance
-- as `state`). Callers must use RuntimeState:LogError(state, ...).

function RuntimeState:LogError(state, module, msg)
    if not state then return end
    table.insert(state.errors, { module = module, message = msg, time = now() })
end

function RuntimeState:LogWarning(state, module, msg)
    if not state then return end
    table.insert(state.warnings, { module = module, message = msg, time = now() })
end

-- ============================================================================
-- Snapshot (read-only)
-- ============================================================================

function RuntimeState:GetSnapshot(state)
    if not state then return {} end
    return {
        id = state.id,
        version = state.version,
        creationTime = state.creationTime,
        bootID = state.bootID,
        phase = state.phase,
        isReady = state.isReady,
        hasFailed = state.hasFailed,
        failureMessage = state.failureMessage,
        phaseTimestamps = state.phaseTimestamps,
        serviceCount = self:CountKeys(state.services),
        moduleCount = self:CountKeys(state.modules),
        pluginCount = self:CountKeys(state.plugins),
        listenerCount = self:CountKeys(state.eventListeners),
        taskCount = self:CountKeys(state.scheduledTasks),
        errorCount = #(state.errors or {}),
        warningCount = #(state.warnings or {}),
    }
end

function RuntimeState:CountKeys(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- Registered on the DCE_INTERNAL namespace (server and client VMs).
-- The manifest's client_scripts/server_scripts ordering guarantees this runs
-- before runtime/bootstrap.lua (server) and client/bootstrap.lua (client).
-- No require() is used.
DCE_INTERNAL = DCE_INTERNAL or {}
DCE_INTERNAL.RuntimeState = RuntimeState