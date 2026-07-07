-- DCE Debug Mode Manager
-- Production/Development/Stress Test/Benchmark modes.
-- Spec: ADR-0015

local ModeManager = {}
local currentMode = "production"
local modes = {
    production = {
        logLevel = "warn",
        profilerEnabled = false,
        stressSimulation = false,
        verboseEvents = false,
        benchmarkMode = false,
    },
    development = {
        logLevel = "debug",
        profilerEnabled = true,
        stressSimulation = false,
        verboseEvents = true,
        benchmarkMode = false,
    },
    verbose = {
        logLevel = "debug",
        profilerEnabled = true,
        stressSimulation = false,
        verboseEvents = true,
        benchmarkMode = false,
        stackTraces = true,
    },
    profiler = {
        logLevel = "info",
        profilerEnabled = true,
        stressSimulation = false,
        verboseEvents = false,
        benchmarkMode = false,
        detailedMetrics = true,
    },
    stress_test = {
        logLevel = "info",
        profilerEnabled = true,
        stressSimulation = true,
        verboseEvents = false,
        benchmarkMode = false,
        simulatedLoad = 10, -- Simulate 10x load
    },
    simulation = {
        logLevel = "info",
        profilerEnabled = true,
        stressSimulation = false,
        verboseEvents = false,
        benchmarkMode = false,
        deterministicTiming = true,
    },
    benchmark = {
        logLevel = "info",
        profilerEnabled = true,
        stressSimulation = false,
        verboseEvents = false,
        benchmarkMode = true,
    },
}
local logger
local cachedConfig = {}

--- Initialize the mode manager
function ModeManager.Init(log)
    logger = log
    cachedConfig = _G.Config or {}

    -- Check config for initial mode
    local configMode = cachedConfig.Admin and cachedConfig.Admin.DebugMode
    if configMode and modes[configMode] then
        currentMode = configMode
    end

    ModeManager.ApplyMode(currentMode)
end

--- Log a message
local function log(level, module, message, ...)
    if logger then
        logger.Log(module, level, message, ...)
    end
end

--- Apply a mode's settings
---@param mode string
function ModeManager.ApplyMode(mode)
    local modeConfig = modes[mode]
    if not modeConfig then
        log("warn", "core", "Unknown debug mode: %s", mode)
        return false
    end

    currentMode = mode

    -- Apply logger level
    if DCE and DCE.GetService then
        local Logger = DCE.GetService("Logger")
        if Logger and Logger.SetLevel then
            Logger.SetLevel(modeConfig.logLevel)
        end
    end

    -- Apply profiler settings
    if DCE and DCEProfiler then
        DCEProfiler.SetEnabled(modeConfig.profilerEnabled)
    end

    -- Emit mode change event
    if DCE and DCE.Emit then
        DCE.Emit("admin:debug:mode:changed", {
            eventName = "admin:debug:mode:changed",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-admin-debug",
            payload = {
                mode = mode,
                config = modeConfig,
            },
        })
    end

    log("info", "core", "Debug mode set to: %s", mode)
    return true
end

--- Get current mode
---@return string
function ModeManager.GetMode()
    return currentMode
end

--- Set mode
---@param mode string
---@return boolean
function ModeManager.SetMode(mode)
    return ModeManager.ApplyMode(mode)
end

--- Get mode configuration
---@return table
function ModeManager.GetModeConfig()
    return modes[currentMode] or modes.production
end

--- Check if a feature is enabled
---@param feature string
---@return boolean
function ModeManager.IsEnabled(feature)
    local config = modes[currentMode]
    if not config then return false end

    if feature == "profiler" then
        return config.profilerEnabled
    elseif feature == "verbose" then
        return config.verboseEvents
    elseif feature == "stress_test" then
        return config.stressSimulation
    elseif feature == "benchmark" then
        return config.benchmarkMode
    elseif feature == "stack_traces" then
        return config.stackTraces
    elseif feature == "deterministic" then
        return config.deterministicTiming
    end
    return false
end

--- List available modes
---@return table
function ModeManager.ListModes()
    local result = {}
    for mode, _ in pairs(modes) do
        table.insert(result, mode)
    end
    return result
end

--- Shutdown
function ModeManager.Shutdown()
    log("info", "core", "Debug mode manager shutdown")
end

return ModeManager