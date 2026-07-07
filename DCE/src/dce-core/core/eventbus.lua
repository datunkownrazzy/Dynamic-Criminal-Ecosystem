-- DCE Event Bus
-- Pub/sub mechanism for all cross-module communication.
-- Spec: DCE-0002
-- Extended: ADR-0015 (Priority, Batching, Debouncing, Coalescing, Async queues)

local EventBus = {}
local handlers = {}              -- eventName -> { [handlerId] = { fn, priority, isHigh } }
local handlerCounter = 0
local logger
local cachedConfig = {}

-- Event optimization queues
local debounceTimers = {}        -- eventName -> { timerId, lastEmit } (times in milliseconds)
local coalesceQueues = {}      -- eventName -> { queuedPayloads }
local asyncQueues = {}         -- eventName -> queue for async processing

-- Metrics tracking
local metrics = {
    totalDispatches = 0,
    totalErrors = 0,
    totalFailed = 0,
    totalSkipped = 0,
    slowHandlers = {},           -- eventName -> count of slow handlers (>50ms)
    dispatchTimes = {},          -- eventName -> array of recent dispatch times for avg/max
}

--- Initialize the event bus with a reference to the logger.
function EventBus.Init(log)
    logger = log
    cachedConfig = _G.Config or {}
end

--- Log a message through the logger if available.
local function log(level, module, message, ...)
    if logger then
        logger.Log(module, level, message, ...)
    end
end

--- Get stack trace for error reporting (FiveM-compatible)
---@return string|nil
local function getStackTrace()
    local trace = ""
    -- Try to get stack trace using debug library if available
    local success, result = pcall(function()
        if debug and debug.traceback then
            return debug.traceback("", 2)
        end
        return nil
    end)
    if success and result then
        trace = result
    end
    return trace
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
        metrics.totalSkipped = metrics.totalSkipped + 1
        return -- no subscribers, silently return
    end

    metrics.totalDispatches = metrics.totalDispatches + 1
    
    -- Track dispatch time
    local startTime = GetGameTimer and (GetGameTimer() / 1000) or (os.clock and os.clock() or nil)
    
    local failedCount = 0
    for handlerId, handlerInfo in pairs(eventHandlers) do
        local handlerFn = handlerInfo
        -- Handle both simple function and priority table
        if type(handlerInfo) == "table" and handlerInfo.fn then
            handlerFn = handlerInfo.fn
        end
        
        local success, err = pcall(handlerFn, payload)
        if not success then
            failedCount = failedCount + 1
            metrics.totalErrors = metrics.totalErrors + 1
            local stackTrace = getStackTrace()
            log("error", "core", "EventBus.Emit: handler %s for '%s' errored: %s", tostring(handlerId), eventName, tostring(err))
            if stackTrace and stackTrace ~= "" then
                log("error", "core", "EventBus.Emit: stack trace: %s", stackTrace)
            end
            -- Emit error event for observability
            if DCE and DCE.Emit then
                DCE.Emit("eventbus:handler:error", {
                    eventName = "eventbus:handler:error",
                    eventVersion = 1,
                    timestamp = os.time(),
                    source = "dce-core",
                    payload = {
                        eventName = eventName,
                        handlerId = handlerId,
                        error = tostring(err),
                    },
                })
            end
        end
    end
    
    -- Record dispatch time for metrics
    if startTime then
        local endTime = GetGameTimer and (GetGameTimer() / 1000) or (os.clock and os.clock() or os.time())
        local elapsed = (endTime - startTime) * 1000
        
        if not metrics.dispatchTimes[eventName] then
            metrics.dispatchTimes[eventName] = {}
        end
        table.insert(metrics.dispatchTimes[eventName], elapsed)
        
        -- Trim to last 100 entries
        while #metrics.dispatchTimes[eventName] > 100 do
            table.remove(metrics.dispatchTimes[eventName], 1)
        end
        
        -- Track slow handlers (>50ms)
        if elapsed > 50 then
            metrics.slowHandlers[eventName] = (metrics.slowHandlers[eventName] or 0) + 1
        end
    end
