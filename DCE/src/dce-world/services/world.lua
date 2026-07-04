-- DCE World Engine Service
-- Maintains world state, regions, and layer simulation.
-- Other systems query this through the Service Registry — they never mutate it directly.
-- Spec: docs/04_Simulation/World_Engine.md

local Region = DCERegion
local WorldState = DCEWorldState
local Layer0 = DCELayer0
local Layer1 = DCELayer1
local TimeSim = DCETimeSim
local WeatherSim = DCEWeatherSim

local WorldService = {}
local regions = {}        -- regionId -> Region instance
local worldState = nil
local isInitialized = false

--- Initialize the World Engine.
function WorldService.Initialize()
    if isInitialized then
        return
    end

    DCE:Log("world", "info", "World Engine initializing...")

    -- Load region definitions
    local regionData = DCERegions
    for id, data in pairs(regionData) do
        regions[id] = Region.New(id, data)
        DCE:Log("world", "info", "  Region loaded: %s (%s)", id, data.displayName)
    end

    -- Initialize world state
    worldState = WorldState.New()
    TimeSim.Init()
    WeatherSim.Init()

    DCE:Log("world", "info", "World Engine initialized with %d regions", #regions)
    isInitialized = true
end

-- ============================================================================
-- Service Interface (Public API)
-- ============================================================================

--- Get the current state of a specific region.
---@param regionId string
---@return table|nil Region state (read model)
function WorldService.GetRegionState(regionId)
    local region = regions[regionId]
    if not region then
        return nil
    end
    return region:GetState()
end

--- Get all regions adjacent to a given region.
---@param regionId string
---@return table Array of adjacent region IDs
function WorldService.GetAdjacentRegions(regionId)
    local region = regions[regionId]
    if not region then
        return {}
    end
    local adjacent = {}
    for _, adjId in ipairs(region.adjacentRegions) do
        table.insert(adjacent, adjId)
    end
    return adjacent
end

--- Get all registered region IDs.
---@return table Array of region ID strings
function WorldService.GetAllRegionIds()
    local ids = {}
    for id, _ in pairs(regions) do
        table.insert(ids, id)
    end
    return ids
end

--- Get the simulation layer for a region.
---@param regionId string
---@return number 0 or 1
function WorldService.GetRegionLayer(regionId)
    local region = regions[regionId]
    if not region then
        return 0
    end
    return region:GetLayer()
end

--- Get the current time state.
---@return table { hour, minute, day, isNight }
function WorldService.GetTime()
    if not worldState then
        return { hour = 12, minute = 0, day = 1, isNight = false }
    end
    return worldState:GetTime()
end

--- Get the current weather.
---@return string
function WorldService.GetWeather()
    if not worldState then
        return "CLEAR"
    end
    return worldState:GetWeather()
end

--- Get a summary of all region states.
---@return table Array of region state summaries
function WorldService.GetAllRegionStates()
    local states = {}
    for id, region in pairs(regions) do
        table.insert(states, region:GetState())
    end
    return states
end

-- ============================================================================
-- Simulation Ticks (called by Scheduler)
-- ============================================================================

--- Layer 0 tick: statistical simulation for all regions.
function WorldService.Layer0Tick()
    if not isInitialized then
        return
    end

    local changedRegions = Layer0.Tick(regions, worldState)

    -- Emit events for significantly changed regions
    for regionId, state in pairs(changedRegions) do
        DCE:Emit("world:region:state_changed", {
            eventName = "world:region:state_changed",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-world",
            payload = state,
        })
    end
end

--- Layer 1 tick: ambient materialization/dematerialization.
function WorldService.Layer1Tick()
    if not isInitialized then
        return
    end

    local promotions = Layer1.Tick(regions)

    for _, promo in ipairs(promotions) do
        DCE:Emit("world:region:layer_changed", {
            eventName = "world:region:layer_changed",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-world",
            payload = promo,
        })
    end
end

--- Time tick: advance simulated time.
function WorldService.TimeTick()
    if not isInitialized then
        return
    end

    local newTime = TimeSim.Tick(worldState)
    if newTime then
        DCE:Emit("world:time:changed", {
            eventName = "world:time:changed",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-world",
            payload = newTime,
        })
    end
end

--- Weather tick: possibly change weather.
function WorldService.WeatherTick()
    if not isInitialized then
        return
    end

    local newWeather = WeatherSim.Tick(worldState)
    if newWeather then
        DCE:Emit("world:weather:changed", {
            eventName = "world:weather:changed",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-world",
            payload = { weather = newWeather },
        })
    end
end

-- ============================================================================
-- Shutdown
-- ============================================================================

--- Clean up all world state.
function WorldService.Shutdown()
    DCE:Log("world", "info", "World Engine shutting down...")

    Layer1.Clear()

    for regionId, _ in pairs(regions) do
        regions[regionId] = nil
    end

    worldState = nil
    isInitialized = false

    DCE:Log("world", "info", "World Engine shutdown complete")
end

_G.DCEWorldService = WorldService
