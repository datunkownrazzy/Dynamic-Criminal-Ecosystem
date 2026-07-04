-- DCE Service Registry
-- How modules find each other without hardcoding dependencies.
-- Spec: DCE-0001

local Registry = {}
local services = {}  -- name -> { table, options }
local logger

--- Initialize the registry with a reference to the logger.
function Registry.Init(log)
    logger = log
end

--- Log a message through the logger if available.
local function log(level, module, message, ...)
    if logger then
        logger.Log(module, level, message, ...)
    end
end

--- Register a service with the registry.
---@param name string Service name (e.g., "World", "Dispatch", "Evidence")
---@param serviceTable table The service's public interface
---@param options table|nil { override = boolean }
---@return boolean success Whether registration succeeded
function Registry.Register(name, serviceTable, options)
    if not name or type(name) ~= "string" then
        log("error", "core", "Registry.Register: name must be a string, got %s", type(name))
        return false
    end

    if not serviceTable or type(serviceTable) ~= "table" then
        log("error", "core", "Registry.Register: serviceTable must be a table for '%s'", name)
        return false
    end

    options = options or {}

    if services[name] and not options.override then
        log("warn", "core", "Registry.Register: service '%s' already registered. Use override=true to replace.", name)
        return false
    end

    if services[name] and options.override then
        log("info", "core", "Registry.Register: overriding existing service '%s'", name)
    end

    services[name] = { table = serviceTable, options = options }

    if Config.Registry.LogRegistrations then
        log("info", "core", "Service registered: %s", name)
    end

    -- Emit event on the bus if available (bus may not be initialized yet during startup)
    if DCE and DCE.Emit then
        DCE:Emit("service:registered:" .. name, {
            eventName = "service:registered:" .. name,
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-core",
            payload = { serviceName = name },
        })
    end

    return true
end

--- Resolve a service by name.
---@param name string Service name
---@return table|nil The service table, or nil if not registered
function Registry.Get(name)
    local entry = services[name]
    if not entry then
        return nil
    end
    return entry.table
end

--- Check if a service is registered.
---@param name string Service name
---@return boolean
function Registry.Has(name)
    return services[name] ~= nil
end

--- Resolve a service or throw an error.
---@param name string Service name
---@return table The service table
function Registry.GetOrThrow(name)
    local entry = services[name]
    if not entry then
        error("DCE Service Registry: required service '" .. name .. "' is not registered")
    end
    return entry.table
end

--- Unregister a service. Used on resource stop/restart.
---@param name string Service name
---@return boolean success
function Registry.Unregister(name)
    if not services[name] then
        log("warn", "core", "Registry.Unregister: service '%s' is not registered", name)
        return false
    end

    services[name] = nil

    if Config.Registry.LogRegistrations then
        log("info", "core", "Service unregistered: %s", name)
    end

    if DCE and DCE.Emit then
        DCE:Emit("service:unregistered:" .. name, {
            eventName = "service:unregistered:" .. name,
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-core",
            payload = { serviceName = name },
        })
    end

    return true
end

--- Get a list of all registered service names.
---@return table Array of service name strings
function Registry.List()
    local names = {}
    for name, _ in pairs(services) do
        table.insert(names, name)
    end
    return names
end

--- Unregister all services. Called during shutdown.
function Registry.Clear()
    for name, _ in pairs(services) do
        Registry.Unregister(name)
    end
end

_G.DCERegistry = Registry
