-- DCE Runtime Report
-- Phase 10: Runtime Report
-- NOTE: "undefined-field" diagnostics below are false positives from LuaLS.
-- ccState.failure is a dynamically-assigned table accessed via nil-safe patterns.
-- The `ccState.failure and ccState.failure.stage` pattern is intentional runtime safety.
---@diagnostic disable: undefined-field
-- After startup, generate a complete runtime diagnostic report.
-- Output format:
-- =====================================
-- DCE Runtime Report
-- =====================================
-- Version
-- Startup Time
-- Services
-- Exports
-- Events
-- Resources
-- Warnings
-- Errors
-- Performance
-- =====================================
--
-- DF-002 FIX: State is now stored in centralized RuntimeState (DCERuntimeState.report)
-- No local state ownership. All modules consume shared state.

local RuntimeReport = {}

--- Get report state from RuntimeState
local function getState()
    local state = _G.DCERuntimeState
    if state and state.report then
        return state.report
    end
    local gd = _G.DCEGracefulDegradation
    if gd and gd.ReportFailure then
        gd.ReportFailure("Report", "RuntimeState.report", "nil", "report.lua", "getState")
    end
    return nil
end

--- Initialize the runtime report generator
function RuntimeReport.Init()
    local repState = getState()
    if repState then
        repState.initialized = true
        repState.generated = false
        repState.lastReport = nil
    end

    -- Mark subsystem operational
    local gd = _G.DCEGracefulDegradation
    if gd and gd.MarkOperational then
        gd.MarkOperational("Report")
    end
end

--- Get the DCE version
local function getVersion()
    if DCE and DCE.GetService then
        local registry = DCE.GetService("CoreRegistry")
        if registry and registry.GetDCEVersion then
            local ok, version = pcall(registry.GetDCEVersion)
            if ok then return version end
        end
    end

    if DCE and DCE.GetServiceOrThrow then
        local ok, result = pcall(DCE.GetServiceOrThrow, "CoreRegistry")
        if ok and result and result.GetDCEVersion then
            local ok2, version = pcall(result.GetDCEVersion)
            if ok2 then return version end
        end
    end

    return "1.0.0"
end

