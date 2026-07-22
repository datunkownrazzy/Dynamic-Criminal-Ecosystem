-- DCE Graceful Degradation Handler
-- Rule Zero: The diagnostics framework shall never become the cause of a runtime failure.
-- If any diagnostic subsystem encounters an internal error, it must:
--   1. Record the error
--   2. Explain the error
--   3. Continue operating in degraded mode whenever possible
--
-- Diagnostics must never:
--   - crash commands
--   - prevent resource startup
--   - interrupt initialization
--   - break Control Center
--   - prevent other diagnostics from executing

local GracefulDegradation = {}

-- Track subsystem health
local subsystemHealth = {}

-- Known subsystems
local SUBSYSTEMS = {
    "RuntimeState",
    "Diagnostics",
    "BootTimeline",
    "ServiceValidator",
    "CCDiagnostics",
    "Report",
    "Commands",
    "ModuleLoader",
    "Logger",
}

-- Initialize all subsystems as UNKNOWN
for _, name in ipairs(SUBSYSTEMS) do
    subsystemHealth[name] = {
        status = "UNKNOWN",
        lastError = nil,
        lastErrorTime = nil,
        errorCount = 0,
        degraded = false,
    }
end

--- Report a subsystem failure
-- @param subsystem string - The subsystem name
-- @param expected string - What was expected
-- @param received string - What was received
-- @param caller string - The calling function
-- @param stage string - The execution stage
function GracefulDegradation.ReportFailure(subsystem, expected, received, caller, stage)
    local health = subsystemHealth[subsystem]
    if not health then
        health = {
            status = "UNKNOWN",
            lastError = nil,
            lastErrorTime = nil,
            errorCount = 0,
            degraded = false,
        }
        subsystemHealth[subsystem] = health
    end

    health.status = "FAILED"
    health.lastError = string.format("Expected: %s Received: %s", tostring(expected), tostring(received))
    health.lastErrorTime = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
    health.errorCount = health.errorCount + 1
    health.degraded = true

    -- Print structured error
    print(string.format("^1[DCE][DIAG][ERROR]^0"))
    print(string.format("^1  Subsystem: %s^0", subsystem))
    print(string.format("^1  Status: FAILED^0"))
    print(string.format("^1  Expected: %s^0", tostring(expected)))
    print(string.format("^1  Received: %s^0", tostring(received)))
    print(string.format("^1  Caller: %s^0", caller or "unknown"))
    print(string.format("^1  Stage: %s^0", stage or "unknown"))
    print(string.format("^1  Impact: %s unavailable. Other diagnostics continue operating.^0", subsystem))
end

--- Report a subsystem recovery
-- @param subsystem string - The subsystem name
function GracefulDegradation.ReportRecovery(subsystem)
    local health = subsystemHealth[subsystem]
    if health then
        health.status = "RECOVERED"
        health.degraded = false
        print(string.format("^2[DCE][DIAG] Subsystem %s recovered^0", subsystem))
    end
end

--- Mark a subsystem as operational
-- @param subsystem string - The subsystem name
function GracefulDegradation.MarkOperational(subsystem)
    local health = subsystemHealth[subsystem]
    if health then
        health.status = "OPERATIONAL"
        health.degraded = false
    end
end

--- Check if a subsystem is operational
-- @param subsystem string - The subsystem name
-- @return boolean - true if operational or degraded
function GracefulDegradation.IsOperational(subsystem)
    local health = subsystemHealth[subsystem]
    if not health then return false end
    return health.status == "OPERATIONAL" or health.status == "RECOVERED"
end

--- Check if a subsystem is in degraded mode
-- @param subsystem string - The subsystem name
-- @return boolean - true if degraded
function GracefulDegradation.IsDegraded(subsystem)
    local health = subsystemHealth[subsystem]
    if not health then return false end
    return health.degraded
end

--- Get the health status of a subsystem
-- @param subsystem string - The subsystem name
-- @return table|nil - The health record
function GracefulDegradation.GetHealth(subsystem)
    return subsystemHealth[subsystem]
end

--- Get all subsystem health records
-- @return table - All health records
function GracefulDegradation.GetAllHealth()
    return subsystemHealth
end

--- Get a summary of all subsystem health
-- @return table - Summary with counts
function GracefulDegradation.GetSummary()
    local summary = {
        total = 0,
        operational = 0,
        degraded = 0,
        failed = 0,
        unknown = 0,
        subsystems = {},
    }
    for name, health in pairs(subsystemHealth) do
        summary.total = summary.total + 1
        summary.subsystems[name] = health.status
        if health.status == "OPERATIONAL" or health.status == "RECOVERED" then
            summary.operational = summary.operational + 1
        elseif health.status == "FAILED" then
            summary.failed = summary.failed + 1
        elseif health.degraded then
            summary.degraded = summary.degraded + 1
        else
            summary.unknown = summary.unknown + 1
        end
    end
    return summary
end

--- Print the full health report
function GracefulDegradation.PrintHealthReport()
    print("^4=====================================^0")
    print("^4  Diagnostics Framework Status^0")
    print("^4=====================================^0")
    for _, name in ipairs(SUBSYSTEMS) do
        local health = subsystemHealth[name]
        if health then
            local color, icon, statusText
            if health.status == "OPERATIONAL" or health.status == "RECOVERED" then
                color = "2"
                icon = "PASS"
                statusText = health.status
            elseif health.degraded then
                color = "3"
                icon = "DEGRADED"
                statusText = health.status
            else
                color = "1"
                icon = "FAIL"
                statusText = health.status
            end
            print(string.format("^%s  %s %s [%s]^0", color, icon, name, statusText))
            if health.lastError then
                print(string.format("^1    Last Error: %s^0", health.lastError))
            end
        end
    end
    print("^4=====================================^0")
end

--- Safe execution wrapper
-- Wraps a function call with graceful degradation
-- @param subsystem string - The subsystem name
-- @param fn function - The function to execute
-- @param ... any - Arguments to pass to fn
-- @return boolean success, any result
function GracefulDegradation.SafeExecute(subsystem, fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        GracefulDegradation.ReportFailure(
            subsystem,
            "Successful execution",
            tostring(result),
            debug and debug.traceback and debug.traceback("", 2) or "unknown",
            "SafeExecute"
        )
        return false, result
    end
    GracefulDegradation.MarkOperational(subsystem)
    return true, result
end

--- Reset all health tracking
function GracefulDegradation.Reset()
    for _, name in ipairs(SUBSYSTEMS) do
        subsystemHealth[name] = {
            status = "UNKNOWN",
            lastError = nil,
            lastErrorTime = nil,
            errorCount = 0,
            degraded = false,
        }
    end
end

_G.DCEGracefulDegradation = GracefulDegradation
return GracefulDegradation