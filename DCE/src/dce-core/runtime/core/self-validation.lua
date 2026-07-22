-- DCE Framework Self-Validation (Phase 7)
-- The diagnostics framework validates itself before validating DCE.
-- This module checks:
--   - Runtime State
--   - Diagnostics Logger
--   - Module Loader
--   - Timeline
--   - Report Generator
--   - Command Registration
--   - Service Cache
--   - Event Cache
--   - Failure Handler (Graceful Degradation)

local SelfValidation = {}
local validationResults = {}

--- Validate RuntimeState
local function validateRuntimeState()
    local state = _G.DCERuntimeState
    if not state then
        return { name = "RuntimeState", status = "FAIL", reason = "DCERuntimeState global not found" }
    end
    if not state.initialized then
        return { name = "RuntimeState", status = "FAIL", reason = "Not initialized" }
    end
    if not state.id then
        return { name = "RuntimeState", status = "FAIL", reason = "No id set" }
    end
    -- Verify sub-structures exist
    if not state.bootTimeline then
        return { name = "RuntimeState", status = "DEGRADED", reason = "bootTimeline sub-state missing" }
    end
    if not state.diagnostics then
        return { name = "RuntimeState", status = "DEGRADED", reason = "diagnostics sub-state missing" }
    end
    if not state.serviceValidator then
        return { name = "RuntimeState", status = "DEGRADED", reason = "serviceValidator sub-state missing" }
    end
    if not state.moduleLoader then
        return { name = "RuntimeState", status = "DEGRADED", reason = "moduleLoader sub-state missing" }
    end
    if not state.ccDiagnostics then
        return { name = "RuntimeState", status = "DEGRADED", reason = "ccDiagnostics sub-state missing" }
    end
    if not state.report then
        return { name = "RuntimeState", status = "DEGRADED", reason = "report sub-state missing" }
    end
    if not state.commands then
        return { name = "RuntimeState", status = "DEGRADED", reason = "commands sub-state missing" }
    end
    return { name = "RuntimeState", status = "PASS" }
end

--- Validate Diagnostics Logger
local function validateDiagnostics()
    local diagnostics = _G.DCEDiagnostics
    if not diagnostics then
        return { name = "Diagnostics", status = "FAIL", reason = "DCEDiagnostics global not found" }
    end
    if type(diagnostics.Info) ~= "function" then
        return { name = "Diagnostics", status = "FAIL", reason = "Info method missing" }
    end
    if type(diagnostics.Warn) ~= "function" then
        return { name = "Diagnostics", status = "FAIL", reason = "Warn method missing" }
    end
    if type(diagnostics.Error) ~= "function" then
        return { name = "Diagnostics", status = "FAIL", reason = "Error method missing" }
    end
    if not diagnostics.IsReady then
        return { name = "Diagnostics", status = "DEGRADED", reason = "IsReady method missing" }
    end
    return { name = "Diagnostics", status = "PASS" }
end

--- Validate Module Loader
local function validateModuleLoader()
    local state = _G.DCERuntimeState
    if not state or not state.moduleLoader then
        return { name = "ModuleLoader", status = "FAIL", reason = "RuntimeState.moduleLoader not found" }
    end
    if state.moduleLoader.moduleCount == 0 then
        return { name = "ModuleLoader", status = "DEGRADED", reason = "No modules loaded yet (may be too early)" }
    end
    local result = { name = "ModuleLoader", status = "PASS", details = string.format("%d modules loaded, %d passed, %d failed", 
        state.moduleLoader.moduleCount, state.moduleLoader.passed, state.moduleLoader.failed) }
    if state.moduleLoader.failed > 0 then
        result.status = "DEGRADED"
        result.reason = string.format("%d module(s) failed to load", state.moduleLoader.failed)
    end
    return result
end

