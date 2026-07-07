-- DCE Benchmark Suite
-- Built-in performance measurement tools.
-- Spec: ADR-0015

local BenchmarkSuite = {}
local benchmarks = {}
local results = {}
local logger
local cachedConfig = {}

--- Initialize the benchmark suite
function BenchmarkSuite.Init(log)
    logger = log
    cachedConfig = _G.Config or {}
end

--- Log a message
local function log(level, module, message, ...)
    if logger then
        logger.Log(module, level, message, ...)
    end
end

--- Register a benchmark
---@param name string Benchmark name
---@param fn function Function to measure
function BenchmarkSuite.Register(name, fn)
    benchmarks[name] = fn
end

--- Run a single benchmark and return time
---@param name string Benchmark name
---@return number elapsedMs, boolean success
function BenchmarkSuite.Run(name)
    local fn = benchmarks[name]
    if not fn then
        log("warn", "core", "Benchmark: '%s' not found", name)
        return 0, false
    end

    local startTime = GetGameTimer and (GetGameTimer() / 1000) or (os.clock and os.clock() or os.time())
    local success, err = pcall(fn)
    local endTime = GetGameTimer and (GetGameTimer() / 1000) or (os.clock and os.clock() or os.time())

    local elapsed = (endTime - startTime) * 1000
    results[name] = {
        elapsed = elapsed,
        success = success,
        error = err,
        timestamp = os.time(),
    }

    if not success then
        log("error", "core", "Benchmark '%s' failed: %s", name, tostring(err))
    end

    return elapsed, success
end

--- Run all benchmarks
---@return table results
function BenchmarkSuite.RunAll()
    local allResults = {}

    for name, _ in pairs(benchmarks) do
        local elapsed, success = BenchmarkSuite.Run(name)
        allResults[name] = {
            elapsed = elapsed,
            success = success,
        }
    end

    return allResults
end

--- Framework startup benchmark
function BenchmarkSuite.BenchmarkFrameworkStartup()
    local DCEAPI = DCE and DCE.GetService("CoreRegistry")
    return DCEAPI ~= nil
end

--- Service startup benchmark (measures first call to service)
function BenchmarkSuite.BenchmarkServiceStartup()
    local services = { "CoreRegistry", "Scheduler", "EventBus" }
    for _, name in ipairs(services) do
        local svc = DCE and DCE.GetService(name)
    end
    return true
end

--- Event throughput benchmark
function BenchmarkSuite.BenchmarkEventThroughput()
    local iterations = 1000
    for i = 1, iterations do
        DCE.Emit("benchmark:test:event", {
            eventVersion = 1,
            timestamp = os.time(),
            source = "benchmark",
            payload = { iteration = i },
        })
    end
    return true
end

--- Scheduler throughput benchmark
function BenchmarkSuite.BenchmarkSchedulerThroughput()
    local iterations = 100
    for i = 1, iterations do
        DCE.Schedule("benchmark:task:" .. i, 60000, function() end, { immediate = false })
    end
    return true
end

--- Cache throughput benchmark
function BenchmarkSuite.BenchmarkCacheThroughput()
    local cache = DCECache
    if not cache then return false end

    cache.Create("benchmark_cache", { maxSize = 100 })
    for i = 1, 100 do
        cache.Set("benchmark_cache", "key_" .. i, { value = i })
        cache.Get("benchmark_cache", "key_" .. i)
    end
    cache.Clear("benchmark_cache")
    return true
end

--- Initialize default benchmarks
function BenchmarkSuite.InitializeBenchmarks()
    BenchmarkSuite.Register("framework_startup", BenchmarkSuite.BenchmarkFrameworkStartup)
    BenchmarkSuite.Register("service_startup", BenchmarkSuite.BenchmarkServiceStartup)
    BenchmarkSuite.Register("event_throughput", BenchmarkSuite.BenchmarkEventThroughput)
    BenchmarkSuite.Register("scheduler_throughput", BenchmarkSuite.BenchmarkSchedulerThroughput)
    BenchmarkSuite.Register("cache_throughput", BenchmarkSuite.BenchmarkCacheThroughput)

    log("info", "core", "Benchmark suite initialized with %d benchmarks", 5)
end

--- Get cached results
---@return table
function BenchmarkSuite.GetResults()
    return results
end

--- Clear benchmark results
function BenchmarkSuite.ClearResults()
    results = {}
end

--- Generate report
---@return table
function BenchmarkSuite.GenerateReport()
    local report = {
        timestamp = os.time(),
        benchmarks = {},
    }

    for name, result in pairs(results) do
        report.benchmarks[name] = {
            elapsed = result.elapsed,
            success = result.success,
        }
    end

    -- Calculate totals
    local totalTime = 0
    local successCount = 0
    for _, result in pairs(results) do
        totalTime = totalTime + (result.elapsed or 0)
        if result.success then successCount = successCount + 1 end
    end

    report.summary = {
        totalTime = totalTime,
        benchmarksRun = #results,
        successRate = (#results > 0) and (successCount / #results * 100) or 0,
    }

    return report
end

--- Shutdown
function BenchmarkSuite.Shutdown()
    benchmarks = {}
    results = {}
    log("info", "core", "Benchmark suite shutdown")
end

return BenchmarkSuite