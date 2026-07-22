-- DCE Service Lifecycle Framework — Sprint 1.9
-- Standardizes every service lifecycle.
-- Every service must support:
--   Initialize()  — allocate resources, validate dependencies
--   Start()       — begin processing, register event handlers
--   Ready()       — signal readiness, emit ready event
--   Shutdown()    — graceful stop, flush pending work
--   Dispose()     — release all resources
--   Restart()     — full restart cycle
--   FailureRecovery() — attempt recovery from degraded state
--
-- The registry must understand lifecycle transitions.
-- No service should transition directly from INITIALIZED to RUNNING.
---@diagnostic disable: undefined-global

local ServiceLifecycle = {}

-- ============================================================================
-- Lifecycle States
-- ============================================================================

local State = {
    UNKNOWN      = "UNKNOWN",
    CREATED      = "CREATED",
    INITIALIZED  = "INITIALIZED",
    STARTING     = "STARTING",
    RUNNING      = "RUNNING",
    READY        = "READY",
    DEGRADED     = "DEGRADED",
    STOPPING     = "STOPPING",
    STOPPED      = "STOPPED",
    FAILED       = "FAILED",
}

-- Valid transitions
local VALID_TRANSITIONS = {
    [State.UNKNOWN]     = { State.CREATED },
    [State.CREATED]     = { State.INITIALIZED, State.FAILED },
    [State.INITIALIZED] = { State.STARTING, State.STOPPED, State.FAILED },
    [State.STARTING]    = { State.RUNNING, State.DEGRADED, State.FAILED },
    [State.RUNNING]     = { State.READY, State.DEGRADED, State.STOPPING, State.FAILED },
    [State.READY]       = { State.RUNNING, State.DEGRADED, State.STOPPING, State.FAILED },
    [State.DEGRADED]    = { State.RUNNING, State.STOPPING, State.FAILED },
    [State.STOPPING]    = { State.STOPPED, State.FAILED },
    [State.STOPPED]     = { State.INITIALIZED, State.CREATED, State.FAILED },
    [State.FAILED]      = { State.CREATED, State.STOPPED },
}

-- ============================================================================
-- Service Instance
-- ============================================================================

local serviceInstances = {}
local serviceIndex = 0

--- Create a new service instance with lifecycle management
---@param name string Service name
---@param implementation table Service implementation with lifecycle methods
---@return table Service instance
function ServiceLifecycle.Create(name, implementation)
    serviceIndex = serviceIndex + 1
    local id = serviceIndex

    local instance = {
        id = id,
        name = name,
        state = State.CREATED,
        implementation = implementation or {},
        createdAt = os.time(),
        lastTransition = os.time(),
        transitionHistory = {},
        errors = {},
    }

    -- Copy implementation methods
    for k, v in pairs(implementation or {}) do
        instance[k] = v
    end

    serviceInstances[name] = instance
    serviceInstances[id] = instance

    return instance
end

-- ============================================================================
-- State Transitions
-- ============================================================================

local function isValidTransition(current, target)
    local allowed = VALID_TRANSITIONS[current]
    if not allowed then return false end
    for _, state in ipairs(allowed) do
        if state == target then return true end
    end
    return false
end

local function transitionTo(instance, target, reason)
    if not isValidTransition(instance.state, target) then
        local msg = string.format("Invalid transition: %s -> %s for service '%s'",
            instance.state, target, instance.name)
        table.insert(instance.errors, { time = os.time(), message = msg })
        return false, msg
    end

    local from = instance.state
    instance.state = target
    instance.lastTransition = os.time()

    table.insert(instance.transitionHistory, {
        from = from,
        to = target,
        time = os.time(),
        reason = reason or "",
    })

    -- Emit lifecycle event
    local dce = _G.DCE
    if dce and dce.Emit then
        dce.Emit("lifecycle:service:stateChanged", {
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-core",
            payload = {
                service = instance.name,
                from = from,
                to = target,
                reason = reason or "",
            },
        })
    end

    return true
