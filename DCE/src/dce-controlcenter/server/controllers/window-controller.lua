-- DCE Control Center v2 - Window Controller
-- Manages window state for the Control Center

local WindowController = {}
local logger

--- Initialize
function WindowController.Init(log)
    logger = log
end

--- Log helper
local function log(level, msg, ...)
    if logger then
        logger.Log("window-controller", level, msg, ...)
    end
end

--- Store window state for a player
---@param source number
---@param windowId string
---@param state table
function WindowController.SetWindowState(source, windowId, state)
    -- Window state is managed in ControlCenterService
    -- This controller handles business logic
end

--- Get window state for a player
---@param source number
---@param windowId string
---@return table|nil
function WindowController.GetWindowState(source, windowId)
    return nil
end

--- Reset all windows for a player
---@param source number
function WindowController.ResetWindows(source)
    -- Notify NUI to close all windows
    TriggerClientEvent('dce-cc:window:allClosed', source)
end

return WindowController