-- DCE Runtime Diagnostic Framework Initializer
-- Ties together all runtime diagnostic modules and integrates them into core initialization.
-- Called from dce-core/init.lua during InitializeCore()
--
-- DF-001 FIX: Replaced require() calls with global lookups.
--   Root Cause: FiveM's Lua module loader does not resolve relative paths like
--   "runtime.diagnostics" from within the runtime/ directory. The modules are
--   already loaded via fxmanifest.lua in dependency order, so they exist as
--   globals (_G.DCEDiagnostics, _G.DCEBootTimeline, etc.). The require() calls
--   fail because Lua's package.path doesn't include the runtime/ subdirectory.
--
-- DF-002 FIX: All modules now consume centralized RuntimeState via _G.DCERuntimeState.
--   No module owns its own state. Every subsystem reads from the same shared state.

local RuntimeInit = {}

-- Instrumented module loader with pass/fail tracking
local moduleLoadResults = {}

local function instrumentedLoad(moduleName, globalName, fn)
    local startTime = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
    local ok, err = pcall(fn)
    local elapsed = (GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)) - startTime

    local result = {
        module = moduleName,
        global = globalName,
        success = ok,
        error = err,
        timeMs = elapsed,
    }
    table.insert(moduleLoadResults, result)

    -- Track in RuntimeState
    local state = _G.DCERuntimeState
    if state and state.moduleLoader then
        state.moduleLoader.moduleCount = state.moduleLoader.moduleCount + 1
        state.moduleLoader.modules[moduleName] = result
        state.moduleLoader.totalTimeMs = state.moduleLoader.totalTimeMs + elapsed
        if ok then
            state.moduleLoader.passed = state.moduleLoader.passed + 1
        else
            state.moduleLoader.failed = state.moduleLoader.failed + 1
        end
    end

    if ok then
        print(string.format("^2[DCE][LOAD] Loading %s.lua PASS (%.1fms)^0", moduleName, elapsed))
    else
        print(string.format("^1[DCE][LOAD] Loading %s.lua FAIL^0", moduleName))
        print(string.format("^1[DCE][LOAD]   Reason: %s^0", tostring(err)))
        -- Report to graceful degradation
        local gd = _G.DCEGracefulDegradation
        if gd and gd.ReportFailure then
            gd.ReportFailure(
                moduleName,
                "Module loaded successfully",
                tostring(err),
                "runtime/init.lua",
                "Module Loading"
            )
        end
    end
    return ok
end

--- Initialize all runtime diagnostic modules
function RuntimeInit.Initialize(logger)
    print("^4[DCE][RUNTIME] === Runtime Diagnostic Framework Initializing ===^0")

    -- Step 0: Initialize RuntimeState (centralized state)
    instrumentedLoad("runtime.core.state", "DCERuntimeState", function()
        local RuntimeState = _G.DCERuntimeState
        if RuntimeState and RuntimeState.Init then
            RuntimeState.Init()
            -- Mark RuntimeState as operational in graceful degradation
            local gd = _G.DCEGracefulDegradation
            if gd and gd.MarkOperational then
                gd.MarkOperational("RuntimeState")
            end
        end
    end)

    -- Step 0.5: Initialize Graceful Degradation handler
    instrumentedLoad("runtime.core.graceful-degradation", "DCEGracefulDegradation", function()
        local gd = _G.DCEGracefulDegradation
        if gd and gd.MarkOperational then
            gd.MarkOperational("ModuleLoader")
        end
    end)

    -- Phase 1: Initialize Runtime Diagnostics (no deps beyond logger)
    instrumentedLoad("runtime.diagnostics", "DCEDiagnostics", function()
        local Diagnostics = _G.DCEDiagnostics
        if Diagnostics and Diagnostics.Init then
            Diagnostics.Init(logger)
            Diagnostics.Info("RUNTIME", "Runtime Diagnostic Logger initialized")
        end
    end)

    -- Phase 2: Initialize Boot Timeline
    instrumentedLoad("runtime.boot-timeline", "DCEBootTimeline", function()
        local BootTimeline = _G.DCEBootTimeline
        if BootTimeline and BootTimeline.Init then
            BootTimeline.Init()
        end
    end)

    -- Phase 3: Initialize Service Validator
    instrumentedLoad("runtime.service-validator", "DCEServiceValidator", function()
        local ServiceValidator = _G.DCEServiceValidator
        if ServiceValidator and ServiceValidator.Init then
            ServiceValidator.Init()
        end
    end)

    -- Phase 8: Initialize CC Diagnostics
    instrumentedLoad("runtime.cc-diagnostics", "DCECCDiagnostics", function()
        local CCDiagnostics = _G.DCECCDiagnostics
        if CCDiagnostics and CCDiagnostics.Init then
            CCDiagnostics.Init()
        end
    end)

    -- Phase 9: Initialize Contract Validator (Sprint 1.6B)
    instrumentedLoad("runtime.contract-validator", "DCEContractValidator", function()
        local ContractValidator = _G.DCEContractValidator
        if ContractValidator and ContractValidator.Init then
            ContractValidator.Init()
        end
    end)

    -- Phase 9B: Initialize Contract Verifier (Sprint 1.7 — Complete Architectural Verification)
    instrumentedLoad("runtime.contract-verifier", "DCEContractVerifier", function()
        local ContractVerifier = _G.DCEContractVerifier
        if ContractVerifier and ContractVerifier.Init then
            ContractVerifier.Init()
        end
    end)

    -- Phase 10: Initialize Runtime Report
    instrumentedLoad("runtime.report", "DCERuntimeReport", function()
        local RuntimeReport = _G.DCERuntimeReport
        if RuntimeReport and RuntimeReport.Init then
            RuntimeReport.Init()
        end
    end)

    -- Phase 11: Initialize Diagnostic Commands
    instrumentedLoad("runtime.commands", "DCEDiagnosticCommands", function()
        local DiagnosticCommands = _G.DCEDiagnosticCommands
        if DiagnosticCommands and DiagnosticCommands.Init then
            DiagnosticCommands.Init()
        end
    end)

    -- Print module load summary
    local state = _G.DCERuntimeState
    if state and state.moduleLoader then
        print(string.format("^4[DCE][RUNTIME] Module Load Summary: %d/%d passed (%d failed) in %.1fms^0",
            state.moduleLoader.passed,
            state.moduleLoader.moduleCount,
            state.moduleLoader.failed,
            state.moduleLoader.totalTimeMs))
    end

    print("^4[DCE][RUNTIME] === Runtime Diagnostic Framework Initialized ===^0")
