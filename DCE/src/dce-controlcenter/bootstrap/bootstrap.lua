-- DCE Control Center v2 - Bootstrap — Sprint 1.11.3
--
-- MINIMAL bootstrap - ONLY NUI communication and focus release
-- Uses sticky lifecycle events for guaranteed delivery.
-- No polling. No retry loops.
---
---@diagnostic disable: undefined-global

local Bootstrap = { isReady = false }
local DCE = nil
local initialized = false
local pendingRequests = {}
local nextRequestId = 0

-- ============================================================================
-- SDK Acquisition — Single Call, No Polling
-- ============================================================================

local function AcquireSDK()
    local success, api = pcall(function()
        if exports and exports['dce-core'] and exports['dce-core'].GetDCEAPI then
            return exports['dce-core']:GetDCEAPI()
        end
        return nil
    end)
    if success then
        DCE = api
    end
    return DCE
end

local function GetService(serviceName)
    if not DCE then return nil end
    if DCE.GetService then
        return DCE:GetService(serviceName)
    end
    return nil
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

    local FM = GetService("FocusManager")
    if FM and FM.ReleaseFocus then
        FM.ReleaseFocus("bootstrap", "auto-granted focus cleanup")
    else
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

RegisterNUICallback('dce-cc:application:booted', function(data, cb)
    print("[DCE Bootstrap] Application booted, acquiring focus")
    local FM = GetService("FocusManager")
    if FM and FM.RequestFocus then
        FM.RequestFocus(data and data.sessionId, "application-boot-complete")
    end
    SendNUIMessage({ action = "application:activate", data = { sessionId = data and data.sessionId } })
    cb({ status = "ok", state = "active" })
end)

local function RequestServerData(dataType, cb)
    nextRequestId = nextRequestId + 1
    local requestId = (GetGameTimer and GetGameTimer() or os.time()) .. ":" .. nextRequestId
    pendingRequests[requestId] = cb
    TriggerServerEvent('dce-cc:server:data-request', {
        requestId = requestId,
        dataType = dataType
    })
end

RegisterNUICallback('world-locations:get', function(data, cb)
    RequestServerData('world-locations', cb)
end)

RegisterNUICallback('world-territories:get', function(data, cb)
    RequestServerData('world-territories', cb)
end)

RegisterNUICallback('organization-list:get', function(data, cb)
    RequestServerData('organizations', cb)
end)

RegisterNetEvent('dce-cc:client:data-response')
AddEventHandler('dce-cc:client:data-response', function(response)
    if not response or not response.requestId then return end
    local cb = pendingRequests[response.requestId]
    if not cb then return end
    pendingRequests[response.requestId] = nil
    cb(response)
end)

-- ============================================================================
-- Lifecycle
-- ============================================================================

Citizen.CreateThread(function()
    Citizen.Wait(0)
    DCE = AcquireSDK()
    if DCE and not initialized then
        initialized = true
        DCE:On("lifecycle:running", function(payload)
            print("[DCE Bootstrap] Runtime running - bootstrap active")
        end)
    end
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
    if not DCE then
        DCE = AcquireSDK()
    end
end)

print("[DCE Bootstrap] Loaded - waiting for /dce command")
return Bootstrap