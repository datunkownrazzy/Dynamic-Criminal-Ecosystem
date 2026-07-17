-- DCE Control Center v2 - Event Forwarder (Authoritative)
-- Bridges EventBus events from Lua to NUI for real-time updates

local EventBus = nil
local Logger = nil
local dceCoreReady = false
local subscribed = false

local function ConnectToCore()
    if dceCoreReady then return true end
    if GetResourceState('dce-core') ~= 'started' then return false end
    local DCE = exports['dce-core']:GetDCEAPI()
    if not DCE then return false end
    EventBus = DCE.GetService and DCE.GetService("EventBus")
    Logger = DCE.GetService and DCE.GetService("Logger")
    dceCoreReady = true
    return true
end

-- Subscribe to EventBus events and forward to NUI
local function SubscribeEvents()
    if not ConnectToCore() then
        SetTimeout(1000, SubscribeEvents)
        return
    end
    if subscribed or not EventBus then return end
    
    -- Forward all relevant DCE events to NUI
    local events = {
        "operation:state_changed",
        "intelligence:updated",
        "heat:changed",
        "territory:changed",
        "economy:updated",
        "world:state_changed",
    }
    
    for _, eventName in ipairs(events) do
        EventBus.On(eventName, function(payload)
            SendNUIMessage({
                action = "eventbus:event",
                data = {
                    eventName = eventName,
                    payload = payload
                }
            })
        end)
    end
    
    subscribed = true
    print("[DCE EventForwarder] Subscribed to EventBus events")
end

-- NUI callback for EventBus subscriptions from JS
RegisterNUICallback('dce-cc:eventbus:subscribe', function(data, cb)
    if not ConnectToCore() then
        cb({ status = "error", message = "Core not connected" })
        return
    end
    cb({ status = "ok" })
end)

-- Resource start
SubscribeEvents()

-- Resource stop
AddEventHandler("onClientResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    subscribed = false
end)

print("[DCE EventForwarder] Loaded")