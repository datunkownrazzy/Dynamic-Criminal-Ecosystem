-- DCE Registry — Sprint 1.11.3
--
-- Single canonical service registry.
-- No duplicate registrations.
-- No shadow copies.
-- Every service is registered exactly once.
---@diagnostic disable: undefined-global

local Registry = {}

function Registry:New(runtimeState, logger)
    local registry = {}
    local services = {}

    function registry:Register(name, serviceTable, options)
        if type(name) ~= "string" then
            if logger then logger:LogError("registry", "Register: name must be a string") end
            return false
        end
        if type(serviceTable) ~= "table" then
            if logger then logger:LogError("registry", "Register: serviceTable must be a table for '%s'", name) end
            return false
        end

        options = options or {}

        if services[name] and not options.override then
            if logger then logger:LogWarn("registry", "Service '%s' already registered (use override=true to force)", name) end
            return false
        end

        services[name] = { table = serviceTable, options = options }

        -- Update canonical runtime state
        if runtimeState then
            runtimeState.services[name] = serviceTable
        end

        if logger then logger:LogInfo("registry", "Service registered: %s", name) end
        return true
    end

    function registry:Get(name)
        local entry = services[name]
        if not entry then return nil end
        return entry.table
    end

    function registry:Has(name)
        return services[name] ~= nil
    end

    function registry:GetOrThrow(name)
        local entry = services[name]
        if not entry then
            error("DCE Registry: required service '" .. tostring(name) .. "' is not registered", 2)
        end
        return entry.table
    end

    function registry:Unregister(name)
        local entry = services[name]
        if not entry then return false end
        services[name] = nil
        if runtimeState then
            runtimeState.services[name] = nil
        end
        if logger then logger:LogInfo("registry", "Service unregistered: %s", name) end
        return true
    end

    function registry:List()
        local names = {}
        for k in pairs(services) do
            table.insert(names, k)
        end
        table.sort(names)
        return names
    end

    function registry:Clear()
        for name in pairs(services) do
            services[name] = nil
            if runtimeState then
                runtimeState.services[name] = nil
            end
        end
        if logger then logger:LogInfo("registry", "All services cleared") end
    end

    function registry:Count()
        local n = 0
        for _ in pairs(services) do n = n + 1 end
        return n
    end

    return registry
end

-- Registered on the server-only DCE_INTERNAL namespace.
DCE_INTERNAL = DCE_INTERNAL or {}
DCE_INTERNAL.Registry = Registry
