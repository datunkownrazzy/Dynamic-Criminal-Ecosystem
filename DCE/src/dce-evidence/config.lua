-- DCE Evidence Configuration

Config = Config or {}
Config.Evidence = Config.Evidence or {}

-- Evidence confidence thresholds
Config.Evidence.Confidence = {
    Low = 25,
    Medium = 50,
    High = 75,
    Certain = 100,
}

-- Evidence types
Config.Evidence.Types = {
    Physical = "physical",
    Digital = "digital",
    Testimonial = "testimonial",
    Financial = "financial",
    Forensic = "forensic",
}

-- Default evidence decay (seconds before confidence starts dropping)
Config.Evidence.DecayInterval = 86400  -- 24 hours
Config.Evidence.DecayRate = 5          -- confidence points lost per interval

-- Integration settings
Config.Evidence.Integration = {
    Mode = "native", -- "native", "ers", or "custom"
    ResourceName = "ers",
    ExportName = "DCEEvidenceAdapter",
    EnableStandaloneFallback = true,
}
