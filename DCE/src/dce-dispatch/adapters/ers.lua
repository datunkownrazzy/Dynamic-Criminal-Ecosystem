-- DCE ERS Dispatch Adapter
-- Provides integration with the ERS CAD/MDT system.
-- Falls back gracefully if ERS is not available.

local ERSAdapter = {}
ERSAdapter.__index = ERSAdapter

--- Create a new ERS adapter instance.
---@param config table Integration configuration
---@return table Adapter instance
function ERSAdapter.New(config)
    local self = setmetatable({}, ERSAdapter)
    self.config = config or {}
    self.available = false
    self._errors = 0
    self._lastCheck = os.time()

    -- Get ERS resource name from config (defaults to "ers")
    local Config = _G.Config or {}
    local ersConfig = (Config.Dispatch and Config.Dispatch.Integration) or {}
    local resourceName = ersConfig.ResourceName or "ers"

    -- Check if ERS is available at runtime
    if GetResourceState and GetResourceState(resourceName) == "started" then
        self.available = true
        if DCE and DCE.Log then
            DCE.Log("dispatch", "info", "ERS dispatch adapter: ERS resource detected and available")
        end
    else
        if DCE and DCE.Log then
            DCE.Log("dispatch", "warn", "ERS dispatch adapter: ERS resource not found, using native adapter")
        end
    end

    return self
end

--- Check if the adapter is available.
---@return boolean
function ERSAdapter:IsAvailable()
    return self.available
end

--- Create a dispatch call in ERS.
---@param callData table Call summary
function ERSAdapter:CreateCall(callData)
    if not self.available then
        return
    end

    if exports and exports.ers and exports.ers.CreateDispatchCall then
        exports.ers.CreateDispatchCall(callData)
    end
end

--- Update a dispatch call in ERS.
---@param callData table Call summary
function ERSAdapter:UpdateCall(callData)
    if not self.available then
        return
    end

    if exports and exports.ers and exports.ers.UpdateDispatchCall then
        exports.ers.UpdateDispatchCall(callData)
    end
end

--- Resolve a dispatch call in ERS.
---@param callData table Call summary
function ERSAdapter:ResolveCall(callData)
    if not self.available then
        return
    end

    if exports and exports.ers and exports.ers.ResolveDispatchCall then
        exports.ers.ResolveDispatchCall(callData)
    end
end

--- Cancel a dispatch call in ERS.
---@param callData table Call summary
function ERSAdapter:CancelCall(callData)
    if not self.available then
        return
    end

    if exports and exports.ers and exports.ers.CancelDispatchCall then
        exports.ers.CancelDispatchCall(callData)
    end
end

--- Get diagnostics for the adapter.
---@return table Diagnostics information
function ERSAdapter:GetDiagnostics()
    return {
        status = self.available and "active" or "inactive",
        health = self.available and 100 or 0,
        latency = 0,
        queue = 0,
        errors = self._errors,
        lastCheck = self._lastCheck,
        capabilities = { "CreateCall", "UpdateCall", "ResolveCall", "CancelCall" }
    }
end

--- Health check for the adapter.
---@return boolean success
function ERSAdapter:HealthCheck()
    self._lastCheck = os.time()
    local wasAvailable = self.available

    if GetResourceState and GetResourceState(self.config.ResourceName or "ers") == "started" then
        self.available = true
        if DCE and DCE.Log and not wasAvailable then
            DCE.Log("dispatch", "info", "ERS dispatch adapter: Connection restored")
        end
    else
        self.available = false
        if DCE and DCE.Log and wasAvailable then
            DCE.Log("dispatch", "warn", "ERS dispatch adapter: Connection lost")
        end
    end

    return self.available
end

_G.DCEERSDispatchAdapter = ERSAdapter
