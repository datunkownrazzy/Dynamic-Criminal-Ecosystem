-- DCE Native Dispatch Adapter
-- Fallback implementation that works without any third-party CAD/MDT.
-- Provides basic in-game notifications and blips.

local NativeAdapter = {}

--- Get players safely
local function getPlayers()
    local players = {}
    local success, result = pcall(function()
        if GetPlayers then
            return GetPlayers()
        end
        return nil
    end)
    if success and result then
        players = result
    end
    return players
end

--- Get Config safely
local function getConfig()
    return _G.Config or {}
end

--- Create a dispatch call in the native UI.
---@param callData table Call summary
function NativeAdapter.CreateCall(callData)
    if not callData then
        return
    end

    local prefix = "[DCE Dispatch] "
    local Config = getConfig()
    if Config.Dispatch and Config.Dispatch.Native and Config.Dispatch.Native.NotificationPrefix then
        prefix = Config.Dispatch.Native.NotificationPrefix
    end

    -- Send notification to all police players
    local players = getPlayers()
    for _, playerId in ipairs(players) do
        TriggerClientEvent("chat:addMessage", playerId, {
            color = { 255, 0, 0 },
            multiline = true,
            args = {
                prefix .. "New Incident",
                string.format("Priority: %s\nType: %s\nLocation: %s\nCall ID: %s",
                    callData.priority or "medium",
                    callData.description or "Unknown",
                    callData.regionId or "Unknown",
                    callData.id or "Unknown"
                )
            }
        })
    end

    if DCE and DCE.Log then
        DCE.Log("dispatch", "info", "Native adapter: call %s dispatched to %d players",
            callData.id, #players)
    end
end

--- Update a dispatch call.
---@param callData table Call summary
function NativeAdapter.UpdateCall(callData)
    if not callData then
        return
    end

    local prefix = "[DCE Dispatch] "
    local Config = getConfig()
    if Config.Dispatch and Config.Dispatch.Native and Config.Dispatch.Native.NotificationPrefix then
        prefix = Config.Dispatch.Native.NotificationPrefix
    end

    local players = getPlayers()
    for _, playerId in ipairs(players) do
        TriggerClientEvent("chat:addMessage", playerId, {
            color = { 255, 165, 0 },
            multiline = true,
            args = {
                prefix .. "Call Updated",
                string.format("Call: %s\nStatus: %s\nUpdates: %d",
                    callData.id,
                    callData.status or "unknown",
                    callData.updateCount or 0
                )
            }
        })
    end
end

--- Resolve a dispatch call.
---@param callData table Call summary
function NativeAdapter.ResolveCall(callData)
    if not callData then
        return
    end

    local prefix = "[DCE Dispatch] "
    local Config = getConfig()
    if Config.Dispatch and Config.Dispatch.Native and Config.Dispatch.Native.NotificationPrefix then
        prefix = Config.Dispatch.Native.NotificationPrefix
    end

    local players = getPlayers()
    for _, playerId in ipairs(players) do
        TriggerClientEvent("chat:addMessage", playerId, {
            color = { 0, 255, 0 },
            multiline = true,
            args = {
                prefix .. "Call Resolved",
                string.format("Call: %s\nDisposition: %s",
                    callData.id,
                    callData.disposition or "Unknown"
                )
            }
        })
    end
end

--- Cancel a dispatch call.
---@param callData table Call summary
function NativeAdapter.CancelCall(callData)
    if not callData then
        return
    end

    local prefix = "[DCE Dispatch] "
    local Config = getConfig()
    if Config.Dispatch and Config.Dispatch.Native and Config.Dispatch.Native.NotificationPrefix then
        prefix = Config.Dispatch.Native.NotificationPrefix
    end

    local players = getPlayers()
    for _, playerId in ipairs(players) do
        TriggerClientEvent("chat:addMessage", playerId, {
            color = { 128, 128, 128 },
            args = {
                prefix .. "Call Cancelled",
                string.format("Call: %s has been cancelled", callData.id)
            }
        })
    end
end

--- Get diagnostics for the adapter.
---@return table Diagnostics information
function NativeAdapter.GetDiagnostics()
    return {
        status = "active",
        health = 100,
        latency = 0,
        queue = 0,
        errors = 0,
        lastCheck = os.time(),
        capabilities = { "CreateCall", "UpdateCall", "ResolveCall", "CancelCall" }
    }
end

--- Check if the adapter is available.
---@return boolean
function NativeAdapter.IsAvailable()
    return true
end

_G.DCENativeAdapter = NativeAdapter