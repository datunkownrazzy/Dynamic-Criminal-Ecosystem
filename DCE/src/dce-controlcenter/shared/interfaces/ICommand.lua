-- DCE Control Center v2 - Command Interface
-- Undo/Redo commands for editor actions

---@class ICommand
local ICommand = {}

--- Execute the command
---@return boolean success
function ICommand.Execute()
    error("ICommand:Execute must be implemented")
end

--- Undo the command
---@return boolean success
function ICommand.Undo()
    error("ICommand:Undo must be implemented")
end

--- Redo the command
---@return boolean success
function ICommand.Redo()
    error("ICommand:Redo must be implemented")
end

--- Merge with another command (for batching)
---@param other ICommand
---@return boolean merged
function ICommand.Merge(other)
    return false
end

--- Serialize command for persistence
---@return table
function ICommand.Serialize()
    return {}
end

--- Get command description
---@return string
function ICommand.GetDescription()
    return "Unnamed command"
end

--- Get command type
---@return string
function ICommand.GetType()
    return "generic"
end

return ICommand