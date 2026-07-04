-- DCE Organization Model
-- Organization identity, runtime state, leadership, and state machine.
-- Spec: docs/05_Organizations/Organizations.md

local Organization = {}
Organization.__index = Organization

-- Organization state machine enum
Organization.States = {
    Dormant = "Dormant",
    Growing = "Growing",
    Stable = "Stable",
    AggressiveExpansion = "Aggressive Expansion",
    Conflict = "Conflict",
    UnderInvestigation = "Under Investigation",
    Suppressed = "Suppressed",
    Recovering = "Recovering",
}

--- Create a new Organization instance.
---@param id string Organization ID
---@param data table Static organization definition data
---@return table Organization instance
function Organization.New(id, data)
    local self = setmetatable({}, Organization)

    -- Static identity (from data files)
    self.id = id
    self.displayName = data.displayName or id
    self.personality = data.personality or {
        violence = 50,
        drugTrade = 50,
        extortion = 50,
        smuggling = 50,
        recruitment = 50,
        territorial = 50,
        planning = 50,
    }

    -- Runtime state
    self.runtime = {
        money = Config.AI.Organization.DefaultMoney,
        members = Config.AI.Organization.DefaultMembers,
        vehicles = {},
        safehouses = {},
        territories = {},
        heat = Config.AI.Organization.DefaultHeat,
        influence = Config.AI.Organization.DefaultInfluence,
        morale = Config.AI.Organization.DefaultMorale,
        intelligence = 0,  -- police-held intelligence on this org
        state = Config.AI.Organization.DefaultState,
        lastStateChange = 0,
        suppressedSince = 0,
    }

    -- Leadership hierarchy
    self.leadership = {
        boss = nil,
        underboss = nil,
        lieutenants = {},
        crewLeaders = {},
        veterans = {},
        soldiers = {},
        prospects = {},
    }

    -- Initialize starting resources from data
    if data.startingResources then
        self.runtime.money = data.startingResources.money or self.runtime.money
        self.runtime.members = data.startingResources.members or self.runtime.members
        self.runtime.vehicles = data.startingResources.vehicles or {}
    end

    return self
end

--- Get the current runtime state of the organization.
---@return table A copy of the runtime state (read model)
function Organization:GetState()
    local state = {}
    for k, v in pairs(self.runtime) do
        if type(v) == "table" then
            state[k] = {}
            for k2, v2 in pairs(v) do
                state[k2] = v2
            end
        else
            state[k] = v
        end
    end
    state.id = self.id
    state.displayName = self.displayName
    return state
end

--- Get the organization's identity data.
---@return table { id, displayName, personality }
function Organization:GetIdentity()
    return {
        id = self.id,
        displayName = self.displayName,
        personality = self.personality,
    }
end

--- Get the leadership hierarchy.
---@return table
function Organization:GetLeadership()
    local leadership = {}
    for k, v in pairs(self.leadership) do
        if type(v) == "table" then
            leadership[k] = {}
            for _, agentId in ipairs(v) do
                table.insert(leadership[k], agentId)
            end
        else
            leadership[k] = v
        end
    end
    return leadership
end

--- Set the organization's state.
---@param newState string One of Organization.States
---@return boolean true if state changed
function Organization:SetState(newState)
    -- Validate the state
    local valid = false
    for _, stateName in pairs(Organization.States) do
        if stateName == newState then
            valid = true
            break
        end
    end
    if not valid then
        return false
    end

    local oldState = self.runtime.state
    if oldState == newState then
        return false
    end

    self.runtime.state = newState
    self.runtime.lastStateChange = os.time()

    if newState == Organization.States.Suppressed then
        self.runtime.suppressedSince = os.time()
    end

    return true
end

--- Add heat to the organization.
---@param amount number
function Organization:AddHeat(amount)
    self.runtime.heat = math.min(100, math.max(0, self.runtime.heat + amount))
end

--- Add money to the organization.
---@param amount number (positive = gain, negative = loss)
function Organization:AddMoney(amount)
    self.runtime.money = math.max(0, self.runtime.money + amount)
end

--- Change member count.
---@param delta number (positive = gain, negative = loss)
function Organization:ChangeMembers(delta)
    self.runtime.members = math.max(0, self.runtime.members + delta)
end

--- Change morale.
---@param delta number
function Organization:ChangeMorale(delta)
    self.runtime.morale = math.min(100, math.max(0, self.runtime.morale + delta))
end

--- Add a territory to the organization's controlled list.
---@param regionId string
function Organization:AddTerritory(regionId)
    if not self.runtime.territories[regionId] then
        self.runtime.territories[regionId] = true
    end
end

--- Remove a territory from the organization's controlled list.
---@param regionId string
function Organization:RemoveTerritory(regionId)
    self.runtime.territories[regionId] = nil
end

--- Check if the organization controls a specific territory.
---@param regionId string
---@return boolean
function Organization:HasTerritory(regionId)
    return self.runtime.territories[regionId] == true
end

_G.DCEOrganization = Organization
