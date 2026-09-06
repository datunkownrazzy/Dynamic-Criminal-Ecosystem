-- DCE EventBus — Sprint 1.11.7 Contract Reconciliation
--
-- Single canonical event bus.
-- Rejects invalid handlers immediately.
-- Supports sticky lifecycle events for guaranteed delivery.
-- No duplicate event buses.
--
-- FIVEM COMPATIBILITY (Investigation 1):
-- This module is loaded by the FiveM CLIENT VM via client_scripts. The FiveM
-- client Lua runtime does NOT provide the `os` library. All timestamps use the
-- platform-safe clock (GetGameTimer native) instead of os.time().
---@diagnostic disable: undefined-global

local EventBus = {}

-- Platform-safe clock (FiveM client/server compatible).
-- GetGameTimer() is the documented FiveM native available on both VMs.
local function now()
    if GetGameTimer then return GetGameTimer() end
    if os and os.time then return os.time() * 1000 end
    return 0
end

-- ============================================================================
-- FiveM cross-resource function references (Sprint 1.11.11 contract repair)
-- ============================================================================
-- FiveM exports marshal values across resource VMs (msgpack). A Lua function
-- passed as an ARGUMENT through the export boundary — or stored in a table
-- RETURNED by an export, e.g. the SDK — materializes on the receiving side as
-- a callable FunctionRef TABLE, not a Lua closure. type() therefore reports
-- "table" even though the value is callable. This is documented FiveM
-- cross-resource function-reference semantics.
--
-- normalizeHandler converts such a callable reference into a real in-VM Lua
-- closure so the EventBus stores exactly one canonical representation:
--   listeners[event][i] = { id = <number>, handler = <function> }
local function normalizeHandler(fn)
    if type(fn) == "function" then
        return fn
    end
    if type(fn) == "table" then
        local mt = getmetatable(fn)
        if mt ~= nil and type(mt.__call) == "function" then
            -- Callable FunctionRef table (FiveM cross-resource callback).
            -- This closure lives in THIS VM and never crosses the boundary
            -- again, preserving canonical EventBus storage semantics.
            return function(payload)
                return fn(payload)
            end
        end
    end
    return nil
end

