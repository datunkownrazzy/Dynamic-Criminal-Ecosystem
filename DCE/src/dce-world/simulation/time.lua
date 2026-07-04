-- DCE Time Simulation
-- Tracks and updates the simulated time of day.

local Time = {}
local lastTick = 0

--- Initialize time tracking.
function Time.Init()
    lastTick = os.time()
end

--- Get the current simulated time state.
---@param worldState table The global world state
---@return table { hour, minute, day, isNight }
function Time.GetCurrent(worldState)
    return worldState:GetTime()
end

--- Tick the time simulation forward.
---@param worldState table The global world state
---@return table|nil New time state if it changed meaningfully (crossed into/out of night), nil otherwise
function Time.Tick(worldState)
    local now = os.time()
    local deltaTime = now - lastTick
    if deltaTime <= 0 then
        deltaTime = 60 -- default to 60 seconds if no time passed
    end
    lastTick = now

    local before = worldState:GetTime()
    worldState:UpdateTime(deltaTime)
    local after = worldState:GetTime()

    -- Only emit if we crossed a meaningful boundary (night/day transition)
    if before.isNight ~= after.isNight then
        return after
    end

    return nil
end

_G.DCETimeSim = Time