--- Collect all diagnostic data into a structured report
local function collectReport()
    local report = {
        generated = os.time(),
        version = getVersion(),
        startupTime = nil,
        services = { passed = 0, failed = 0, total = 0, items = {} },
        exports = { passed = 0, failed = 0, total = 0, items = {} },
        api = { passed = 0, failed = 0, total = 0, items = {} },
        events = { active = 0, total = 0, items = {} },
        resources = { started = 0, total = 0, items = {} },
        warnings = { count = 0, items = {} },
        errors = { count = 0, items = {} },
        performance = {},
        bootTimeline = {},
        ccTransitions = {},
        assertions = {},
    }

    -- Get boot timeline
    local bootTimeline = _G.DCEBootTimeline
    if bootTimeline and bootTimeline.GetTotalTime then
        report.startupTime = bootTimeline.GetTotalTimeMs()
        report.bootTimeline = bootTimeline.GetStages()
    end

    -- Get service validator results
    local validator = _G.DCEServiceValidator
    if validator then
        local ok_getsummary, summary = pcall(validator.GetSummary)
        local ok_getresults, results = pcall(validator.GetResults)

        if ok_getsummary and summary then
            report.services.passed = summary.passedServices or 0
            report.services.failed = summary.failedServices or 0
            report.services.total = summary.totalServices or 0
            report.exports.passed = summary.passedExports or 0
            report.exports.failed = summary.failedExports or 0
            report.exports.total = summary.totalExports or 0
            report.api.passed = summary.passedAPI or 0
            report.api.failed = summary.failedAPI or 0
            report.api.total = summary.totalAPI or 0
            report.events.active = summary.activeEvents or 0
            report.events.total = summary.totalEvents or 0
            report.resources.started = summary.startedDeps or 0
            report.resources.total = summary.totalDeps or 0
        end

        if ok_getresults and results then
            report.services.items = results.services.list or {}
            report.exports.items = results.exports.list or {}
            report.api.items = results.api.list or {}
            report.events.items = results.events.list or {}
            report.resources.items = results.dependencies.list or {}
        end
    end

    -- Get diagnostics warnings/errors
    local diagnostics = _G.DCEDiagnostics
    if diagnostics then
        if diagnostics.GetWarnings then
            local ok, warnItems = pcall(diagnostics.GetWarnings)
            if ok then
                report.warnings.count = #warnItems
                report.warnings.items = warnItems
            end
        end
        if diagnostics.GetErrors then
            local ok, errItems = pcall(diagnostics.GetErrors)
            if ok then
                report.errors.count = #errItems
                report.errors.items = errItems
            end
        end
        if diagnostics.GetAssertionFailures then
            local ok, assertions = pcall(diagnostics.GetAssertionFailures)
            if ok then
                report.assertions = assertions
            end
        end
    end

    -- Get CC diagnostics
    local ccDiag = _G.DCECCDiagnostics
    if ccDiag and ccDiag.GetTransitions then
        local ok, transitions = pcall(ccDiag.GetTransitions)
        if ok then
            report.ccTransitions = transitions
        end
    end

    -- Performance metrics
    local eventBus = DCEEventBus
    if eventBus and eventBus.GetMetrics then
        local ok, metrics = pcall(eventBus.GetMetrics)
        if ok then
            report.performance.eventBus = metrics
        end
    end

    if bootTimeline and bootTimeline.GetTotalTime then
        report.performance.bootTime = bootTimeline.GetTotalTimeMs()
    end

    return report
end

