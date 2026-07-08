-- DCE Control Center v2 - Validatable Interface
-- Objects that support validation (locations, organizations, etc.)

local IValidatable = {}

--- Validate the object
---@return boolean valid, table errors
function IValidatable.Validate()
    error("IValidatable:Validate must be implemented")
end

--- Attempt to repair/validate errors
---@return table suggestions
function IValidatable.Repair()
    error("IValidatable:Repair must be implemented")
end

--- Normalize data to standard format
function IValidatable.Normalize()
    error("IValidatable:Normalize must be implemented")
end

--- Detect conflicts with other objects
---@return table conflicts
function IValidatable.DetectConflicts()
    error("IValidatable:DetectConflicts must be implemented")
end

--- Get warnings (non-blocking validation issues)
---@return table warnings
function IValidatable.Warnings()
    return {}
end

--- Get errors (blocking validation issues)
---@return table errors
function IValidatable.Errors()
    return {}
end

--- Get suggestions for improvement
---@return table suggestions
function IValidatable.Suggestions()
    return {}
end

return IValidatable