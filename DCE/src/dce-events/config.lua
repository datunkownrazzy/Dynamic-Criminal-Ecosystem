-- DCE Events Configuration
-- All tunable values for the Scenario Engine.

Config = Config or {}
Config.Events = Config.Events or {}
Config.Scenario = Config.Scenario or {}

-- Scenario tick interval (referenced by init.lua)
Config.Scenario.TickInterval = 5000
Config.Events.TickInterval = 5000  -- deprecated, use Config.Scenario.TickInterval

-- Scenario model configuration (for models/scenario.lua defaults)
Config.Scenario.Default = {
    Stages = { "Planning", "Travel", "Preparation", "Execution", "Reaction", "Escape", "Resolution" },
}
Config.Scenario.StageDurations = {
    Planning = 30,
    Travel = 60,
    Preparation = 120,
    Execution = 180,
    Reaction = 60,
    Escape = 120,
    Resolution = 30,
}
Config.Scenario.Escalation = {
    DispatchTriggerStages = { "Execution", "Reaction" },
    ScenarioTimeout = 1800,  -- 30 minutes
}

-- Set global Config (extends the core config)
_G.Config = Config
return Config
