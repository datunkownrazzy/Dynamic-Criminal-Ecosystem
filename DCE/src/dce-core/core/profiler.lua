-- DCE Profiler Service
-- Central performance measurement and monitoring.
-- Spec: ADR-0015

local Profiler = {}
local metrics = {}           -- serviceId -> { cpuMs, memoryBytes, eventCount, queueDepth, execFrequency, lastUpdate }
local history = {}           -- serviceId -> array of { timestamp, cpuMs } for graphs
local serviceBudgets = {}    -- serviceId -> budgetMs
local isEnabled = true
local logger
local cachedConfig = {}

--- Initialize the profiler with a reference to the logger.
function Profiler.Init(log)
    logger = log
    cachedConfig = _G.Config or {}
    isEnabled = cachedConfig.Performance and cachedConfig.Performance.ProfilerEnabled ~= false
end

--- Log a message through the logger if available.
local function log(level, module, message, ...)
    if logger then
        logger.Log(module, level, message, ...)
    end
end

--- Record start time for a service/task (for CPU measurement)
---@param serviceId string Unique identifier (e.g., "ai", "dispatch", "Scheduler:world:tick")
function Profiler.RecordStart(serviceId)
    if not isEnabled then return end
    if not metrics[serviceId] then
        metrics[serviceId] = {
            cpuMs = 0,
            memoryBytes = 0,
            eventCount = 0,
            queueDepth = 0,
            execFrequency = 0,
            lastUpdate = os.time(),
            runCount = 0,
        }
    end
    
    -- Store start time for this invocation
    metrics[serviceId]._startTime = GetGameTimer and (GetGameTimer() / 1000) or nil
    if not metrics[serviceId]._startTime then
        -- Fallback for non-FiveM environments
        metrics[serviceId]._startTime = os.clock and os.clock() or os.time()
    end
    metrics[serviceId]._startTime = metrics[serviceId]._startTime
end

--- Record end time for a service/task (calculates CPU time)
---@param serviceId string Unique identifier
function Profiler.RecordEnd(serviceId)
    if not isEnabled then return end
    local m = metrics[serviceId]
    if not m or not m._startTime then return end
    
    local endTime = GetGameTimer and (GetGameTimer() / 1000) or (os.clock and os.clock() or os.time())
    local elapsed = (endTime - m._startTime) * 1000  -- convert to ms
    
    m.cpuMs = elapsed
    m.runCount = m.runCount + 1
    m.lastUpdate = os.time()
    m._startTime = nil
    
    -- Record historical data for graphs (keep last 10 minutes at 1s intervals)
    if not history[serviceId] then
        history[serviceId] = {}
    end
    
    local histEntry = {
        timestamp = os.time(),
        cpuMs = elapsed,
    }
    table.insert(history[serviceId], histEntry)
    
    -- Trim history to max size (default: 600 entries = 10 minutes at 1s)
    local maxHistory = 600
    if cachedConfig.Performance and cachedConfig.Performance.MaxHistorySize then
        maxHistory = cachedConfig.Performance.MaxHistorySize
    end
    while #history[serviceId] > maxHistory do
        table.remove(history[serviceId], 1)
    end
    
    -- Check budget and emit alert if exceeded
    local budget = serviceBudgets[serviceId]
    if budget and elapsed > budget then
        Profiler.EmitBudgetExceeded(serviceId, elapsed, budget)
    end
end

--- Set the CPU budget for a service
---@param serviceId string
---@param budgetMs number Budget in milliseconds
function Profiler.SetBudget(serviceId, budgetMs)
    serviceBudgets[serviceId] = budgetMs
    log("debug", "core", "Profiler: set budget %.2fms for '%s'", budgetMs, serviceId)
end

