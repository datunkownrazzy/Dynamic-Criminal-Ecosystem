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

-- Return config for modules that require it
return Config
