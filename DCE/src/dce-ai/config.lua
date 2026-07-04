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