-- DCE ERS (Extended Roleplay System) Dispatch Adapter
-- Provides integration with the ERS dispatch system.
-- Falls back gracefully if ERS is not available.

local ERSAdapter = {}

--- Create a new ERS adapter instance.
---@param config table Integration configuration
---@return table Adapter instance
function ERSAdapter.New(config)
    local self = {}
    self.config = config or {}
    self.available = false

    -- Check if ERS is available
    if GetResourceState("ers") == "started" then
        self.available = true
        DCE:Log("dispatch", "info", "ERS adapter: ERS resource detected and available")
    else
        DCE:Log("dispatch", "warn", "ERS adapter: ERS resource not found, running in standalone mode")
    end

    return self
end

--- Check if the adapter is available.
---@return boolean
function ERSAdapter.IsAvailable()
    return self.available
end

--- Create a dispatch call in ERS.
---@param callData table Call summary
function ERSAdapter.CreateCall(callData)
    if not self.available then
        return
    end

    if exports.ers and exports.ers.CreateDispatchCall then
        exports.ers.CreateDispatchCall(callData)
    end
end

--- Update a dispatch call in ERS.
---@param callData table Call summary
function ERSAdapter.UpdateCall(callData)
    if not self.available then
        return
    end

    if exports.ers and exports.ers.UpdateDispatchCall then
        exports.ers.UpdateDispatchCall(callData)
    end
end

--- Resolve a dispatch call in ERS.
---@param callData table Call summary
function ERSAdapter.ResolveCall(callData)
    if not self.available then
        return
    end

    if exports.ers and exports.ers.ResolveDispatchCall then
        exports.ers.ResolveDispatchCall(callData)
    end
end

--- Cancel a dispatch call in ERS.
---@param callData table Call summary
function ERSAdapter.CancelCall(callData)
    if not self.available then
        return
    end

    if exports.ers and exports.ers.CancelDispatchCall then
        exports.ers.CancelDispatchCall(callData)
    end
end

_G.DCERSAdapter = ERSAdapter