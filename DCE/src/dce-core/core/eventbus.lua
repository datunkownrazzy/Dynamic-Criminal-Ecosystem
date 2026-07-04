-- DCE Event Bus
-- Pub/sub mechanism for all cross-module communication.
-- Spec: DCE-0002

local EventBus = {}
local handlers = {}       -- eventName -> { [handlerId] = handlerFn }
local handlerCounter = 0
local logger

--- Initialize the event bus with a reference to the logger.
function EventBus.Init(log)
    logger = log
end

--- Emit an event to all subscribers.
--- Payload must use the envelope format: { eventName, eventVersion, timestamp, source, correlationId?, payload }
---@param eventName string The event name (domain:subject:verb)
---@param payload table The event payload (plain table, no functions or metatables)
function EventBus.Emit(eventName, payload)
    if not eventName or type(eventName) ~= "string" then
        log("error", "core", "EventBus.Emit: eventName must be a string")
        return
    end

    if not payload or type(payload) ~= "table" then
        log("error", "core", "EventBus.Emit: payload must be a table for event '%s'", eventName)
        return
    end

    local eventHandlers = handlers[eventName]
    if not eventHandlers then
        return -- no subscribers, silently return
    end

    for handlerId, handlerFn in pairs(eventHandlers) do
        local success, err = pcall(handlerFn, payload)
        if not success then
            log("error", "core", "EventBus.Emit: handler %s for '%s' errored: %s", tostring(handlerId), eventName, tostring(err))
        end
    end
end

--- Subscribe to an event.
---@param eventName string The event name to subscribe to
---@param handlerFn function The handler function (receives the payload table)
---@return number handlerId Unique identifier for unsubscription
function EventBus.On(eventName, handlerFn)
    if not eventName or type(eventName) ~= "string" then
        log("error", "core", "EventBus.On: eventName must be a string")
        return nil
    end

    if not handlerFn or type(handlerFn) ~= "function" then
        log("error", "core", "EventBus.On: handlerFn must be a function for event '%s'", eventName)
        return nil
    end

    if not handlers[eventName] then
        handlers[eventName] = {}
    end

    handlerCounter = handlerCounter + 1
    handlers[eventName][handlerCounter] = handlerFn

    return handlerCounter
end

--- Subscribe to an event, but fire only once then auto-unsubscribe.
---@param eventName string The event name to subscribe to
---@param handlerFn function The handler function (receives the payload table)
---@return number handlerId Unique identifier
function EventBus.Once(eventName, handlerFn)
    if not eventName or type(eventName) ~= "string" then
        log("error", "core", "EventBus.Once: eventName must be a string")
        return nil
    end

    if not handlerFn or type(handlerFn) ~= "function" then
        log("error", "core", "EventBus.Once: handlerFn must be a function for event '%s'", eventName)
        return nil
    end

    local wrapperId
    local wrapper = function(payload)
        -- Unsubscribe first to prevent re-entrancy issues
        EventBus.Off(eventName, wrapperId)
        handlerFn(payload)
    end

    wrapperId = EventBus.On(eventName, wrapper)
    return wrapperId
end

--- Unsubscribe from an event.
---@param eventName string The event name
---@param handlerId number The handler ID returned from On/Once
function EventBus.Off(eventName, handlerId)
    if not eventName or type(eventName) ~= "string" then
        log("error", "core", "EventBus.Off: eventName must be a string")
        return
    end

    if handlerId == nil then
        log("warn", "core", "EventBus.Off: handlerId is nil for event '%s'", eventName)
        return
    end

    local eventHandlers = handlers[eventName]
    if not eventHandlers then
        log("warn", "core", "EventBus.Off: no handlers for event '%s'", eventName)
        return
    end

    eventHandlers[handlerId] = nil

    -- Clean up empty handler tables
    if next(eventHandlers) == nil then
        handlers[eventName] = nil
    end
end

--- Remove all handlers for a specific event.
---@param eventName string The event name
function EventBus.ClearEvent(eventName)
    if not eventName then
        return
    end
    handlers[eventName] = nil
    log("debug", "core", "EventBus: cleared all handlers for '%s'", eventName)
end

--- Remove all handlers for all events. Called during shutdown.
function EventBus.ClearAll()
    for eventName, _ in pairs(handlers) do
        handlers[eventName] = nil
    end
    handlerCounter = 0
    log("info", "core", "EventBus: all handlers cleared")
end

--- Get a list of all events that have active handlers.
---@return table Array of event name strings
function EventBus.ListEvents()
    local names = {}
    for eventName, _ in pairs(handlers) do
        table.insert(names, eventName)
    end
    return names
end

--- Get the number of handlers for a specific event.
---@param eventName string
---@return number
function EventBus.HandlerCount(eventName)
    local eventHandlers = handlers[eventName]
    if not eventHandlers then
        return 0
    end
    local count = 0
    for _, _ in pairs(eventHandlers) do
        count = count + 1
    end
    return count
end

local function log(level, module, message, ...)
    if logger then
        logger.Log(module, level, message, ...)
    end
end

_G.DCEEventBus = EventBus
