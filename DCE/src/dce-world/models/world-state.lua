-- DCE World State Model
-- Global world state: time, weather, synced state.

local WorldState = {}
WorldState.__index = WorldState

--- Create a new WorldState instance.
---@return table WorldState instance
function WorldState.New()
    local self = setmetatable({}, WorldState)

    self.time = {
        hour = 12,
        minute = 0,
        day = 1,
        isNight = false,
        lastUpdate = 0,
    }

    self.weather = {
        current = "CLEAR",
        previous = "EXTRASUNNY",
        lastChange = 0,
        nextScheduledChange = 0,
    }

    return self
end

--- Update the simulated time.
---@param deltaTime number Seconds elapsed since last update
function WorldState:UpdateTime(deltaTime)
    if not Config.World.Time.Enabled then
        return
    end

    local totalMinutesPerDay = Config.World.Time.DayLengthMinutes
    local gameMinutesPerRealSecond = (24 * 60) / totalMinutesPerDay

    local totalGameMinutes = self.time.hour * 60 + self.time.minute
    totalGameMinutes = totalGameMinutes + (deltaTime * gameMinutesPerRealSecond)

    -- Wrap around at 24 hours
    if totalGameMinutes >= 24 * 60 then
        totalGameMinutes = totalGameMinutes - (24 * 60)
        self.time.day = self.time.day + 1
    end

    self.time.hour = math.floor(totalGameMinutes / 60)
    self.time.minute = math.floor(totalGameMinutes % 60)
    self.time.isNight = self.time.hour >= Config.World.Time.NightStart or self.time.hour < Config.World.Time.NightEnd
end

--- Get the current time state.
---@return table { hour, minute, day, isNight }
function WorldState:GetTime()
    return {
        hour = self.time.hour,
        minute = self.time.minute,
        day = self.time.day,
        isNight = self.time.isNight,
    }
end

--- Get the current weather.
---@return string Weather type
function WorldState:GetWeather()
    return self.weather.current
end

--- Set the weather to a specific type.
---@param weatherType string Valid weather type
function WorldState:SetWeather(weatherType)
    if self.weather.current ~= weatherType then
        self.weather.previous = self.weather.current
        self.weather.current = weatherType
        self.weather.lastChange = os.time()
        self.weather.nextScheduledChange = os.time() + (Config.World.Weather.ChangeInterval / 1000)
    end
end

--- Randomly change the weather based on configured intervals.
function WorldState:MaybeChangeWeather()
    if not Config.World.Weather.Enabled then
        return false
    end

    local now = os.time()
    if now < self.weather.nextScheduledChange then
        return false
    end

    -- Pick a random weather type different from current
    local types = Config.World.Weather.Types
    local newWeather
    repeat
        newWeather = types[math.random(#types)]
    until newWeather ~= self.weather.current

    self:SetWeather(newWeather)
    return true
end

return WorldState