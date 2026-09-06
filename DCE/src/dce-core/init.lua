-- DCE Core — Sprint 1.11.6 Server Entry Point
--
-- FiveM executes this file as the final server_script.
-- The bootstrap composition root (DCE_INTERNAL.Bootstrap) was registered by
-- runtime/bootstrap.lua which ran immediately before this file.
--
-- This file:
--   1. Runs the single composition root (no require()).
--   2. Defines exports as STATIC functions.
--   3. Registers resource lifecycle teardown.
--
-- Exports exist before any consumer executes because FiveM's dependency
-- directive guarantees dce-core reaches fully-started (all server_scripts
-- executed) BEFORE a dependent resource's scripts run.
--
-- Exports are platform infrastructure:
--   * Never created lazily.
--   * Never created inside lifecycle callbacks.
--   * Never removed during operation.
---@diagnostic disable: undefined-global

-- ============================================================================
-- Exports — Static, ALWAYS defined BEFORE bootstrap runs.
-- Bootstrap must never control export existence.
-- Exports exist even if bootstrap crashes.
-- ============================================================================

local runtime = nil
local DCE = nil
local logger = nil

function GetDCEAPI()
    return DCE
end

function IsReady()
    if not runtime then return false end
    return runtime.state.isReady == true
end

function DCE_Subscribe(dceEvent, fivemEvent)
    if type(dceEvent) ~= "string" then
        print("^1[DCE Core] DCE_Subscribe: dceEvent must be a string^0")
        return false
    end
    if not runtime then
        print("^1[DCE Core] DCE_Subscribe: runtime not available^0")
        return false
    end

    if not fivemEvent then
        fivemEvent = "dce-bridge:" .. dceEvent .. ":" .. tostring(math.floor((GetGameTimer and GetGameTimer() or 0) * 1000)) .. ":" .. tostring(math.random(100000, 999999))
    end

    runtime.eventBus:On(dceEvent, function(payload)
        TriggerEvent(fivemEvent, payload)
    end)

    return fivemEvent
end

-- ============================================================================
-- Bootstrap Pipeline (single composition root, no require)
-- Runs AFTER exports are defined so exports always exist.
-- ============================================================================

-- DCE_INTERNAL is a server-only namespace. It is NEVER published to _G.DCE.
-- It is populated solely by the server_scripts listed before this file.
if DCE_INTERNAL and DCE_INTERNAL.Bootstrap then
    local ok, err = pcall(function()
        runtime = DCE_INTERNAL.Bootstrap:Run()
    end)

    if not ok or not runtime then
        print("^1[DCE] FATAL: Bootstrap pipeline failed: " .. tostring(err) .. "^0")
        runtime = nil
    else
        DCE = runtime.sdk
        logger = runtime.logger
        logger:LogInfo("core", "Bootstrap pipeline completed successfully")
    end
else
    print("^1[DCE] FATAL: DCE_INTERNAL.Bootstrap is nil. Server_scripts are misordered in fxmanifest.lua^0")
end

-- ============================================================================
-- Resource Lifecycle Hooks
-- ============================================================================

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if logger then
            logger:LogInfo("core", "=== DCE Core Shutdown ===")
        end
        if runtime then
            runtime.scheduler:Clear()
            runtime.eventBus:Clear()
            runtime.registry:Clear()
            runtime.pluginManager:Clear()
        end
        if logger then
            logger:LogInfo("core", "=== DCE Core Shutdown Complete ===")
        end
    end
end)