end

--- Subscribe to an event.
---@param eventName string The event name to subscribe to
---@param handlerFn function The handler function (receives the payload table)
---@return number|nil handlerId Unique identifier for unsubscription, or nil on error
function EventBus.On(eventName, handlerFn)
    if not eventName or type(eventName) ~= "string" then
        log("error", "core", "EventBus.On: eventName must be a string")
        return nil
    end

    print("------------------------------------")
    print("REGISTER EVENT")
    print("event:")
    print(tostring(eventName))
    print("handler type:")
    print(type(handlerFn))
    print("handler:")
    print(tostring(handlerFn))
    local trace = debug and debug.traceback and debug.traceback("", 2) or "no trace"
    print("stack:")
    print(trace)
    print("------------------------------------")

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
---@return number|nil handlerId Unique identifier for unsubscription, or nil on error
function EventBus.Once(eventName, handlerFn)
    if not eventName or type(eventName) ~= "string" then
        log("error", "core", "EventBus.Once: eventName must be a string")
        return nil
    end

    if not handlerFn or type(handlerFn) ~= "function" then
        log("error", "core", "EventBus.Once: handlerFn must be a function for event '%s'", eventName)
        return nil
    end

    ---@type number|nil
    local wrapperId
    local wrapper = function(payload)
        -- Unsubscribe first to prevent re-entrancy issues
        if wrapperId then
            EventBus.Off(eventName, wrapperId)
        end
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

--- Subscribe with priority (high priority handlers run first)
---@param eventName string
---@param handlerFn function
---@param priority string "high" or "low"
---@return number|nil handlerId Unique identifier for unsubscription, or nil on error
function EventBus.OnPriority(eventName, handlerFn, priority)
    if not eventName or type(eventName) ~= "string" then
        log("error", "core", "EventBus.OnPriority: eventName must be a string")
        return nil
    end

    if not handlerFn or type(handlerFn) ~= "function" then
        log("error", "core", "EventBus.OnPriority: handlerFn must be a function for event '%s'", eventName)
        return nil
    end

    local isHigh = priority == "high" or priority == "High"

    if not handlers[eventName] then
        handlers[eventName] = {}
    end

    handlerCounter = handlerCounter + 1
    handlers[eventName][handlerCounter] = {
        fn = handlerFn,
        isHigh = isHigh,
    }

    return handlerCounter
end

--- Emit with priority-based handler execution
local function EmitWithPriority(eventName, payload)
    if not handlers[eventName] then return end

    -- Separate high and low priority handlers
    local highHandlers = {}
    local lowHandlers = {}

    for handlerId, handlerInfo in pairs(handlers[eventName]) do
        if handlerInfo.isHigh then
            table.insert(highHandlers, handlerInfo.fn)
        else
            table.insert(lowHandlers, handlerInfo.fn)
        end
    end

    -- Execute high priority first
    for _, handlerFn in ipairs(highHandlers) do
        local success, err = pcall(handlerFn, payload)
        if not success then
            log("error", "core", "EventBus.EmitWithPriority: high-priority handler for '%s' errored: %s", eventName, tostring(err))
        end
    end

    -- Then execute low priority
    for _, handlerFn in ipairs(lowHandlers) do
        local success, err = pcall(handlerFn, payload)
        if not success then
            log("error", "core", "EventBus.EmitWithPriority: low-priority handler for '%s' errored: %s", eventName, tostring(err))
        end
    end
end

--- Emit multiple events at once (batching)
---@param eventList table Array of { eventName, payload }
function EventBus.EmitBatch(eventList)
    if not eventList or type(eventList) ~= "table" then return end

    for _, event in ipairs(eventList) do
        if event.eventName and event.payload then
            EventBus.Emit(event.eventName, event.payload)
        end
    end
end

