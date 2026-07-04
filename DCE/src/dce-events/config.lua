-- DCE Scenario Engine Configuration

Config = Config or {}
Config.Scenario = Config.Scenario or {}

-- Scenario tick interval (ms)
Config.Scenario.TickInterval = 5000  -- check scenario progression every 5 seconds

-- Stage durations (seconds) for each stage of a scenario
Config.Scenario.StageDurations = {
    Planning = 30,
    Travel = 60,
    Preparation = 30,
    Execution = 120,
    Reaction = 60,
    Escape = 60,
    Resolution = 30,
}

-- Escalation thresholds
Config.Scenario.Escalation = {
    -- Layer 2 -> Layer 3 triggers
    DispatchTriggerStages = { "Execution", "Reaction" },
    -- Heat threshold for automatic escalation
    HeatEscalationThreshold = 50,
    -- Time before a scenario times out (seconds)
    ScenarioTimeout = 600,  -- 10 minutes
}

-- Default scenario definition
Config.Scenario.Default = {
    Type = "drug_sale",
    DisplayName = "Drug Sale",
    Stages = { "Planning", "Travel", "Preparation", "Execution", "Reaction", "Escape", "Resolution" },
    DispatchTriggerStage = "Execution",
    HeatOutput = 10,
    ViolenceOutput = 5,
    EvidenceOutput = 1,
}