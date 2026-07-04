-- DCE Activity Model
-- Defines the structure of a criminal activity that organizations can perform.

local Activity = {}
Activity.__index = Activity

--- Create a new Activity definition.
---@param id string Activity type ID (e.g., "drug_sale")
---@param data table Activity configuration
---@return table Activity definition
function Activity.New(id, data)
    local self = setmetatable({}, Activity)

    self.id = id
    self.displayName = data.displayName or id
    self.type = data.type or "generic"
    self.baseWeight = data.baseWeight or 50
    self.minHeat = data.minHeat or 0
    self.maxHeat = data.maxHeat or 100
    self.minMembers = data.minMembers or 1
    self.durationMinutes = data.durationMinutes or 10
    self.heatOutput = data.heatOutput or 5
    self.violenceOutput = data.violenceOutput or 0
    self.moneyOutput = data.moneyOutput or 1000
    self.personalityAffinities = data.personalityAffinities or {}  -- traitName -> weight multiplier
    self.requiredState = data.requiredState or nil  -- organization state required, or nil for any
    self.forbiddenStates = data.forbiddenStates or {}  -- states that block this activity

    return self
end

--- Check if this activity is available for an organization in its current state.
---@param orgState string The organization's current state
---@return boolean
function Activity:IsAvailable(orgState)
    if self.requiredState and self.requiredState ~= orgState then
        return false
    end

    for _, forbidden in ipairs(self.forbiddenStates) do
        if forbidden == orgState then
            return false
        end
    end

    return true
end

--- Check if the organization meets the minimum requirements for this activity.
---@param orgRuntime table Organization runtime state
---@return boolean
function Activity:MeetsRequirements(orgRuntime)
    if orgRuntime.heat < self.minHeat or orgRuntime.heat > self.maxHeat then
        return false
    end

    if orgRuntime.members < self.minMembers then
        return false
    end

    return true
end

_G.DCEActivity = Activity
