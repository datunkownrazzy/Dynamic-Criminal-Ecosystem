-- DCE Resource Lifecycle — Sprint 1.9
-- Every DCE resource must use one lifecycle.
-- No custom lifecycle states.
--
-- States:
--   UNKNOWN     — Resource not yet discovered
--   DISCOVERED  — Resource found in resource list
--   LOADING     — Resource scripts are loading
--   INITIALIZED — Resource initialized core services
--   READY       — Resource is fully operational
--   RUNNING     — Resource is actively processing
--   DEGRADED    — Resource is operational but degraded
--   STOPPING    — Resource is shutting down
--   STOPPED     — Resource has stopped
--   FAILED      — Resource encountered a fatal error
---@diagnostic disable: undefined-global

local ResourceLifecycle = {}

-- ============================================================================
-- States
-- ============================================================================

local State = {
    UNKNOWN     = "UNKNOWN",
    DISCOVERED  = "DISCOVERED",
    LOADING     = "LOADING",
    INITIALIZED = "INITIALIZED",
    READY       = "READY",
    RUNNING     = "RUNNING",
    DEGRADED    = "DEGRADED",
    STOPPING    = "STOPPING",
    STOPPED     = "STOPPED",
    FAILED      = "FAILED",
}

local VALID_TRANSITIONS = {
    [State.UNKNOWN]     = { State.DISCOVERED, State.FAILED },
    [State.DISCOVERED]  = { State.LOADING, State.FAILED },
    [State.LOADING]     = { State.INITIALIZED, State.FAILED },
    [State.INITIALIZED] = { State.READY, State.DEGRADED, State.STOPPING, State.FAILED },
    [State.READY]       = { State.RUNNING, State.DEGRADED, State.STOPPING, State.FAILED },
    [State.RUNNING]     = { State.READY, State.DEGRADED, State.STOPPING, State.FAILED },
    [State.DEGRADED]    = { State.READY, State.RUNNING, State.STOPPING, State.FAILED },
    [State.STOPPING]    = { State.STOPPED, State.FAILED },
    [State.STOPPED]     = { State.DISCOVERED, State.FAILED },
    [State.FAILED]      = { State.DISCOVERED, State.STOPPED },
}

-- ============================================================================
-- Resource Instances
-- ============================================================================

local resources = {}

--- Create or update a resource state
---@param name string Resource name
---@return table Resource state
function ResourceLifecycle.Track(name)
    if not resources[name] then
        resources[name] = {
            name = name,
            state = State.UNKNOWN,
            transitions = {},
            errors = {},
            metadata = {},
            startedAt = nil,
            stoppedAt = nil,
        }
    end
    return resources[name]
end

--- Transition a resource to a new state
---@param name string Resource name
---@param target string Target state
---@param reason string|nil Reason for transition
---@return boolean success, string|nil error
function ResourceLifecycle.Transition(name, target, reason)
    local resource = ResourceLifecycle.Track(name)
    local from = resource.state

    -- Allow any transition from UNKNOWN
    if from ~= State.UNKNOWN then
        local allowed = VALID_TRANSITIONS[from]
        if not allowed then
            return false, string.format("No transitions defined from %s", from)
        end
        local valid = false
        for _, s in ipairs(allowed) do
            if s == target then valid = true break end
        end
        if not valid then
            return false, string.format("Invalid transition: %s -> %s for resource '%s'",
                from, target, name)
        end
    end

    resource.state = target
    table.insert(resource.transitions, {
        from = from,
        to = target,
        time = os.time(),
        reason = reason or "",
    })

    if target == State.RUNNING or target == State.READY then
        resource.startedAt = os.time()
    elseif target == State.STOPPED or target == State.FAILED then
        resource.stoppedAt = os.time()
    end

    -- Emit lifecycle event
    local dce = _G.DCE
    if dce and dce.Emit then
        dce.Emit("lifecycle:resource:stateChanged", {
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-core",
            payload = {
                resource = name,
                from = from,
                to = target,
                reason = reason or "",
            },
        })
    end

    return true
end

--- Get the current state of a resource
---@param name string Resource name
---@return string|nil
function ResourceLifecycle.GetState(name)
    local resource = resources[name]
    if not resource then return nil end
    return resource.state
end

--- Get all tracked resources
---@return table
function ResourceLifecycle.List()
    local list = {}
    for name, resource in pairs(resources) do
        table.insert(list, {
            name = name,
            state = resource.state,
            transitions = #resource.transitions,
            errors = #resource.errors,
            startedAt = resource.startedAt,
            stoppedAt = resource.stoppedAt,
        })
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

--- Record an error for a resource
---@param name string Resource name
---@param message string Error message
function ResourceLifecycle.RecordError(name, message)
    local resource = ResourceLifecycle.Track(name)
    table.insert(resource.errors, {
        time = os.time(),
        message = message,
    })
end

--- Set metadata for a resource
---@param name string Resource name
---@param key string Metadata key
---@param value any Metadata value
function ResourceLifecycle.SetMetadata(name, key, value)
    local resource = ResourceLifecycle.Track(name)
    resource.metadata[key] = value
end

--- Get metadata for a resource
---@param name string Resource name
---@param key string Metadata key
---@return any
function ResourceLifecycle.GetMetadata(name, key)
    local resource = resources[name]
    if not resource then return nil end
    return resource.metadata[key]
end

--- Reset all resource tracking
function ResourceLifecycle.Reset()
    resources = {}
end

--- Get all valid states
---@return table
function ResourceLifecycle.GetStates()
    return State
end

-- ============================================================================
-- Register
-- ============================================================================

_G.DCEResourceLifecycle = ResourceLifecycle
return ResourceLifecycle