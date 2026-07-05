-- DCE World Configuration
-- All tunable values for the World Engine.

Config = Config or {}
Config.World = Config.World or {}

-- Simulation tick intervals (milliseconds)
Config.World.Layer0Interval = 10000   -- Layer 0 statistical tick: every 10 seconds
Config.World.Layer1Interval = 3000    -- Layer 1 ambient tick: every 3 seconds near players

-- Ambient materialization
Config.World.AmbientRadius = 150.0   -- Units from a player to trigger Layer 0 -> Layer 1 promotion
Config.World.AmbientLingerTime = 30000  -- ms before demoting Layer 1 -> Layer 0 after players leave

-- State change emission thresholds
Config.World.StateChangeThreshold = {
    PolicePresence = 5,      -- minimum change to emit event
    CivilianDensity = 10,
    Heat = 5,
    Violence = 5,
    EconomicHealth = 3,
}

-- Region default values (used as drift targets)
Config.World.DefaultRegion = {
    PolicePresence = 20,
    CivilianDensity = 50,
    Heat = 0,
    Violence = 0,
    EconomicHealth = 50,
    GangInfluence = 0,
}

-- Time simulation
Config.World.Time = {
    Enabled = true,
    TickInterval = 60000,       -- update time state every 60 seconds
    DayLengthMinutes = 48,      -- full day/night cycle duration in minutes
    NightStart = 20,            -- hour (24h) when "night" begins
    NightEnd = 6,               -- hour (24h) when "night" ends
}

-- Weather simulation
Config.World.Weather = {
    Enabled = true,
    TickInterval = 120000,      -- check weather every 2 minutes
    ChangeInterval = 600000,    -- minimum ms between weather changes (10 minutes)
    Types = { "EXTRASUNNY", "CLEAR", "CLOUDS", "SMOG", "FOGGY", "OVERCAST", "RAIN", "THUNDER", "CLEARING" },
}

-- Set global Config (extends the core config)
_G.Config = Config
