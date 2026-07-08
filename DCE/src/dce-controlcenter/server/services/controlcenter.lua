-- DCE Control Center Service v2
-- Core service for the Control Center operating system
-- Owns: NUI lifecycle, window management, plugin registry, event forwarding

local ControlCenterService = {}
local DCE = _G.DCE
local logger

-- Internal state
local subscriptions = {}      -- playerSource -> { [eventName] = fivemEvent }
local openSessions = {}       -- playerSource -> boolean (is CC open)
local windowStates = {}       -- playerSource -> { [windowId] = state }

--- Initialize the service
function ControlCenterService.Init(log)
    logger = log
    if logger then
        logger.Info("controlcenter", "Initializing Control Center v2...")
    end
end

--- Log helper
local function log(level, msg, ...)
    if logger then
        logger.Log("controlcenter", level, msg, ...)
    end
end

--- Check if a player has permission to use Control Center
---@param source number Player server ID
---@return boolean
function ControlCenterService.HasPermission(source)
    local Config = _G.Config or {}
    if Config.CC and Config.CC.Permissions then
        local permConfig = Config.CC.Permissions
        
        -- Custom permission function takes precedence
        if permConfig.CheckFunction and type(permConfig.CheckFunction) == "function" then
            return permConfig.CheckFunction(source)
        end
        
        -- Check ACE permissions
        if IsPlayerAceAllowed then
            for role, perms in pairs(permConfig.Roles or {}) do
                for _, perm in ipairs(perms) do
                    if IsPlayerAceAllowed(source, perm) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

--- Register a player's EventBus subscription
---@param source number Player server ID
---@param eventName string DCE event to subscribe to
---@return string|nil FiveM event name
function ControlCenterService.RegisterSubscription(source, eventName)
    if type(eventName) ~= "string" then
        return nil
    end
    
    if not subscriptions[source] then
        subscriptions[source] = {}
    end
    
    -- Use DCE_Subscribe to bridge the event
    if DCE and DCE_Subscribe then
        local fivemEvent = DCE_Subscribe(eventName)
        if fivemEvent then
            subscriptions[source][eventName] = fivemEvent
            return fivemEvent
        end
    end
    
    return nil
end

--- Remove a player's EventBus subscription
---@param source number Player server ID
---@param eventName string DCE event name
function ControlCenterService.UnregisterSubscription(source, eventName)
    if subscriptions[source] then
        subscriptions[source][eventName] = nil
    end
end

--- Forward an event to a specific player's NUI
---@param source number Player server ID
---@param eventName string Event name
---@param payload table Event payload
function ControlCenterService.ForwardEvent(source, eventName, payload)
    if not openSessions[source] then
        return -- Don't forward to closed sessions
    end
    
    TriggerClientEvent('dce-cc:client:eventbus', source, {
        eventName = eventName,
        payload = payload
    })
end

--- Request to open Control Center for a player
---@param source number Player server ID
---@param callback function Function to call on open
function ControlCenterService.RequestOpen(source, callback)
    if not ControlCenterService.HasPermission(source) then
        if callback then
            callback(false, "permission_denied")
        end
        return
    end
    
    -- Set session state
    openSessions[source] = true
    
    -- Send open request to client
    TriggerClientEvent('dce-cc:client:open', source)
    
    -- Log the action
    log("info", "Control Center opened for player %d", source)
    
    -- Emit event for audit trail
    if DCE and DCE.Emit then
        DCE.Emit("controlcenter:opened", {
            eventName = "controlcenter:opened",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-controlcenter",
            payload = {
                playerId = source,
            },
        })
    end
    
    if callback then
        callback(true)
    end
end

--- Request to close Control Center
---@param source number Player server ID
function ControlCenterService.RequestClose(source)
    if not openSessions[source] then
        return
    end
    
    openSessions[source] = false
    windowStates[source] = nil
    
    TriggerClientEvent('dce-cc:client:close', source)
    
    log("info", "Control Center closed for player %d", source)
    
    if DCE and DCE.Emit then
        DCE.Emit("controlcenter:closed", {
            eventName = "controlcenter:closed",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-controlcenter",
            payload = {
                playerId = source,
            },
        })
    end
end

--- Get list of all opened windows for a player
---@param source number Player server ID
---@return table Window states
function ControlCenterService.GetWindowStates(source)
    return windowStates[source] or {}
end

--- Update window state for a player
---@param source number Player server ID
---@param windowId string Window identifier
---@param state table Window state
function ControlCenterService.SetWindowState(source, windowId, state)
    if not windowStates[source] then
        windowStates[source] = {}
    end
    windowStates[source][windowId] = state
end

--- Get all registered plugins
---@return table Plugin list
function ControlCenterService.GetPlugins()
    local PluginRegistry = DCE and DCE.GetService and DCE.GetService("PluginRegistry")
    if PluginRegistry then
        return PluginRegistry.ListPlugins and PluginRegistry.ListPlugins() or {}
    end
    return {}
end

--- Get all services status
---@return table Service list
function ControlCenterService.GetServices()
    local CoreRegistry = DCE and DCE.GetService and DCE.GetService("CoreRegistry")
    if CoreRegistry then
        return CoreRegistry.ListServices and CoreRegistry.ListServices() or {}
    end
    return {}
end

--- Get profiler metrics
---@return table
function ControlCenterService.GetProfilerMetrics()
    local Profiler = DCEProfiler
    if Profiler then
        return Profiler.GetAllMetrics and Profiler.GetAllMetrics() or {}
    end
    return {}
end

--- Get event bus metrics
---@return table
function ControlCenterService.GetEventBusMetrics()
    local EventBus = DCE and DCE.GetService and DCE.GetService("EventBus")
    if EventBus then
        return EventBus.GetMetrics and EventBus.GetMetrics() or {}
    end
    return {}
end

--- Shutdown - clean up all subscriptions
function ControlCenterService.Shutdown()
    -- Clean up all player subscriptions
    for source, events in pairs(subscriptions) do
        for eventName, _ in pairs(events) do
            -- Remove event handlers
            -- (FiveM handles cleanup on resource stop, but be explicit)
        end
    end
    
    subscriptions = {}
    openSessions = {}
    windowStates = {}
    
    log("info", "Control Center service shut down")
end

return ControlCenterService