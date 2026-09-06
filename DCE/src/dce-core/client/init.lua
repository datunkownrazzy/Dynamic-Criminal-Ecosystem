-- DCE Core — Sprint 1.11.6 Client Entry Point
--
-- FiveM executes this file as the final client_script.
-- client/bootstrap.lua (which ran immediately before) registered the client
-- composition root on DCE_INTERNAL.ClientBootstrap.
--
-- Client-side runtime: a MINIMAL SDK facade (State, Logger, Registry,
-- EventBus). No Scheduler, no PluginManager, no ConfigManager — those are
-- server-ops components and are NEVER loaded into the client Lua VM.
--
-- Exports are static functions, always present after this resource starts
-- on the client. No require(). No Wait(). No polling.
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

-- FiveM CLIENT exports are registered at RUNTIME via exports(), per the
-- official Cfx.re export API. The manifest client_exports directive does not
-- register client-side global functions as exports (server_exports does for
-- the server VM, but the client VM requires runtime registration).
-- This registers the EXISTING canonical SDK accessor — no wrapper, no alias.
exports("GetDCEAPI", GetDCEAPI)

function IsReady()
    if not runtime then return false end
    return runtime.state.isReady == true
end

local dceEventBridges = {}

function DCE_Subscribe(dceEvent, fivemEvent)
    if type(dceEvent) ~= "string" then
        print("^1[DCE Core Client] DCE_Subscribe: dceEvent must be a string^0")
        return false
    end
    if not runtime then
        print("^1[DCE Core Client] DCE_Subscribe: runtime not available^0")
        return false
    end

    if not fivemEvent then
        fivemEvent = "dce-bridge:" .. dceEvent .. ":" .. tostring(math.floor((GetGameTimer and GetGameTimer() or 0) * 1000)) .. ":" .. tostring(math.random(100000, 999999))
    elseif type(fivemEvent) ~= "string" then
        print("^1[DCE Core Client] DCE_Subscribe: fivemEvent must be a string or nil^0")
        return false
    end

    if not dceEventBridges[dceEvent] then
        dceEventBridges[dceEvent] = {}
        if DCE then
            DCE:On(dceEvent, function(payload)
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
-- Bootstrap Pipeline (client composition root, no require)
-- Runs AFTER exports are defined so exports always exist.
-- ============================================================================

if DCE_INTERNAL and DCE_INTERNAL.ClientBootstrap then
    local ok, err = pcall(function()
        runtime = DCE_INTERNAL.ClientBootstrap:Run()
    end)

    if not ok or not runtime then
        print("^1[DCE Client] FATAL: Bootstrap pipeline failed: " .. tostring(err) .. "^0")
        runtime = nil
    else
        DCE = runtime.sdk
        logger = runtime.logger
        logger:LogInfo("core", "Client bootstrap pipeline completed successfully")
    end
else
    print("^1[DCE Client] FATAL: DCE_INTERNAL.ClientBootstrap is nil. Client_scripts are misordered in fxmanifest.lua^0")
end

-- ============================================================================
-- Resource Lifecycle Hooks
-- ============================================================================

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if logger then
            logger:LogInfo("core", "=== DCE Client Core Shutdown ===")
        end
        if runtime then
            runtime.eventBus:Clear()
            runtime.registry:Clear()
        end
        if logger then
            logger:LogInfo("core", "=== DCE Client Core Shutdown Complete ===")
        end
    end
end)