-- DCE Control Center v2 - Session Interface
-- Defines the contract for session lifecycle management

---@class ISession
---@field sessionId string Unique identifier for this session
---@field playerSource number The player who owns this session
---@field state string Current session state ("created", "booting", "active", "lingering", "destroyed")
---@field createdAt number Timestamp when session was created
---@field focusAcquiredAt number|nil Timestamp when focus was granted
---@field focusReleasedAt number|nil Timestamp when focus was released
local ISession = {}

--- Create a new session for a player
---@param playerSource number The player server ID
---@return ISession
function ISession.Create(playerSource)
    error("ISession.Create must be implemented")
end

--- Get session state
---@return string state
function ISession.GetState()
    error("ISession.GetState must be implemented")
end

--- Transition session to a new state
---@param newState string
---@return boolean success
function ISession.Transition(newState)
    error("ISession.Transition must be implemented")
end

--- Cleanup and destroy session
---@return boolean success
function ISession.Destroy()
    error("ISession.Destroy must be implemented")
end

--- Check if session has focus
---@return boolean
function ISession.HasFocus()
    error("ISession.HasFocus must be implemented")
end

return ISession