-- DCE Control Center v2 - Event Forwarder Client
-- Forwards DCE EventBus events to NUI for real-time updates

local DCE = _G.DCE
local DCEEventForwarder = {}

-- Store subscriptions per player
local playerSubscriptions = {}

-- Forward an event to the NUI
--@param source number Player source
--@param eventName string DCE event name
--@param payload table Event payload
function DCEEventForwarder.ForwardEvent(source, eventName, payload)
    if not source or not eventName then return end
    
    -- Check if player has any windows open that might care about this event
    -- In a full implementation, we'd check which plugins are subscribed to which events
    TriggerClientEvent('dce-cc:client:eventbus', source, {
        eventName = eventName,
        payload = payload
    })
end

-- Register an event subscription for a player
--@param source number Player source
--@param eventName string DCE event name
--@return boolean
function DCEEventForwarder.RegisterSubscription(source, eventName)
    if not source or not eventName then return false end
    
    if not playerSubscriptions[source] then
        playerSubscriptions[source] = {}
    end
    
    playerSubscriptions[source][eventName] = true
    return true
end

-- Unregister an event subscription for a player
--@param source number Player source
--@param eventName string DCE event name
function DCEEventForwarder.UnregisterSubscription(source, eventName)
    if playerSubscriptions[source] then
        playerSubscriptions[source][eventName] = nil
    end
end

-- Clean up all subscriptions for a player (on disconnect)
--@param source number Player source
function DCEEventForwarder.CleanupPlayer(source)
    playerSubscriptions[source] = nil
end

-- Handle subscription requests from NUI
RegisterNUICallback('dce-cc:eventbus:subscribe', function(data, cb)
    local src = source
    if data.eventName and DCEEventForwarder.RegisterSubscription(src, data.eventName) then
        -- Acknowledge subscription
        cb({ success = true })
    else
        cb({ success = false })
    end
end)

RegisterNUICallback('dce-cc:eventbus:unsubscribe', function(data, cb)
    local src = source
    DCEEventForwarder.UnregisterSubscription(src, data.eventName)
    cb({})
end)

-- Handle player disconnecting
AddEventHandler('playerDropped', function()
    local src = source
    DCEEventForwarder.CleanupPlayer(src)
end)

-- Export
_G.DCEEventForwarder = DCEEventForwarder