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
local placement = nil

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

local function RequestConfigurationChange(request, cb)
    nextRequestId = nextRequestId + 1
    local requestId = (GetGameTimer and GetGameTimer() or os.time()) .. ":" .. nextRequestId
    pendingRequests[requestId] = cb
    TriggerServerEvent('dce-cc:server:configuration-request', {
        requestId = requestId,
        request = request,
    })
    SetTimeout(10000, function()
        if pendingRequests[requestId] then
            pendingRequests[requestId] = nil
            cb({
                code = "TIMEOUT",
                message = "No authoritative response was received.",
                runtimeApplied = false,
                persisted = false,
                restartRequired = false,
            })
        end
    end)
end

RegisterNUICallback('world-locations:get', function(data, cb)
    RequestServerData('world-locations', cb)
end)

RegisterNUICallback('world-territories:get', function(data, cb)
    RequestServerData('world-territories', cb)
end)

RegisterNUICallback('world-placement:start', function(data, cb)
    local ped = PlayerPedId and PlayerPedId() or 0
    if not ped or ped == 0 or not GetEntityCoords or not GetEntityHeading then
        cb({ code = "CAPTURE_UNAVAILABLE", message = "The player position is unavailable." })
        return
    end
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    if not coords or type(heading) ~= "number" then
        cb({ code = "CAPTURE_UNAVAILABLE", message = "The player position is unavailable." })
        return
    end
    placement = {
        ---@diagnostic disable-next-line: undefined-field
        coordinates = { x = coords.x, y = coords.y, z = coords.z },
        heading = heading,
    }
    local FM = GetService("FocusManager")
    if FM and FM.SetGameInputAllowed then
        FM.SetGameInputAllowed(true)
    end
    cb({ code = "SUCCESS" })
end)

RegisterNUICallback('world-placement:cancel', function(data, cb)
    placement = nil
    local FM = GetService("FocusManager")
    if FM and FM.SetGameInputAllowed then
        FM.SetGameInputAllowed(false)
    end
    cb({ code = "SUCCESS" })
end)

RegisterNUICallback('world-placement:reset', function(data, cb)
    local ped = PlayerPedId and PlayerPedId() or 0
    if not ped or ped == 0 or not GetEntityCoords or not GetEntityHeading then
        cb({ code = "CAPTURE_UNAVAILABLE", message = "The player position is unavailable." })
        return
    end
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    placement = {
        ---@diagnostic disable-next-line: undefined-field
        coordinates = { x = coords.x, y = coords.y, z = coords.z },
        heading = heading,
    }
    cb({ code = "SUCCESS" })
end)

RegisterNUICallback('world-placement:capture', function(data, cb)
    local ped = PlayerPedId and PlayerPedId() or 0
    if not ped or ped == 0 or not GetEntityCoords or not GetEntityHeading then
        cb({ code = "CAPTURE_UNAVAILABLE", message = "The player position is unavailable." })
        return
    end

    local coords = placement and placement.coordinates or GetEntityCoords(ped)
    local heading = placement and placement.heading or GetEntityHeading(ped)
    if not coords or type(heading) ~= "number" then
        cb({ code = "CAPTURE_UNAVAILABLE", message = "The player position is unavailable." })
        return
    end

    cb({
        code = "SUCCESS",
        ---@diagnostic disable-next-line: undefined-field
        coordinates = { x = coords.x, y = coords.y, z = coords.z },
        heading = heading,
    })
end)

Citizen.CreateThread(function()
    while true do
        if placement and IsControlPressed and DrawMarker then
            local coordinates = placement.coordinates
            local speed = IsControlPressed(0, 21) and 0.2 or 0.05
            if IsControlPressed(0, 172) then coordinates.y = coordinates.y + speed end
            if IsControlPressed(0, 173) then coordinates.y = coordinates.y - speed end
            if IsControlPressed(0, 174) then coordinates.x = coordinates.x - speed end
            if IsControlPressed(0, 175) then coordinates.x = coordinates.x + speed end
            if IsControlPressed(0, 10) then coordinates.z = coordinates.z + speed end
            if IsControlPressed(0, 11) then coordinates.z = coordinates.z - speed end
            if IsControlPressed(0, 44) then placement.heading = (placement.heading - 1) % 360 end
            if IsControlPressed(0, 38) then placement.heading = (placement.heading + 1) % 360 end
            DrawMarker(1, coordinates.x, coordinates.y, coordinates.z - 1.0, 0.0, 0.0, 0.0,
                0.0, 0.0, placement.heading, 1.0, 1.0, 0.25, 40, 180, 120, 160,
                false, true, 2, false, nil, nil, false)
            Citizen.Wait(0)
        else
            Citizen.Wait(250)
        end
    end
end)

RegisterNUICallback('organization-list:get', function(data, cb)
    RequestServerData('organizations', cb)
end)

RegisterNUICallback('configuration:get', function(data, cb)
    RequestServerData('configuration', cb)
end)

RegisterNUICallback('world-configuration:apply', function(data, cb)
    RequestConfigurationChange(data, cb)
end)

RegisterNetEvent('dce-cc:client:data-response')
AddEventHandler('dce-cc:client:data-response', function(response)
    if not response or not response.requestId then return end
    local cb = pendingRequests[response.requestId]
    if not cb then return end
    pendingRequests[response.requestId] = nil
    cb(response)
end)

RegisterNetEvent('dce-cc:client:configuration-changed')
AddEventHandler('dce-cc:client:configuration-changed', function(change)
    Bootstrap.NotifyNUI('configuration:changed', change)
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
    placement = nil
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