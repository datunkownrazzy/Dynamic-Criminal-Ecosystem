-- DCE Control Center v2 - Browser Manager Interface
-- Defines the contract for browser lifecycle operations
-- Owns ONLY browser operations - nothing else

---@class IBrowserManager
---@field browserId string|nil The active browser identifier
---@field state string Current browser state ("unloaded", "ready", "activated", "suspended")
local IBrowserManager = {}

--- Create a new browser instance (FiveM handles actual creation)
--- Returns identifier for tracking
---@return string browserId
function IBrowserManager.Create()
    error("IBrowserManager.Create must be implemented")
end

--- Activate the browser for a session (grant focus)
--- Called by SessionManager when player opens CC
---@param sessionId string
---@return boolean success
function IBrowserManager.Activate(sessionId)
    error("IBrowserManager.Activate must be implemented")
end

--- Suspend the browser (release focus)
--- Called by SessionManager when player closes CC
---@param sessionId string
---@return boolean success
function IBrowserManager.Suspend(sessionId)
    error("IBrowserManager.Suspend must be implemented")
end

--- Destroy the browser (cleanup on resource stop)
---@return boolean success
function IBrowserManager.Destroy()
    error("IBrowserManager.Destroy must be implemented")
end

--- Check if browser is in a valid state
---@return boolean
function IBrowserManager.IsReady()
    error("IBrowserManager.IsReady must be implemented")
end

--- Ensure clean state (release any auto-granted focus)
--- Called once on NUI loaded
---@return boolean success
function IBrowserManager.EnsureCleanState()
    error("IBrowserManager.EnsureCleanState must be implemented")
end

return IBrowserManager