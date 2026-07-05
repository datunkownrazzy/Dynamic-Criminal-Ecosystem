-- DCE ERS (Extended Roleplay System) Dispatch Adapter
-- Provides integration with the ERS dispatch system.
-- Falls back gracefully if ERS is not available.

local ERSAdapter = {}
ERSAdapter.__index = ERSAdapter

-- Store available state at module level for static access
local available = false

--- Create a new ERS adapter instance.
---@param config table Integration configuration
---@return table Adapter instance
function ERSAdapter.New(config)
    local self = setmetatable({}, ERSAdapter)
    self.config = config or {}

    -- Get ERS resource name from config (defaults to "ers")
    local Config = _G.Config or {}
    local ersConfig = (Config.Dispatch and Config.Dispatch.Integration) or {}
    local resourceName = ersConfig.ResourceName or "ers"

    -- Check if ERS is available at runtime
    if GetResourceState and GetResourceState(resourceName) == "started" then
        available = true
        self.available = true
        if DCE and DCE.Log then
            DCE.Log("dispatch", "info", "ERS adapter: ERS resource detected and available")
        end
    else
        if DCE and DCE.Log then
            DCE.Log("dispatch", "warn", "ERS adapter: ERS resource not found, running in standalone mode")
        end
    end

    return self
end

--- Check if the adapter is available.
---@return boolean
function ERSAdapter.IsAvailable()
    return available
end

--- Create a dispatch call in ERS.
---@param callData table Call summary
---@return boolean
function ERSAdapter.CreateCall(callData)
    if not available then
        return false
    end

    if exports and exports.ers and exports.ers.CreateDispatchCall then
        exports.ers.CreateDispatchCall(callData)
    end
    return true
end

--- Update a dispatch call in ERS.
---@param callData table Call summary
---@return boolean
function ERSAdapter.UpdateCall(callData)
    if not available then
        return false
    end

    if exports and exports.ers and exports.ers.UpdateDispatchCall then
        exports.ers.UpdateDispatchCall(callData)
    end
    return true
end

--- Resolve a dispatch call in ERS.
---@param callData table Call summary
---@return boolean
function ERSAdapter.ResolveCall(callData)
    if not available then
        return false
    end

    if exports and exports.ers and exports.ers.ResolveDispatchCall then
        exports.ers.ResolveDispatchCall(callData)
    end
    return true
end

--- Cancel a dispatch call in ERS.
---@param callData table Call summary
---@return boolean
function ERSAdapter.CancelCall(callData)
    if not available then
        return false
    end

    if exports and exports.ers and exports.ers.CancelDispatchCall then
        exports.ers.CancelDispatchCall(callData)
    end
    return true
end

_G.DCERSAdapter = ERSAdapter