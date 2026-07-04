-- DCE Native Dispatch Adapter
-- Fallback implementation that works without any third-party CAD/MDT.
-- Provides basic in-game notifications and blips.

local NativeAdapter = {}

--- Create a dispatch call in the native UI.
---@param callData table Call summary
function NativeAdapter.CreateCall(callData)
    if not callData then
        return
    end

    local prefix = Config.Dispatch.Native.NotificationPrefix

    -- Send notification to all police players
    local players = GetPlayers()
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

    DCE.Log("dispatch", "info", "Native adapter: call %s dispatched to %d players",
        callData.id, #players)
end

--- Update a dispatch call.
---@param callData table Call summary
function NativeAdapter.UpdateCall(callData)
    if not callData then
        return
    end

    local prefix = Config.Dispatch.Native.NotificationPrefix

    local players = GetPlayers()
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

    local prefix = Config.Dispatch.Native.NotificationPrefix

    local players = GetPlayers()
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

    local prefix = Config.Dispatch.Native.NotificationPrefix

    local players = GetPlayers()
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

_G.DCENativeAdapter = NativeAdapter
