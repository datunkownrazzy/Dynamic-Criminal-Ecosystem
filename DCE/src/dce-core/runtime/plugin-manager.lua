-- DCE Plugin Manager — Sprint 1.11.3
--
-- Single canonical plugin manager.
-- No duplicate registrations.
---@diagnostic disable: undefined-global

local PluginManager = {}

function PluginManager:New(runtimeState, logger)
    local pm = {}
    local plugins = {}

    function pm:Register(manifest)
        if type(manifest) ~= "table" then
            if logger then logger:LogError("plugin", "Register: manifest must be a table") end
            return false
        end
        if type(manifest.name) ~= "string" then
            if logger then logger:LogError("plugin", "Register: manifest must have a 'name' field (string)") end
            return false
        end

        if plugins[manifest.name] then
            if logger then logger:LogWarn("plugin", "Plugin '%s' already registered", manifest.name) end
            return false
        end

        plugins[manifest.name] = manifest

        -- Update canonical runtime state
        if runtimeState then
            runtimeState.plugins[manifest.name] = manifest
        end

        if logger then logger:LogInfo("plugin", "Plugin registered: %s v%s", manifest.name, manifest.version or "1.0") end
        return true
    end

    function pm:Unregister(name)
        if plugins[name] then
            plugins[name] = nil
            if runtimeState then
                runtimeState.plugins[name] = nil
            end
            if logger then logger:LogInfo("plugin", "Plugin unregistered: %s", name) end
            return true
        end
        return false
    end

    function pm:Get(name)
        return plugins[name]
    end

    function pm:List()
        local names = {}
        for k in pairs(plugins) do
            table.insert(names, k)
        end
        table.sort(names)
        return names
    end

    function pm:Count()
        local n = 0
        for _ in pairs(plugins) do n = n + 1 end
        return n
    end

    function pm:Clear()
        for k in pairs(plugins) do
            plugins[k] = nil
            if runtimeState then
                runtimeState.plugins[k] = nil
            end
        end
        if logger then logger:LogInfo("plugin", "All plugins cleared") end
    end

    return pm
end

-- Registered on the server-only DCE_INTERNAL namespace.
DCE_INTERNAL = DCE_INTERNAL or {}
DCE_INTERNAL.PluginManager = PluginManager
