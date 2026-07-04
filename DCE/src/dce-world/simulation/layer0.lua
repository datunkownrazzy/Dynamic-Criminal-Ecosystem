-- DCE Layer 0 Statistical Simulation
-- Updates statistical values for every region, cheaply.
-- Runs map-wide on every tick.

local Layer0 = {}
local lastTickTime = {}

--- Execute a Layer 0 tick for all regions.
---@param regions table All region instances keyed by ID
---@param worldState table The global world state
---@return table changedRegions Regions whose state changed meaningfully
function Layer0.Tick(regions, worldState)
    local now = os.time()
    local deltaTime = 10 -- default: assume 10 seconds if first tick
    local lastTick = lastTickTime["layer0"]
    if lastTick then
        deltaTime = now - lastTick
    end
    lastTickTime["layer0"] = now

    local changedRegions = {}
    local timeState = worldState:GetTime()

    for regionId, region in pairs(regions) do
        local before = region:GetState()

        -- Drift region state toward baseline values
        region:DriftTowardBaseline(deltaTime)

        -- Apply time-of-day effects
        if timeState.isNight then
            -- Night: civilian density decreases
            region.runtime.civilianDensity = math.max(0, region.runtime.civilianDensity - (2 * deltaTime))
        else
            -- Day: civilian density increases toward baseline
            local base = region.baseValues.civilianDensity
            region.runtime.civilianDensity = region.runtime.civilianDensity + (base - region.runtime.civilianDensity) * 0.01 * deltaTime
        end

        -- Apply weather effects
        local weather = worldState:GetWeather()
        if weather == "RAIN" or weather == "THUNDER" then
            -- Rain: civilian density drops, police presence increases slightly
            region.runtime.civilianDensity = math.max(0, region.runtime.civilianDensity - (1 * deltaTime))
            region.runtime.policePresence = math.min(100, region.runtime.policePresence + (0.5 * deltaTime))
        end

        -- Clamp all values to valid range
        region.runtime.policePresence = math.max(0, math.min(100, region.runtime.policePresence))
        region.runtime.civilianDensity = math.max(0, math.min(100, region.runtime.civilianDensity))
        region.runtime.economicHealth = math.max(0, math.min(100, region.runtime.economicHealth))
        region.runtime.heat = math.max(0, math.min(100, region.runtime.heat))
        region.runtime.violence = math.max(0, math.min(100, region.runtime.violence))

        local after = region:GetState()
        if HasSignificantChange(before, after) then
            changedRegions[regionId] = after
        end
    end

    return changedRegions
end

--- Check if a region's state changed meaningfully enough to emit an event.
---@param before table Previous state
---@param after table Current state
---@return boolean
function HasSignificantChange(before, after)
    local threshold = Config.World.StateChangeThreshold
    return math.abs((after.policePresence or 0) - (before.policePresence or 0)) >= threshold.PolicePresence
        or math.abs((after.civilianDensity or 0) - (before.civilianDensity or 0)) >= threshold.CivilianDensity
        or math.abs((after.heat or 0) - (before.heat or 0)) >= threshold.Heat
        or math.abs((after.violence or 0) - (before.violence or 0)) >= threshold.Violence
        or math.abs((after.economicHealth or 0) - (before.economicHealth or 0)) >= threshold.EconomicHealth
end

return Layer0