--- Validate Boot Timeline
local function validateTimeline()
    local bootTimeline = _G.DCEBootTimeline
    if not bootTimeline then
        return { name = "Timeline", status = "FAIL", reason = "DCEBootTimeline global not found" }
    end
    if type(bootTimeline.IsReady) ~= "function" then
        return { name = "Timeline", status = "FAIL", reason = "IsReady method missing" }
    end
    local ok, ready = pcall(bootTimeline.IsReady)
    if not ok then
        return { name = "Timeline", status = "FAIL", reason = "IsReady threw error: " .. tostring(ready) }
    end
    if not ready then
        return { name = "Timeline", status = "DEGRADED", reason = "Not initialized" }
    end
    if type(bootTimeline.GetStages) ~= "function" then
        return { name = "Timeline", status = "DEGRADED", reason = "GetStages method missing" }
    end
    return { name = "Timeline", status = "PASS" }
end

--- Validate Report Generator
local function validateReport()
    local runtimeReport = _G.DCERuntimeReport
    if not runtimeReport then
        return { name = "ReportGenerator", status = "FAIL", reason = "DCERuntimeReport global not found" }
    end
    if type(runtimeReport.Generate) ~= "function" then
        return { name = "ReportGenerator", status = "FAIL", reason = "Generate method missing" }
    end
    if type(runtimeReport.GetPlainTextSummary) ~= "function" then
        return { name = "ReportGenerator", status = "DEGRADED", reason = "GetPlainTextSummary method missing" }
    end
    return { name = "ReportGenerator", status = "PASS" }
end

--- Validate Command Registration
local function validateCommands()
    local diagnosticCommands = _G.DCEDiagnosticCommands
    if not diagnosticCommands then
        return { name = "Commands", status = "FAIL", reason = "DCEDiagnosticCommands global not found" }
    end
    if type(diagnosticCommands.IsRegistered) ~= "function" then
        return { name = "Commands", status = "DEGRADED", reason = "IsRegistered method missing" }
    end
    local ok, registered = pcall(diagnosticCommands.IsRegistered)
    if not ok then
        return { name = "Commands", status = "DEGRADED", reason = "IsRegistered threw error" }
    end
    if not registered then
        return { name = "Commands", status = "DEGRADED", reason = "Not registered yet (will register later)" }
    end
    return { name = "Commands", status = "PASS" }
end

--- Validate Service Cache
local function validateServiceCache()
    local state = _G.DCERuntimeState
    if not state or not state.serviceValidator then
        return { name = "ServiceCache", status = "FAIL", reason = "RuntimeState.serviceValidator not found" }
    end
    local validator = _G.DCEServiceValidator
    if not validator then
        return { name = "ServiceCache", status = "FAIL", reason = "DCEServiceValidator global not found" }
    end
    if type(validator.GetResults) ~= "function" then
        return { name = "ServiceCache", status = "DEGRADED", reason = "GetResults method missing" }
    end
    return { name = "ServiceCache", status = "PASS" }
end

--- Validate Event Cache
local function validateEventCache()
    local eventBus = DCEEventBus
    if not eventBus then
        return { name = "EventCache", status = "FAIL", reason = "DCEEventBus global not found" }
    end
    if type(eventBus.ListEvents) ~= "function" then
        return { name = "EventCache", status = "DEGRADED", reason = "ListEvents method missing" }
    end
    return { name = "EventCache", status = "PASS" }
end

--- Validate Graceful Degradation (Failure Handler)
local function validateFailureHandler()
    local gd = _G.DCEGracefulDegradation
    if not gd then
        return { name = "FailureHandler", status = "FAIL", reason = "DCEGracefulDegradation global not found" }
    end
    if type(gd.ReportFailure) ~= "function" then
        return { name = "FailureHandler", status = "FAIL", reason = "ReportFailure method missing" }
    end
    if type(gd.GetSummary) ~= "function" then
        return { name = "FailureHandler", status = "DEGRADED", reason = "GetSummary method missing" }
    end
    if type(gd.PrintHealthReport) ~= "function" then
        return { name = "FailureHandler", status = "DEGRADED", reason = "PrintHealthReport method missing" }
    end
    return { name = "FailureHandler", status = "PASS" }
