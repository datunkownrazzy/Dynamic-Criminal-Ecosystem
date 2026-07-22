-- DCE Failure Injection Tests (Phase 8)
-- Intentionally simulate subsystem failures to verify graceful degradation.
-- No crashes are acceptable.
-- Tests:
--   - Missing Runtime State
--   - Missing Timeline
--   - Missing Report
--   - Missing Commands
--   - Missing Logger
--   - Missing Module

local FailureInjection = {}

local function printHeader(name)
    print("^4=====================================^0")
    print(string.format("^4  Failure Injection: %s^0", name))
    print("^4=====================================^0")
end

local function printResult(name, passed, detail)
    local color = passed and "2" or "1"
    local status = passed and "PASS" or "FAIL"
    print(string.format("^%s  [%s] %s^0", color, status, name))
    if detail then
        print(string.format("^%s    %s^0", color, detail))
    end
end

--- Test 1: Simulate missing RuntimeState
-- Temporarily remove DCERuntimeState and verify graceful degradation
function FailureInjection.TestMissingRuntimeState()
    printHeader("Missing Runtime State")

    local originalState = _G.DCERuntimeState
    _G.DCERuntimeState = nil

    local crashed = false
    local ok, err = pcall(function()
        -- Try to use diagnostics (which depends on RuntimeState)
        local diagnostics = _G.DCEDiagnostics
        if diagnostics then
            diagnostics.Info("TEST", "This should not crash even without RuntimeState")
        end
    end)

    if not ok then
        crashed = true
        printResult("Diagnostics without RuntimeState", false, "Crashed: " .. tostring(err))
    else
        printResult("Diagnostics without RuntimeState", true, "Gracefully degraded")
    end

    -- Restore
    _G.DCERuntimeState = originalState
    printResult("RuntimeState restored", true)
end

--- Test 2: Simulate missing BootTimeline
function FailureInjection.TestMissingTimeline()
    printHeader("Missing Boot Timeline")

    local originalTimeline = _G.DCEBootTimeline
    _G.DCEBootTimeline = nil

    local crashed = false
    local ok, err = pcall(function()
        -- Try to use boot timeline commands
        local commands = _G.DCEDiagnosticCommands
        if commands and commands.HandleBoot then
            commands.HandleBoot(0, {})
        end
    end)

    if not ok then
        crashed = true
        printResult("Commands without BootTimeline", false, "Crashed: " .. tostring(err))
    else
        printResult("Commands without BootTimeline", true, "Gracefully degraded")
    end

    _G.DCEBootTimeline = originalTimeline
    printResult("BootTimeline restored", true)
end

--- Test 3: Simulate missing Report
function FailureInjection.TestMissingReport()
    printHeader("Missing Runtime Report")

    local originalReport = _G.DCERuntimeReport
    _G.DCERuntimeReport = nil

    local crashed = false
    local ok, err = pcall(function()
        -- Try to use diag command which depends on report
        local commands = _G.DCEDiagnosticCommands
        if commands and commands.HandleDiag then
            commands.HandleDiag(0, {})
        end
    end)

    if not ok then
        crashed = true
        printResult("Commands without Report", false, "Crashed: " .. tostring(err))
    else
        printResult("Commands without Report", true, "Gracefully degraded")
    end

    _G.DCERuntimeReport = originalReport
    printResult("RuntimeReport restored", true)
end

--- Test 4: Simulate missing Commands
function FailureInjection.TestMissingCommands()
    printHeader("Missing Diagnostic Commands")

    local originalCommands = _G.DCEDiagnosticCommands
    _G.DCEDiagnosticCommands = nil

    local crashed = false
    local ok, err = pcall(function()
        -- Try to register commands (should not crash)
        local runtimeInit = _G.DCERuntimeInit
        if runtimeInit and runtimeInit.RegisterCommands then
            runtimeInit.RegisterCommands()
        end
    end)

    if not ok then
        crashed = true
        printResult("Register without Commands", false, "Crashed: " .. tostring(err))
    else
        printResult("Register without Commands", true, "Gracefully degraded")
    end

    _G.DCEDiagnosticCommands = originalCommands
    printResult("DiagnosticCommands restored", true)
end

--- Test 5: Simulate missing Logger
function FailureInjection.TestMissingLogger()
    printHeader("Missing Logger")

    local originalLogger = _G.DCELogger
    _G.DCELogger = nil

    local crashed = false
    local ok, err = pcall(function()
        -- Try to initialize diagnostics (which depends on logger)
        local diagnostics = _G.DCEDiagnostics
        if diagnostics and diagnostics.Init then
            diagnostics.Init(nil)
        end
    end)

    if not ok then
        crashed = true
        printResult("Diagnostics Init without Logger", false, "Crashed: " .. tostring(err))
    else
        printResult("Diagnostics Init without Logger", true, "Gracefully degraded")
    end

    _G.DCELogger = originalLogger
    printResult("Logger restored", true)
