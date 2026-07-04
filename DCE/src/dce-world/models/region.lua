-- DCE Region Model
-- The spatial/data unit the World Engine simulates.
-- Spec: docs/04_Simulation/Regions.md

local Region = {}
Region.__index = Region

--- Get Config safely
local function getConfig()
    return _G.Config or {}
end

--- Create a new Region instance.
---@param id string Unique region identifier
---@param data table Static region definition data
---@return table Region instance
function Region.New(id, data)
    local self = setmetatable({}, Region)

    -- Static identity (from data files)
    self.id = id
    self.displayName = data.displayName or id
    self.bounds = data.bounds or { type = "circle", center = vector3(0, 0, 0), radius = 500.0 }
    self.adjacentRegions = data.adjacentRegions or {}

    local Config = getConfig()
    local defaultRegion = {
        CivilianDensity = 50,
        EconomicHealth = 75,
        PolicePresence = 30,
        Heat = 0,
        Violence = 0,
    }
    if Config.World and Config.World.DefaultRegion then
        defaultRegion = Config.World.DefaultRegion
    end

    -- Static identity (from data files)
    self.baseValues = {
        civilianDensity = data.baseValues and data.baseValues.civilianDensity or defaultRegion.CivilianDensity,
        economicHealth = data.baseValues and data.baseValues.economicHealth or defaultRegion.EconomicHealth,
        policeBaseline = data.baseValues and data.baseValues.policeBaseline or defaultRegion.PolicePresence,
    }

    -- Runtime state (mutated by simulation)
    self.runtime = {
        policePresence = self.baseValues.policeBaseline,
        civilianDensity = self.baseValues.civilianDensity,
        gangInfluence = {},       -- orgId -> influence value (0-100)
        economicHealth = self.baseValues.economicHealth,
        heat = defaultRegion.Heat,
        violence = defaultRegion.Violence,
        layer = 0,                -- 0 = statistical, 1 = ambient
        lastPlayerProximityCheck = 0,
        playersNearby = false,
        ambientSpawned = false,
        -- Perception Pressure: enforcement signals from world
        enforcementSignals = {
            visible = 0,    -- 0-100, visible law enforcement presence
            covert = 0,     -- 0-100, covert/undercover presence
            confidence = 0, -- 0-100, optional reliability rating
        },
    }

    return self
end

--- Get the current runtime state of the region.
---@return table A copy of the runtime state (read model)
function Region:GetState()
    -- Return a copy to prevent external mutation
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

--- Get the current simulation layer for this region.
---@return number 0 or 1
function Region:GetLayer()
    return self.runtime.layer
end

--- Set the simulation layer for this region.
---@param layer number 0 or 1
function Region:SetLayer(layer)
    if layer ~= 0 and layer ~= 1 then
        return false
    end
    local oldLayer = self.runtime.layer
    self.runtime.layer = layer
    return oldLayer ~= layer -- true if changed
end

--- Apply a drift toward base values. Used by Layer 0 tick.
---@param deltaTime number Time elapsed since last tick (seconds)
function Region:DriftTowardBaseline(deltaTime)
    local r = self.runtime
    local b = self.baseValues
    local driftRate = 0.01 * deltaTime -- 1% per second toward baseline

    -- Drift police presence toward baseline
    r.policePresence = r.policePresence + (b.policeBaseline - r.policePresence) * driftRate

    -- Drift civilian density toward baseline
    r.civilianDensity = r.civilianDensity + (b.civilianDensity - r.civilianDensity) * driftRate

    -- Drift economic health toward baseline
    r.economicHealth = r.economicHealth + (b.economicHealth - r.economicHealth) * driftRate

    -- Decay heat and violence over time
    r.heat = math.max(0, r.heat - (0.5 * deltaTime))
    r.violence = math.max(0, r.violence - (0.3 * deltaTime))

    -- Decay gang influence
    for orgId, influence in pairs(r.gangInfluence) do
        r.gangInfluence[orgId] = math.max(0, influence - (0.1 * deltaTime))
        if r.gangInfluence[orgId] <= 0 then
            r.gangInfluence[orgId] = nil
        end
    end
end

--- Apply a heat increase to the region.
---@param amount number Amount of heat to add
function Region:AddHeat(amount)
    self.runtime.heat = math.min(100, self.runtime.heat + amount)
end

--- Apply a violence increase to the region.
---@param amount number Amount of violence to add
function Region:AddViolence(amount)
    self.runtime.violence = math.min(100, self.runtime.violence + amount)
end

--- Set gang influence for a specific organization.
---@param orgId string Organization ID
---@param influence number Influence value (0-100)
function Region:SetGangInfluence(orgId, influence)
    if influence <= 0 then
        self.runtime.gangInfluence[orgId] = nil
    else
        self.runtime.gangInfluence[orgId] = math.min(100, influence)
    end
end

--- Get the dominant organization in this region (highest influence).
---@return string|nil orgId, number influence
function Region:GetDominantOrg()
    local maxInfluence = 0
    local dominantOrg = nil
    for orgId, influence in pairs(self.runtime.gangInfluence) do
        if influence > maxInfluence then
            maxInfluence = influence
            dominantOrg = orgId
        end
    end
    return dominantOrg, maxInfluence
end

--- Check if a specific organization controls this region.
---@param orgId string Organization ID
---@param threshold number Minimum influence to be considered "controlling" (default 50)
---@return boolean
function Region:IsControlledBy(orgId, threshold)
    threshold = threshold or 50
    return (self.runtime.gangInfluence[orgId] or 0) >= threshold
end

_G.DCERegion = Region