end

--- Validate Service Validator
local function validateServiceValidator()
    local validator = _G.DCEServiceValidator
    if not validator then
        return { name = "ServiceValidator", status = "FAIL", reason = "DCEServiceValidator global not found" }
    end
    if type(validator.ValidateServices) ~= "function" then
        return { name = "ServiceValidator", status = "DEGRADED", reason = "ValidateServices method missing" }
    end
    if type(validator.GetSummary) ~= "function" then
        return { name = "ServiceValidator", status = "DEGRADED", reason = "GetSummary method missing" }
    end
    return { name = "ServiceValidator", status = "PASS" }
end

--- Validate CC Diagnostics
local function validateCCDiagnostics()
    local ccDiag = _G.DCECCDiagnostics
    if not ccDiag then
        return { name = "CCDiagnostics", status = "FAIL", reason = "DCECCDiagnostics global not found" }
    end
    if type(ccDiag.GetState) ~= "function" then
        return { name = "CCDiagnostics", status = "DEGRADED", reason = "GetState method missing" }
    end
    return { name = "CCDiagnostics", status = "PASS" }
end

--- Run all self-validations
-- @return table of validation results
function SelfValidation.RunAll()
    print("^4=====================================^0")
    print("^4  Diagnostics Framework Self-Validation^0")
    print("^4=====================================^0")

    validationResults = {}

    local validators = {
        validateRuntimeState,
        validateDiagnostics,
        validateModuleLoader,
        validateTimeline,
        validateReport,
        validateCommands,
        validateServiceCache,
        validateEventCache,
        validateFailureHandler,
        validateServiceValidator,
        validateCCDiagnostics,
    }

    local passed = 0
    local failed = 0
    local degraded = 0

    for _, validatorFn in ipairs(validators) do
        local ok, result = pcall(validatorFn)
        if not ok then
            result = {
                name = "Unknown",
                status = "FAIL",
                reason = "Validation threw error: " .. tostring(result),
            }
        end
        table.insert(validationResults, result)

        local color = "2"
        local icon = "PASS"
        if result.status == "FAIL" then
            color = "1"
            icon = "FAIL"
            failed = failed + 1
        elseif result.status == "DEGRADED" then
            color = "3"
            icon = "DEGRADED"
            degraded = degraded + 1
        else
            passed = passed + 1
        end

        print(string.format("^%s  %s %s [%s]^0", color, icon, result.name, result.status))
        if result.reason then
            print(string.format("^%s    %s^0", color, result.reason))
        end
        if result.details then
            print(string.format("^4    %s^0", result.details))
        end
    end

    print("^4-------------------------------------^0")
    local summaryColor = (failed == 0) and "2" or "1"
    print(string.format("^%s  Self-Validation Complete: %d/%d passed, %d degraded, %d failed^0",
        summaryColor, passed, #validators, degraded, failed))
    print("^4=====================================^0")

    return validationResults
end

--- Get self-validation results
function SelfValidation.GetResults()
    return validationResults
end

--- Print a summary of self-validation results
function SelfValidation.PrintSummary()
    local passed = 0
    local failed = 0
    local degraded = 0
    for _, result in ipairs(validationResults) do
        if result.status == "PASS" then
            passed = passed + 1
        elseif result.status == "FAIL" then
            failed = failed + 1
        elseif result.status == "DEGRADED" then
            degraded = degraded + 1
        end
    end
    print("^4Diagnostics Framework Self-Validation Summary^0")
    print(string.format("  PASS: %d", passed))
    print(string.format("  DEGRADED: %d", degraded))
    print(string.format("  FAIL: %d", failed))
    print(string.format("  Total: %d", #validationResults))
end

_G.DCESelfValidation = SelfValidation
return SelfValidation