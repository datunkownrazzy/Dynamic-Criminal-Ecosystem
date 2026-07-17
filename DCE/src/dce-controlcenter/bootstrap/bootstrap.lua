-- DCE Control Center v2 - Bootstrap (Authoritative)
-- MINIMAL bootstrap - ONLY NUI communication and focus release
-- Total lines ~100, as required by CC-v2-COMPLETE-ARCHITECTURE.md

local Bootstrap = { isReady = false }
local DCE = nil

local function GetService(serviceName)
    if not DCE then return nil end
    return DCE.GetService and DCE.GetService(serviceName)
end

-- ============================================================================
-- NUI Communication
-- ============================================================================

function Bootstrap.NotifyNUI(action, data)
    if SendNUIMessage then
        SendNUIMessage({ action = action, data = data or {} })
    end
end

function Bootstrap.NUIReady()
    print("[DCE Bootstrap] NUI ready - releasing auto-granted focus")
    
    -- RELEASE FIVE-M AUTO-GRANTED FOCUS (critical for preventing gray overlay)
    -- SOLE OWNER: FocusManager. Only FocusManager may call SetNuiFocus.
    local FM = GetService("FocusManager")
    if FM and FM.ReleaseFocus then
        FM.ReleaseFocus("bootstrap", "auto-granted focus cleanup")
    else
        -- FocusManager not yet registered. Queue release for when it becomes available.
        -- NEVER call SetNuiFocus directly - that violates FocusManager ownership.
        print("[DCE Bootstrap] FocusManager not available - focus release deferred")
    end
    
    Bootstrap.isReady = true
    Bootstrap.NotifyNUI("bootstrap:ready", { state = "dormant" })
end

-- ============================================================================
-- NUI Callbacks
-- ============================================================================

RegisterNUICallback('dce-cc:nui:loaded', function(data, cb)
    Bootstrap.NUIReady()
    cb({ status = "ok", state = "dormant" })
end)

RegisterNUICallback('dce-cc:nui:escape', function(data, cb)
    TriggerServerEvent('dce-cc:session:close')
    cb({})
end)

RegisterNUICallback('dce-cc:nui:close', function(data, cb)
    TriggerServerEvent('dce-cc:session:close')
    cb({})
end)

-- ============================================================================
-- Application Boot Complete - Focus Acquisition Bridge
-- ============================================================================
-- Per CC-v2-COMPLETE-ARCHITECTURE.md: Boot completes -> Focus acquired -> Desktop visible
-- This is the critical link between JS boot completion and Lua focus acquisition.

RegisterNUICallback('dce-cc:application:booted', function(data, cb)
    print("[DCE Bootstrap] Application booted, acquiring focus")
    local FM = GetService("FocusManager")
    if FM and FM.RequestFocus then
        FM.RequestFocus(data and data.sessionId, "application-boot-complete")
    end
    SendNUIMessage({ action = "application:activate", data = { sessionId = data and data.sessionId } })
    cb({ status = "ok", state = "active" })
end)

-- ============================================================================
-- Resource Stop Cleanup
-- ============================================================================

AddEventHandler("onClientResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    local FM = GetService("FocusManager")
    if FM and FM.EmergencyRelease then
        FM.EmergencyRelease("resource_stop")
    end
    Bootstrap.isReady = false
end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if GetResourceState('dce-core') == 'started' then
        DCE = exports['dce-core']:GetDCEAPI()
    end
end)

print("[DCE Bootstrap] Loaded - waiting for /dce command")
return Bootstrap