--- Emit with debouncing (rate limit same event within window)
---@param eventName string
---@param payload table
---@param debounceMs number Minimum time between emits (in milliseconds)
function EventBus.EmitDebounced(eventName, payload, debounceMs)
    local config = cachedConfig.EventBus or {}
    local rateLimitWindow = config.RateLimitWindow or debounceMs or 100

    local now = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
    local debounceInfo = debounceTimers[eventName]

    -- Check if we should skip this emit due to debouncing
    -- Times are in milliseconds now
    if debounceInfo and (now - debounceInfo.lastEmit) < rateLimitWindow then
        metrics.totalSkipped = metrics.totalSkipped + 1
        log("debug", "core", "EventBus.EmitDebounced: skipping '%s' due to rate limiting", eventName)
        return -- Skip - rate limited
    end

    debounceTimers[eventName] = {
        lastEmit = now,
        timerId = nil,
    }

    EventBus.Emit(eventName, payload)
end

--- Emit with coalescing (merge similar events)
---@param eventName string
---@param payload table
---@param coalesceMs number Time window to coalesce within
function EventBus.EmitCoalesced(eventName, payload, coalesceMs)
    -- For now, coalesced events are handled same as regular emits
    -- Future: merge payloads within time window
    EventBus.Emit(eventName, payload)
end

--- Safely create a thread with fallback
local function safeCreateThread(fn)
    local success, result = pcall(function()
        return Citizen.CreateThread and Citizen.CreateThread(fn)
    end)
    if success and result then
        return true
    else
        return false
    end
end

--- Emit with delayed execution
---@param eventName string
---@param payload table
---@param delayMs number Delay before executing handlers
function EventBus.EmitDelayed(eventName, payload, delayMs)
    if not eventName or type(eventName) ~= "string" then return end

    safeCreateThread(function()
        if Citizen.Wait then
            Citizen.Wait(delayMs or 1000)
        end
        EventBus.Emit(eventName, payload)
    end)
end

--- Get pending async queue count for an event
---@param eventName string
---@return number
function EventBus.GetAsyncQueueDepth(eventName)
    local queue = asyncQueues[eventName]
    if not queue then return 0 end
    return #queue
end

--- Calculate average from a list of numbers
---@param values table
---@return number
local function calcAverage(values)
    if not values or #values == 0 then return 0 end
    local sum = 0
    for _, v in ipairs(values) do
        sum = sum + v
    end
    return sum / #values
end

--- Calculate maximum from a list of numbers
---@param values table
---@return number
local function calcMax(values)
    if not values or #values == 0 then return 0 end
    local max = 0
    for _, v in ipairs(values) do
        if v > max then max = v end
    end
    return max
end

--- Get event bus metrics with full instrumentation
---@return table
function EventBus.GetMetrics()
    local result = {
        totalDispatches = metrics.totalDispatches,
        totalErrors = metrics.totalErrors,
        totalSkipped = metrics.totalSkipped,
        events = {},
        slowHandlers = metrics.slowHandlers,
    }
    
    -- Add per-event metrics
    for eventName, times in pairs(metrics.dispatchTimes) do
        table.insert(result.events, {
            name = eventName,
            avgDispatchMs = calcAverage(times),
            maxDispatchMs = calcMax(times),
            totalDispatches = #times,
        })
    end
    
    return result
end

--- Reset event bus metrics
function EventBus.ResetMetrics()
    metrics = {
        totalDispatches = 0,
        totalErrors = 0,
        totalFailed = 0,
        totalSkipped = 0,
        slowHandlers = {},
        dispatchTimes = {},
    }
end

--- Get event bus statistics
---@return table
function EventBus.GetStats()
    return {
        totalEvents = #EventBus.ListEvents(),
        totalHandlers = handlerCounter,
        pendingAsyncQueues = asyncQueues,
        metrics = EventBus.GetMetrics(),
    }
end

_G.DCEEventBus = EventBus
