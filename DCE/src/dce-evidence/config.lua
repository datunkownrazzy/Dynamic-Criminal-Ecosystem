-- DCE Evidence Configuration

Config = Config or {}
Config.Evidence = Config.Evidence or {}

-- Evidence types
Config.Evidence.Types = Config.Evidence.Types or {
    Physical = "physical",
    Forensic = "forensic",
    Digital = "digital",
}

-- Evidence confidence defaults
Config.Evidence.Confidence = Config.Evidence.Confidence or {
    Low = 25,
    Medium = 50,
    High = 75,
}

-- Evidence lifecycle
Config.Evidence.ChainOfCustodyEnabled = true
Config.Evidence.AutoVerification = false

-- Evidence decay settings (seconds)
Config.Evidence.DecayInterval = 3600
Config.Evidence.DecayRate = 5

-- Integration settings
Config.Evidence.Integration = Config.Evidence.Integration or {
    Mode = "native", -- "native", "ers", or "custom"
    ResourceName = "ers",
    ExportName = "DCEvidenceAdapter",
    EnableStandaloneFallback = true,
}

-- Factory defaults for evidence creation
Config.Evidence.Factory = Config.Evidence.Factory or {
    DefaultScenarioConfidence = 25,
    DefaultDispatchConfidence = 30,
}

-- Set global Config (extends the core config)
_G.Config = Config
return Config
