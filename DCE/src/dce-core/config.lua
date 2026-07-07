-- DCE Core Configuration
-- All tunable values live here. No hardcoded thresholds in logic.

Config = Config or {}

-- Logger defaults
Config.Logger = {
    Level = "info",         -- "debug" | "info" | "warn" | "error" | "off"
    Format = "[${module}] ${message}",
    Timestamps = true,
}

-- Scheduler defaults
Config.Scheduler = {
    MaxTasks = 128,          -- safety limit to prevent runaway registrations
    DefaultInterval = 60000, -- ms (60 seconds fallback if not specified)
    ErrorCooldown = 10000,   -- ms to wait before retrying a task that errored
}

-- Service Registry defaults
Config.Registry = {
    AllowOverrides = true,   -- allow plugins to override existing services with override=true
    LogRegistrations = true, -- log every RegisterService/UnregisterService call
}

-- Plugin Manager defaults
Config.PluginManager = {
    Enabled = true,
    FailOnMissingDependency = true,  -- reject plugin load if Requires not satisfied
    FailOnVersionMismatch = true,    -- reject plugin load if DCE version outside range
}

-- Performance Budget settings (per ADR-0015)
Config.Performance = {
    -- Target budgets for different server states
    IdleBudget = 0.10,        -- ms target for idle server
    RPBudget = 0.75,          -- ms target for typical RP server
    HeavyBudget = 1.5,        -- ms target for heavy criminal activity
    MaxBudget = 2.5,          -- absolute maximum before hard throttle
    AlertThreshold = 1.25,    -- warn when approaching max
    ProfilerEnabled = true,   -- enable/disable profiler
    MaxHistorySize = 600,     -- max historical entries per service (10 min at 1s)
}

-- Per-service CPU budgets (per ADR-0004 tick model)
Config.SimulationBudget = {
    Scheduler = 0.05,
    AI = 0.40,
    Dispatch = 0.20,
    Evidence = 0.15,
    Economy = 0.25,
    Weather = 0.02,
    Organizations = 0.30,
}

-- AI Update Frequencies (per ADR-0015)
Config.AIUpdateFrequencies = {
    Critical = 250,      -- ms (active incidents, heat spikes)
    Nearby = 500,        -- ms (organizations near players)
    Active = 1000,       -- ms (normal operation)
    Passive = 5000,      -- ms (idle but not dormant)
    Dormant = 30000,     -- ms (sleep until event)
}

-- Cache defaults
Config.Cache = {
    DefaultTTL = 300,        -- 5 minutes default TTL
    DefaultMaxSize = 1000,   -- default max entries
    EvictionPolicy = "lru",  -- lru|fifo|random
}

-- Pool defaults
Config.Pool = {
    DefaultMaxSize = 100,
    DefaultGrowIncrement = 10,
}

-- Admin performance monitoring
Config.Admin = Config.Admin or {}
Config.Admin.Performance = {
    RefreshInterval = 1000,    -- ms between dashboard updates
    AutoAlerts = true,         -- enable automatic performance alerts
}

-- Return config for modules that require it
_G.Config = Config
return Config
