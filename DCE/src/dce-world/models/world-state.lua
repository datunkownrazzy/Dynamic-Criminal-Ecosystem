-- DCE World State Model
-- Global world state: time, weather, synced state.

local WorldState = {}
WorldState.__index = WorldState

--- Get Config safely
local function getConfig()
    return _G.Config or {}
end

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
    local Config = getConfig()
    if not Config.World or not Config.World.Time or not Config.World.Time.Enabled then
        return
    end

    local dayLengthMinutes = 20 -- default 20 minutes per in-game day
    if Config.World.Time and Config.World.Time.DayLengthMinutes then
        dayLengthMinutes = Config.World.Time.DayLengthMinutes
    end
    
    local gameMinutesPerRealSecond = (24 * 60) / dayLengthMinutes

    local totalGameMinutes = self.time.hour * 60 + self.time.minute
    totalGameMinutes = totalGameMinutes + (deltaTime * gameMinutesPerRealSecond)

    -- Wrap around at 24 hours
    if totalGameMinutes >= 24 * 60 then
        totalGameMinutes = totalGameMinutes - (24 * 60)
        self.time.day = self.time.day + 1
    end

    self.time.hour = math.floor(totalGameMinutes / 60)
    self.time.minute = math.floor(totalGameMinutes % 60)
    
    local nightStart = 20
    local nightEnd = 6
    if Config.World.Time then
        if Config.World.Time.NightStart then
            nightStart = Config.World.Time.NightStart
        end
        if Config.World.Time.NightEnd then
            nightEnd = Config.World.Time.NightEnd
        end
    end
    self.time.isNight = self.time.hour >= nightStart or self.time.hour < nightEnd
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
        
        local Config = getConfig()
        local changeInterval = 3600000 -- default 1 hour
        if Config.World and Config.World.Weather and Config.World.Weather.ChangeInterval then
            changeInterval = Config.World.Weather.ChangeInterval
        end
        self.weather.nextScheduledChange = os.time() + (changeInterval / 1000)
    end
end

--- Randomly change the weather based on configured intervals.
function WorldState:MaybeChangeWeather()
    local Config = getConfig()
    if not Config.World or not Config.World.Weather or not Config.World.Weather.Enabled then
        return false
    end

    local now = os.time()
    if now < self.weather.nextScheduledChange then
        return false
    end

    -- Pick a random weather type different from current
    local weatherTypes = {"CLEAR", "EXTRASUNNY", "CLOUDS", "OVERCAST", "RAIN", "THUNDER"}
    if Config.World.Weather and Config.World.Weather.Types then
        weatherTypes = Config.World.Weather.Types
    end
    
    local newWeather
    repeat
        newWeather = weatherTypes[math.random(#weatherTypes)]
    until newWeather ~= self.weather.current

    self:SetWeather(newWeather)
    return true
end

_G.DCEWorldState = WorldState