end

-- ============================================================================
-- Lifecycle Methods
-- ============================================================================

--- Initialize the service
---@param ... any Additional arguments passed to implementation.Initialize
---@return boolean success, string|nil error
function ServiceLifecycle.Initialize(name, ...)
    local instance = serviceInstances[name]
    if not instance then return false, "Service not found: " .. name end

    local ok, err = transitionTo(instance, State.INITIALIZED, "Initialize() called")
    if not ok then return false, err end

    if instance.implementation.Initialize then
        local implOk, implErr = pcall(instance.implementation.Initialize, ...)
        if not implOk then
            transitionTo(instance, State.FAILED, "Initialize() failed: " .. tostring(implErr))
            return false, tostring(implErr)
        end
    end

    return true
end

--- Start the service
---@param ... any Additional arguments passed to implementation.Start
---@return boolean success, string|nil error
function ServiceLifecycle.Start(name, ...)
    local instance = serviceInstances[name]
    if not instance then return false, "Service not found: " .. name end

    local ok, err = transitionTo(instance, State.STARTING, "Start() called")
    if not ok then return false, err end

    if instance.implementation.Start then
        local implOk, implErr = pcall(instance.implementation.Start, ...)
        if not implOk then
            transitionTo(instance, State.FAILED, "Start() failed: " .. tostring(implErr))
            return false, tostring(implErr)
        end
    end

    ok, err = transitionTo(instance, State.RUNNING, "Start() completed")
    if not ok then return false, err end

    return true
end

--- Mark the service as ready
---@return boolean success, string|nil error
function ServiceLifecycle.Ready(name)
    local instance = serviceInstances[name]
    if not instance then return false, "Service not found: " .. name end

    local ok, err = transitionTo(instance, State.READY, "Ready() called")
    if not ok then return false, err end

    if instance.implementation.Ready then
        local implOk, implErr = pcall(instance.implementation.Ready)
        if not implOk then
            transitionTo(instance, State.DEGRADED, "Ready() failed: " .. tostring(implErr))
            return false, tostring(implErr)
        end
    end

    return true
end

--- Shutdown the service gracefully
---@return boolean success, string|nil error
function ServiceLifecycle.Shutdown(name)
    local instance = serviceInstances[name]
    if not instance then return false, "Service not found: " .. name end

    local ok, err = transitionTo(instance, State.STOPPING, "Shutdown() called")
    if not ok then return false, err end

    if instance.implementation.Shutdown then
        local implOk, implErr = pcall(instance.implementation.Shutdown)
        if not implOk then
            transitionTo(instance, State.FAILED, "Shutdown() failed: " .. tostring(implErr))
            return false, tostring(implErr)
        end
    end

    ok, err = transitionTo(instance, State.STOPPED, "Shutdown() completed")
    if not ok then return false, err end

    return true
end

--- Dispose all resources
---@return boolean success, string|nil error
function ServiceLifecycle.Dispose(name)
    local instance = serviceInstances[name]
    if not instance then return false, "Service not found: " .. name end

    if instance.implementation.Dispose then
        local implOk, implErr = pcall(instance.implementation.Dispose)
        if not implOk then
            return false, tostring(implErr)
        end
    end

    -- Remove from registry
    serviceInstances[name] = nil
    serviceInstances[instance.id] = nil

    return true
end

--- Restart the service (full cycle)
---@param ... any Additional arguments passed to Initialize/Start
---@return boolean success, string|nil error
function ServiceLifecycle.Restart(name, ...)
    local ok, err = ServiceLifecycle.Shutdown(name)
    if not ok then return false, err end

    ok, err = ServiceLifecycle.Initialize(name, ...)
    if not ok then return false, err end

    ok, err = ServiceLifecycle.Start(name, ...)
    if not ok then return false, err end

    ok, err = ServiceLifecycle.Ready(name)
    if not ok then return false, err end

    return true
end