function EventBus:New(runtimeState, logger)
    local bus = {}
    local listeners = {}
    local listenerCounter = 0
    local stickyEvents = {}

    -- ============================================================================
    -- Internal: Replay sticky events for new subscribers
    -- ============================================================================

    local function replaySticky(busInstance, eventName, handlerFn)
        if not stickyEvents[eventName] then return end
        for _, entry in ipairs(stickyEvents[eventName]) do
            local ok, err = pcall(handlerFn, entry.payload)
            if not ok and logger then
                logger:LogError("eventbus", "Sticky replay handler for '%s' failed: %s", eventName, tostring(err))
            end
        end
    end

    -- ============================================================================
    -- On — Subscribe to an event
    -- ============================================================================

    function bus:On(eventName, handlerFn)
        if type(eventName) ~= "string" then
            if logger then logger:LogError("eventbus", "On: eventName must be a string, got %s", type(eventName)) end
            return nil
        end
        local normalized = normalizeHandler(handlerFn)
        if normalized == nil then
            if logger then
                logger:LogError("eventbus", "On: handler must be a function for event '%s', got %s",
                    tostring(eventName), type(handlerFn))
            end
            error(("DCE EventBus: On('%s', got %s) is invalid — handler must be a function"):format(
                tostring(eventName), type(handlerFn)), 2)
            return nil
        end
        handlerFn = normalized

        listenerCounter = listenerCounter + 1
        local id = listenerCounter

        if not listeners[eventName] then
            listeners[eventName] = {}
        end

        table.insert(listeners[eventName], { id = id, handler = handlerFn })

        -- Update canonical runtime state
        if runtimeState then
            if not runtimeState.eventListeners then runtimeState.eventListeners = {} end
            runtimeState.eventListeners[eventName] = #listeners[eventName]
        end

        -- Replay sticky events to this new subscriber
        replaySticky(self, eventName, handlerFn)

        if logger then logger:LogInfo("eventbus", "Listener registered for '%s' (id=%d)", eventName, id) end
        return id
    end

    -- ============================================================================
    -- Once — Subscribe to a single emission
    -- ============================================================================

    function bus:Once(eventName, handlerFn)
        if type(eventName) ~= "string" then
            if logger then logger:LogError("eventbus", "Once: eventName must be a string") end
            return nil
        end
        local normalized = normalizeHandler(handlerFn)
        if normalized == nil then
            if logger then
                logger:LogError("eventbus", "Once: handler must be a function for event '%s', got %s",
                    tostring(eventName), type(handlerFn))
            end
            error(("DCE EventBus: Once('%s', got %s) is invalid — handler must be a function"):format(
                tostring(eventName), type(handlerFn)), 2)
            return nil
        end
        handlerFn = normalized

        local wrapped
        local id
        wrapped = function(payload)
            handlerFn(payload)
            bus:Off(eventName, id)
        end
        id = bus:On(eventName, wrapped)
        return id
    end

    -- ============================================================================
    -- Off — Unsubscribe
    -- ============================================================================

    function bus:Off(eventName, handlerId)
        if not listeners[eventName] then return false end
        for i, listener in ipairs(listeners[eventName]) do
            if listener.id == handlerId then
                table.remove(listeners[eventName], i)
                if runtimeState and runtimeState.eventListeners then
                    runtimeState.eventListeners[eventName] = #listeners[eventName]
                    if #listeners[eventName] == 0 then
                        runtimeState.eventListeners[eventName] = nil
                    end
                end
                if logger then logger:LogInfo("eventbus", "Listener unregistered for '%s' (id=%d)", eventName, handlerId) end
                return true
            end
        end
        return false
    end

    -- ============================================================================
    -- Emit — Fire an event
    -- ============================================================================

    function bus:Emit(eventName, payload)
        if type(eventName) ~= "string" then
            if logger then logger:LogError("eventbus", "Emit: eventName must be a string") end
            return
        end

        -- Dispatch to all listeners
        if listeners[eventName] then
            local safeCopy = {}
            for _, listener in ipairs(listeners[eventName]) do
                table.insert(safeCopy, listener)
            end
            for _, listener in ipairs(safeCopy) do
                local ok, err = pcall(listener.handler, payload)
                if not ok and logger then
                    logger:LogError("eventbus", "Handler for '%s' failed: %s", eventName, tostring(err))
                end
            end
        end

        if logger then
            local count = listeners[eventName] and #listeners[eventName] or 0
            logger:LogInfo("eventbus", "Emitted '%s' to %d listener(s)", eventName, count)
        end
    end

    -- ============================================================================
    -- Sticky Lifecycle Events
    -- ============================================================================

    --- Mark an event as sticky. Subsequent On() subscribers will immediately
    --- receive the last emitted payload for sticky events.
    function bus:Sticky(eventName)
        if not stickyEvents[eventName] then
            stickyEvents[eventName] = {}
        end
    end

    --- Emit a sticky event. The payload is stored and replayed to future subscribers.
    function bus:EmitSticky(eventName, payload)
        if not stickyEvents[eventName] then
            stickyEvents[eventName] = {}
        end

        -- Store the event for replay
        table.insert(stickyEvents[eventName], {
            timestamp = now(),
            payload = payload,
        })

        -- Also emit normally
        bus:Emit(eventName, payload)
    end

    -- ============================================================================
    -- Query — Read-only introspection
    -- ============================================================================

    function bus:GetListenerCount(eventName)
        if listeners[eventName] then
            return #listeners[eventName]
        end
        return 0
    end

    function bus:ListEvents()
        local names = {}
        for k in pairs(listeners) do
            table.insert(names, k)
        end
        table.sort(names)
        return names
    end

    function bus:ListStickyEvents()
        local names = {}
        for k in pairs(stickyEvents) do
            table.insert(names, k)
        end
        table.sort(names)
        return names
    end

    -- ============================================================================
    -- Clear
    -- ============================================================================

    function bus:Clear()
        listeners = {}
        stickyEvents = {}
        if runtimeState and runtimeState.eventListeners then
            runtimeState.eventListeners = {}
        end
        if logger then logger:LogInfo("eventbus", "All listeners cleared") end
    end

    return bus
end

-- Registered on the server-only DCE_INTERNAL namespace.
DCE_INTERNAL = DCE_INTERNAL or {}
DCE_INTERNAL.EventBus = EventBus