--- Emit budget exceeded event
---@param serviceId string
---@param actualMs number Actual CPU time
---@param budgetMs number Budget limit
function Profiler.EmitBudgetExceeded(serviceId, actualMs, budgetMs)
    if DCE and DCE.Emit then
        DCE.Emit("performance:budget:exceeded", {
            eventName = "performance:budget:exceeded",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-core-profiler",
            payload = {
                serviceId = serviceId,
                actualMs = actualMs,
                budgetMs = budgetMs,
            },
        })
    end
    log("warn", "core", "Performance alert: '%s' exceeded budget (%.2fms > %.2fms)", serviceId, actualMs, budgetMs)
end

--- Increment event count for a service
---@param serviceId string
function Profiler.IncrementEventCount(serviceId)
    if not isEnabled then return end
    local m = metrics[serviceId]
    if m then
        m.eventCount = m.eventCount + 1
    end
end

--- Set queue depth for a service
---@param serviceId string
---@param depth number Current queue depth
function Profiler.SetQueueDepth(serviceId, depth)
    if not isEnabled then return end
    local m = metrics[serviceId]
    if m then
        m.queueDepth = depth
    end
end

--- Set execution frequency for a service (times per second)
---@param serviceId string
---@param frequency number Executions per second
function Profiler.SetExecutionFrequency(serviceId, frequency)
    if not isEnabled then return end
    local m = metrics[serviceId]
    if m then
        m.execFrequency = frequency
    end
end

--- Get current metrics for a service
---@param serviceId string
---@return table|nil
function Profiler.GetMetrics(serviceId)
    return metrics[serviceId] and {
        cpuMs = metrics[serviceId].cpuMs or 0,
        memoryBytes = metrics[serviceId].memoryBytes or 0,
        eventCount = metrics[serviceId].eventCount or 0,
        queueDepth = metrics[serviceId].queueDepth or 0,
        execFrequency = metrics[serviceId].execFrequency or 0,
        lastUpdate = metrics[serviceId].lastUpdate or 0,
        runCount = metrics[serviceId].runCount or 0,
    } or nil
end

--- Get all metrics
---@return table serviceId -> metrics
function Profiler.GetAllMetrics()
    local result = {}
    for serviceId, m in pairs(metrics) do
        result[serviceId] = Profiler.GetMetrics(serviceId)
    end
    return result
end

--- Get historical metrics for graphs
---@param serviceId string
---@param limit number|nil Maximum entries to return
---@return table Array of { timestamp, cpuMs }
function Profiler.GetHistory(serviceId, limit)
    local h = history[serviceId]
    if not h then return {} end
    
    limit = limit or #h
    local result = {}
    for i = math.max(1, #h - limit + 1), #h do
        result[#result + 1] = h[i]
    end
    return result
end

--- Get list of services being tracked
---@return table Array of service IDs
function Profiler.ListServices()
    local result = {}
    for serviceId, _ in pairs(metrics) do
        table.insert(result, serviceId)
    end
    return result
end

--- Get aggregate statistics
---@return table
function Profiler.GetStats()
    local totalCpu = 0
    local totalEvents = 0
    local activeServices = 0
    local totalRuns = 0
    
    for _, m in pairs(metrics) do
        totalCpu = totalCpu + (m.cpuMs or 0)
        totalEvents = totalEvents + (m.eventCount or 0)
        totalRuns = totalRuns + (m.runCount or 0)
        activeServices = activeServices + 1
    end
    
    return {
        totalServices = activeServices,
        totalCpuMs = totalCpu,
        totalEvents = totalEvents,
        totalRuns = totalRuns,
        timestamp = os.time(),
    }
end

--- Reset metrics for a service
---@param serviceId string|nil If nil, reset all
function Profiler.Reset(serviceId)
    if serviceId then
        metrics[serviceId] = nil
        history[serviceId] = nil
    else
        metrics = {}
        history = {}
    end
end

--- Enable/disable the profiler
---@param enabled boolean
function Profiler.SetEnabled(enabled)
    isEnabled = enabled
    log("info", "core", "Profiler %s", enabled and "enabled" or "disabled")
end

--- Shutdown the profiler
function Profiler.Shutdown()
    log("info", "core", "Profiler shutting down, clearing all metrics")
    Profiler.Reset()
end

_G.DCEProfiler = Profiler