--- Attempt recovery from degraded state
---@param name string Service name
---@return boolean success, string|nil error
function ServiceLifecycle.FailureRecovery(name)
    local instance = serviceInstances[name]
    if not instance then return false, "Service not found: " .. name end

    if instance.state ~= State.DEGRADED and instance.state ~= State.FAILED then
        return false, "Service is not in a recoverable state: " .. instance.state
    end

    if instance.implementation.FailureRecovery then
        local implOk, implErr = pcall(instance.implementation.FailureRecovery)
        if not implOk then
            return false, tostring(implErr)
        end
    end

    -- Attempt to return to RUNNING
    local ok, err = transitionTo(instance, State.RUNNING, "FailureRecovery() succeeded")
    if not ok then return false, err end

    return true
end

-- ============================================================================
-- Query Methods
-- ============================================================================

--- Get the current state of a service
---@param name string Service name
---@return string|nil State or nil if not found
function ServiceLifecycle.GetState(name)
    local instance = serviceInstances[name]
    if not instance then return nil end
    return instance.state
end

--- Get all registered services
---@return table List of service instances
function ServiceLifecycle.ListServices()
    local list = {}
    for name, instance in pairs(serviceInstances) do
        if type(name) == "string" then
            table.insert(list, {
                name = name,
                state = instance.state,
                createdAt = instance.createdAt,
                lastTransition = instance.lastTransition,
                errorCount = #instance.errors,
            })
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

--- Get transition history for a service
---@param name string Service name
---@return table List of transitions
function ServiceLifecycle.GetHistory(name)
    local instance = serviceInstances[name]
    if not instance then return {} end
    return instance.transitionHistory
end

--- Get errors for a service
---@param name string Service name
---@return table List of errors
function ServiceLifecycle.GetErrors(name)
    local instance = serviceInstances[name]
    if not instance then return {} end
    return instance.errors
end

--- Check if a transition is valid
---@param from string Current state
---@param to string Target state
---@return boolean
function ServiceLifecycle.IsValidTransition(from, to)
    return isValidTransition(from, to)
end

--- Get all valid states
---@return table
function ServiceLifecycle.GetStates()
    return State
end

-- ============================================================================
-- Registry Integration
-- ============================================================================

--- Register a service with lifecycle management
---@param name string Service name
---@param implementation table Service implementation
---@return boolean success, string|nil error
function ServiceLifecycle.Register(name, implementation)
    if serviceInstances[name] then
        return false, "Service already registered: " .. name
    end

    local instance = ServiceLifecycle.Create(name, implementation)

    -- Register with DCE service registry
    local dce = _G.DCE
    if dce and dce.RegisterService then
        dce.RegisterService(name, {
            GetState = function() return instance.state end,
            GetLifecycle = function() return instance end,
            Initialize = function(...) return ServiceLifecycle.Initialize(name, ...) end,
            Start = function(...) return ServiceLifecycle.Start(name, ...) end,
            Ready = function() return ServiceLifecycle.Ready(name) end,
            Shutdown = function() return ServiceLifecycle.Shutdown(name) end,
            Dispose = function() return ServiceLifecycle.Dispose(name) end,
            Restart = function(...) return ServiceLifecycle.Restart(name, ...) end,
            FailureRecovery = function() return ServiceLifecycle.FailureRecovery(name) end,
        })
    end

    return true
end

-- ============================================================================
-- Shutdown All
-- ============================================================================

--- Shutdown all lifecycle-managed services
function ServiceLifecycle.ShutdownAll()
    local services = ServiceLifecycle.ListServices()
    -- Shutdown in reverse order (last registered first)
    for i = #services, 1, -1 do
        local svc = services[i]
        if svc.state == State.RUNNING or svc.state == State.READY or svc.state == State.DEGRADED then
            ServiceLifecycle.Shutdown(svc.name)
        end
    end
end

-- ============================================================================
-- Register
-- ============================================================================

_G.DCEServiceLifecycle = ServiceLifecycle
return ServiceLifecycle