end

--- Run all startup validations
function RuntimeInit.RunStartupValidations()
    print("^4[DCE][RUNTIME] === Running Startup Validations ===^0")

    -- Phase 3: Validate Services
    instrumentedLoad("validation.services", "DCEServiceValidator", function()
        local ServiceValidator = _G.DCEServiceValidator
        if ServiceValidator and ServiceValidator.ValidateServices then
            ServiceValidator.ValidateServices()
        end
    end)

    -- Phase 4: Validate Exports
    instrumentedLoad("validation.exports", "DCEServiceValidator", function()
        local ServiceValidator = _G.DCEServiceValidator
        if ServiceValidator and ServiceValidator.ValidateExports then
            ServiceValidator.ValidateExports()
        end
    end)

    -- Phase 5: Validate API
    instrumentedLoad("validation.api", "DCEServiceValidator", function()
        local ServiceValidator = _G.DCEServiceValidator
        if ServiceValidator and ServiceValidator.ValidateAPI then
            ServiceValidator.ValidateAPI()
        end
    end)

    -- Phase 6: Validate Dependencies
    instrumentedLoad("validation.dependencies", "DCEServiceValidator", function()
        local ServiceValidator = _G.DCEServiceValidator
        if ServiceValidator and ServiceValidator.ValidateDependencies then
            ServiceValidator.ValidateDependencies()
        end
    end)

    -- Phase 7: Validate Events
    instrumentedLoad("validation.events", "DCEServiceValidator", function()
        local ServiceValidator = _G.DCEServiceValidator
        if ServiceValidator and ServiceValidator.ValidateEvents then
            ServiceValidator.ValidateEvents()
        end
    end)

    -- Phase 9: Run Contract Validator (Sprint 1.6B)
    instrumentedLoad("validation.contract", "DCEContractValidator", function()
        local ContractValidator = _G.DCEContractValidator
        if ContractValidator and ContractValidator.RunAll then
            ContractValidator.RunAll()
        end
    end)

    -- Phase 10: Generate Runtime Report
    instrumentedLoad("validation.report", "DCERuntimeReport", function()
        local RuntimeReport = _G.DCERuntimeReport
        if RuntimeReport and RuntimeReport.Generate then
            RuntimeReport.Generate()
        end
    end)

    -- Sprint 1.7: Run Complete Architectural Contract Verification
    instrumentedLoad("validation.contract-verifier", "DCEContractVerifier", function()
        local ContractVerifier = _G.DCEContractVerifier
        if ContractVerifier and ContractVerifier.RunAll then
            ContractVerifier.RunAll()
        end
    end)

    print("^4[DCE][RUNTIME] === Startup Validations Complete ===^0")
end

--- Register diagnostic commands
function RuntimeInit.RegisterCommands()
    instrumentedLoad("commands.register", "DCEDiagnosticCommands", function()
        local DiagnosticCommands = _G.DCEDiagnosticCommands
        if DiagnosticCommands and DiagnosticCommands.Register then
            DiagnosticCommands.Register()
        end
    end)
end

--- Run health check (can be called at any time)
function RuntimeInit.RunHealthCheck()
    print("^4[DCE][RUNTIME] === Health Check ===^0")

    -- Re-validate everything
    instrumentedLoad("health.services", "DCEServiceValidator", function()
        local ServiceValidator = _G.DCEServiceValidator
        if ServiceValidator and ServiceValidator.ValidateServices then
            ServiceValidator.ValidateServices()
        end
    end)

    instrumentedLoad("health.exports", "DCEServiceValidator", function()
        local ServiceValidator = _G.DCEServiceValidator
        if ServiceValidator and ServiceValidator.ValidateExports then
            ServiceValidator.ValidateExports()
        end
    end)

    instrumentedLoad("health.dependencies", "DCEServiceValidator", function()
        local ServiceValidator = _G.DCEServiceValidator
        if ServiceValidator and ServiceValidator.ValidateDependencies then
            ServiceValidator.ValidateDependencies()
        end
    end)

    instrumentedLoad("health.events", "DCEServiceValidator", function()
        local ServiceValidator = _G.DCEServiceValidator
        if ServiceValidator and ServiceValidator.ValidateEvents then
            ServiceValidator.ValidateEvents()
        end
    end)

    -- Generate fresh report
    instrumentedLoad("health.report", "DCERuntimeReport", function()
        local RuntimeReport = _G.DCERuntimeReport
        if RuntimeReport and RuntimeReport.Generate then
            RuntimeReport.Generate()
        end
    end)

    print("^4[DCE][RUNTIME] === Health Check Complete ===^0")
end

--- Get module load results
function RuntimeInit.GetModuleLoadResults()
    return moduleLoadResults
end

_G.DCERuntimeInit = RuntimeInit
return RuntimeInit