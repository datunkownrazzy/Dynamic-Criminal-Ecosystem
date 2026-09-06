-- DCE Config Manager — Sprint 1.11.3
--
-- Single canonical config manager.
-- Reads from _G.Config (loaded via fxmanifest shared_scripts).
-- No duplicate implementations.
---@diagnostic disable: undefined-global

local ConfigManager = {}

function ConfigManager:New(runtimeState, logger)
    local cm = {}

    function cm:Load(path)
        return _G.Config or {}
    end

    function cm:Get(key, default)
        local config = _G.Config or {}
        local parts = {}
        for part in (key or ""):gmatch("[^.]+") do
            table.insert(parts, part)
        end
        local value = config
        for _, part in ipairs(parts) do
            if value == nil then return default end
            if type(value) ~= "table" then return default end
            value = value[part]
        end
        if value == nil then return default end
        return value
    end

    function cm:GetAll()
        return _G.Config or {}
    end

    return cm
end

-- Registered on the server-only DCE_INTERNAL namespace.
DCE_INTERNAL = DCE_INTERNAL or {}
DCE_INTERNAL.ConfigManager = ConfigManager