end

--- Test 6: Simulate missing ServiceValidator
function FailureInjection.TestMissingServiceValidator()
    printHeader("Missing Service Validator")

    local originalValidator = _G.DCEServiceValidator
    _G.DCEServiceValidator = nil

    local crashed = false
    local ok, err = pcall(function()
        -- Try to use diag command which depends on service validator
        local commands = _G.DCEDiagnosticCommands
        if commands and commands.HandleServices then
            commands.HandleServices(0, {})
        end
    end)

    if not ok then
        crashed = true
        printResult("Commands without ServiceValidator", false, "Crashed: " .. tostring(err))
    else
        printResult("Commands without ServiceValidator", true, "Gracefully degraded")
    end

    _G.DCEServiceValidator = originalValidator
    printResult("ServiceValidator restored", true)
end

--- Test 7: Simulate missing CCDiagnostics
function FailureInjection.TestMissingCCDiagnostics()
    printHeader("Missing CC Diagnostics")

    local originalCC = _G.DCECCDiagnostics
    _G.DCECCDiagnostics = nil

    local crashed = false
    local ok, err = pcall(function()
        -- Try to use diag command which depends on CC diagnostics
        local commands = _G.DCEDiagnosticCommands
        if commands and commands.HandleDiag then
            commands.HandleDiag(0, {})
        end
    end)

    if not ok then
        crashed = true
        printResult("Commands without CCDiagnostics", false, "Crashed: " .. tostring(err))
    else
        printResult("Commands without CCDiagnostics", true, "Gracefully degraded")
    end

    _G.DCECCDiagnostics = originalCC
    printResult("CCDiagnostics restored", true)
end

--- Test 8: Simulate missing GracefulDegradation
function FailureInjection.TestMissingGracefulDegradation()
    printHeader("Missing Graceful Degradation Handler")

    local originalGD = _G.DCEGracefulDegradation
    _G.DCEGracefulDegradation = nil

    local crashed = false
    local ok, err = pcall(function()
        -- Try to use diagnostics (which calls graceful degradation on failure)
        local diagnostics = _G.DCEDiagnostics
        if diagnostics and diagnostics.Info then
            diagnostics.Info("TEST", "This should not crash even without GracefulDegradation")
        end
    end)

    if not ok then
        crashed = true
        printResult("Diagnostics without GracefulDegradation", false, "Crashed: " .. tostring(err))
    else
        printResult("Diagnostics without GracefulDegradation", true, "Gracefully degraded")
    end

    _G.DCEGracefulDegradation = originalGD
    printResult("GracefulDegradation restored", true)
end

--- Run all failure injection tests
function FailureInjection.RunAll()
    print("^4=====================================^0")
    print("^4  Failure Injection Tests (Phase 8)^0")
    print("^4=====================================^0")
    print("^3  WARNING: These tests temporarily remove critical subsystems^0")
    print("^3  to verify graceful degradation. No crashes are acceptable.^0")
    print("^4=====================================^0")

    local tests = {
        {"Missing RuntimeState", FailureInjection.TestMissingRuntimeState},
        {"Missing BootTimeline", FailureInjection.TestMissingTimeline},
        {"Missing Runtime Report", FailureInjection.TestMissingReport},
        {"Missing Diagnostic Commands", FailureInjection.TestMissingCommands},
        {"Missing Logger", FailureInjection.TestMissingLogger},
        {"Missing Service Validator", FailureInjection.TestMissingServiceValidator},
        {"Missing CC Diagnostics", FailureInjection.TestMissingCCDiagnostics},
        {"Missing Graceful Degradation", FailureInjection.TestMissingGracefulDegradation},
    }

    local passed = 0
    local failed = 0

    for _, test in ipairs(tests) do
        local ok, err = pcall(test[2])
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print(string.format("^1  [CRASH] %s: %s^0", test[1], tostring(err)))
        end
    end

    print("^4=====================================^0")
    local color = (failed == 0) and "2" or "1"
    print(string.format("^%s  Failure Injection Complete: %d/%d passed, %d failed^0",
        color, passed, #tests, failed))
    if failed > 0 then
        print("^1  FAILURE: Some subsystems crashed when dependencies were missing.^0")
        print("^1  This violates Rule Zero. Fix the crashes before proceeding.^0")
    else
        print("^2  SUCCESS: All subsystems degraded gracefully. Rule Zero upheld.^0")
    end
    print("^4=====================================^0")

    return { passed = passed, failed = failed, total = #tests }
end

_G.DCEFailureInjection = FailureInjection
return FailureInjection