-- DCE Weather Simulation
-- Tracks and updates the simulated weather.

local Weather = {}
local lastTick = 0

--- Initialize weather tracking.
function Weather.Init()
    lastTick = os.time()
end

--- Get the current weather.
---@param worldState table The global world state
---@return string Weather type
function Weather.GetCurrent(worldState)
    return worldState:GetWeather()
end

--- Tick the weather simulation forward.
---@param worldState table The global world state
---@return string|nil New weather if it changed, nil otherwise
function Weather.Tick(worldState)
    local now = os.time()
    local deltaTime = now - lastTick
    if deltaTime <= 0 then
        deltaTime = 120 -- default to 120 seconds
    end
    lastTick = now

    local before = worldState:GetWeather()
    worldState:MaybeChangeWeather()
    local after = worldState:GetWeather()

    if before ~= after then
        return after
    end

    return nil
end

return Weather