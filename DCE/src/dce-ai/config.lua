-- DCE AI Director Configuration
-- All tunable values for organization AI and decision-making.

Config = Config or {}
Config.AI = Config.AI or {}

-- AI Director tick interval (time-sliced: one org per tick)
Config.AI.DirectorTickInterval = 5000  -- ms between AI Director ticks

-- Scoring thresholds
Config.AI.Scoring = {
    MinimumScore = 40,       -- scenarios below this score are rejected
    PersonalityWeight = 1.0, -- multiplier for personality trait matching
    ResourceWeight = 1.0,    -- multiplier for resource-based modifiers
    EnvironmentWeight = 1.0, -- multiplier for environmental context
    HeatDeterrent = 0.5,     -- heat value multiplied by this as a deterrent
    PoliceDeterrent = 0.3,   -- police presence multiplied by this as a deterrent
}

-- Organization state transition thresholds
Config.AI.StateTransitions = {
    StableToAggressive = {
        MoneyRatio = 1.5,    -- money > 150% of baseline
        MinMorale = 70,
        MaxHeat = 40,
    },
    UnderInvestigationThreshold = 75,  -- intelligence > 75 triggers Under Investigation
    SuppressedHeatDecay = 30,          -- heat below 30 to exit Suppressed
    SuppressedCooldownMinutes = 120,   -- 2 hours minimum cooldown
}

-- Organization defaults
Config.AI.Organization = {
    DefaultMoney = 15000,
    DefaultMembers = 20,
    DefaultMorale = 50,
    DefaultHeat = 0,
    DefaultInfluence = 10,
    DefaultState = "Dormant",
}

-- Activity defaults
Config.AI.Activity = {
    DrugSale = {
        BaseWeight = 50,
        MinHeat = 0,
        MaxHeat = 60,
        MinMembers = 2,
        DurationMinutes = 15,
        HeatOutput = 10,
        ViolenceOutput = 5,
        MoneyOutput = 5000,
    },
}

-- Perception Pressure configuration
-- Models organization reaction to visible and covert law enforcement presence
Config.AI.PerceptionPressure = {
    Enabled = true,
    VisibleWeight = 1.0,        -- multiplier for visible police presence
    CovertWeight = 0.7,         -- multiplier for covert/undercover presence
    DecayRate = 1.5,            -- pressure decay per tick
    VisibleThreshold = 35,      -- visible pressure level triggering caution
    CovertThreshold = 25,       -- covert pressure level triggering subtle caution
    SpikeThreshold = 60,        -- pressure level triggering strong avoidance
    CooldownMinutes = 10,       -- cooldown to prevent panic loops
    HighHeatMultiplier = 0.6,   -- additional multiplier when org heat is high
}