--- Generate and print the runtime report
function RuntimeReport.Generate()
    local repState = getState()
    if not repState then
        -- Try to initialize on the fly (graceful degradation)
        RuntimeReport.Init()
        repState = getState()
    end

    print("^4=====================================^0")
    print("^4        DCE Runtime Report^0")
    print("^4=====================================^0")

    local ok, report = pcall(collectReport)
    if not ok then
        print(string.format("^1[DCE][REPORT] Failed to collect report data: %s^0", tostring(report)))
        print("^4=====================================^0")
        return nil
    end

    if repState then
        repState.lastReport = report
        repState.generated = true
    end

    -- Version
    print(string.format("^4Version:^0 %s", report.version))

    -- Startup Time
    if report.startupTime then
        print(string.format("^4Startup Time:^0 %dms (%.3fs)", report.startupTime, report.startupTime / 1000))
    end

    -- Boot Timeline
    if #report.bootTimeline > 0 then
        local lastStage = report.bootTimeline[#report.bootTimeline]
        print(string.format("^4Boot Stages:^0 %d (last: %s)", #report.bootTimeline, lastStage.name or "unknown"))
    end

    print("^4-------------------------------------^0")

    -- Services
    local svcIcon = (report.services.failed == 0) and "2✓" or "1✗"
    print(string.format("^%sServices:^0 %d/%d passed (%d failed)", svcIcon, 
        report.services.passed, report.services.total, report.services.failed))

    -- Exports
    local expIcon = (report.exports.failed == 0) and "2✓" or "1✗"
    print(string.format("^%sExports:^0 %d/%d ready (%d failed)", expIcon,
        report.exports.passed, report.exports.total, report.exports.failed))

    -- API
    local apiIcon = (report.api.failed == 0) and "2✓" or "1✗"
    print(string.format("^%sAPI Functions:^0 %d/%d passed (%d failed)", apiIcon,
        report.api.passed, report.api.total, report.api.failed))

    -- Events
    print(string.format("^4Events:^0 %d active / %d total", report.events.active, report.events.total))

    -- Resources
    print(string.format("^4Resources:^0 %d/%d started", report.resources.started, report.resources.total))

    -- Warnings
    local warnColor = (report.warnings.count == 0) and "2" or "3"
    print(string.format("^%sWarnings:^0 %d", warnColor, report.warnings.count))

    -- Errors
    local errColor = (report.errors.count == 0) and "2" or "1"
    print(string.format("^%sErrors:^0 %d", errColor, report.errors.count))

    -- Assertions
    if #report.assertions > 0 then
        print(string.format("^1Assertion Failures:^0 %d", #report.assertions))
        for _, a in ipairs(report.assertions) do
            print(string.format("^1  - %s^0", a.message))
        end
    end

    -- Performance
    print("^4-------------------------------------^0")
    print("^4Performance:^0")
    if report.performance.bootTime then
        print(string.format("  Boot Time: %dms", report.performance.bootTime))
    end
    if report.performance.eventBus then
        print(string.format("  Event Dispatches: %d", report.performance.eventBus.totalDispatches or 0))
        print(string.format("  Event Errors: %d", report.performance.eventBus.totalErrors or 0))
        print(string.format("  Event Skips: %d", report.performance.eventBus.totalSkipped or 0))
    end

    -- CC Status
    local ccDiag = _G.DCECCDiagnostics
    if ccDiag then
        local ok, ccState = pcall(ccDiag.GetState)
        if ok and ccState then
            if ccState.completed then
                print("^2Control Center: STARTED SUCCESSFULLY^0")
            elseif ccState.failed then
                print(string.format("^1Control Center: FAILED at stage '%s'^0", 
                    ccState.failure and ccState.failure.stage or "unknown"))
                if ccState.failure then
                    print(string.format("^1  Reason: %s^0", ccState.failure.reason or "unknown"))
                    print(string.format("^1  File: %s^0", ccState.failure.file or "unknown"))
                    print(string.format("^1  Function: %s^0", ccState.failure.func or "unknown"))
                end
            else
                print("^3Control Center: Not started^0")
            end
        end
    end

    print("^4=====================================^0")
    print("^4      End of Runtime Report^0")
    print("^4=====================================^0")

    return report
end

--- Get the last generated report
function RuntimeReport.GetLastReport()
    local repState = getState()
    return repState and repState.lastReport or nil
end

--- Check if a report has been generated
function RuntimeReport.HasReport()
    local repState = getState()
    return repState and repState.generated or false
end

--- Get a plain-text summary for diagnostic commands
function RuntimeReport.GetPlainTextSummary()
    local repState = getState()
    local report = repState and repState.lastReport
    if not report then
        local ok, collected = pcall(collectReport)
        if ok then report = collected end
    end
    if not report then return "Report unavailable" end

    local lines = {}
    table.insert(lines, "=== DCE Runtime Summary ===")
    table.insert(lines, string.format("Version: %s", report.version))
    if report.startupTime then
        table.insert(lines, string.format("Startup: %dms", report.startupTime))
    end
    table.insert(lines, string.format("Services: %d/%d OK", report.services.passed, report.services.total))
    table.insert(lines, string.format("Exports: %d/%d OK", report.exports.passed, report.exports.total))
    table.insert(lines, string.format("API: %d/%d OK", report.api.passed, report.api.total))
    table.insert(lines, string.format("Events: %d active", report.events.active))
    table.insert(lines, string.format("Resources: %d/%d started", report.resources.started, report.resources.total))
    table.insert(lines, string.format("Warnings: %d", report.warnings.count))
    table.insert(lines, string.format("Errors: %d", report.errors.count))
    table.insert(lines, string.format("Assertions: %d", #report.assertions))
    return table.concat(lines, "\n")
end

--- Reset the report generator
function RuntimeReport.Reset()
    local repState = getState()
    if repState then
        repState.generated = false
        repState.lastReport = nil
    end
end

_G.DCERuntimeReport = RuntimeReport
return RuntimeReport