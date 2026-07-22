-- DCE Sprint 1.10 — Test Suite Bootstrap
-- Single authoritative entry point for the entire validation suite.
-- Uses an explicit Citizen.CreateThread for the bootstrap lifecycle.
-- No passive module loading. No require() side effects. No global discovery.
-- Consumes ONLY the published SDK — no Core internals.
--
-- CANONICAL SDK ACCESS:
-- Every test MUST use exports['dce-core']:GetDCEAPI() to obtain the DCE table.
-- _G.DCE is NOT part of the public platform contract.
-- No production resource may depend on _G.DCE.
--
-- CRITICAL: FiveM gives each resource its own Lua global table.
-- globals set by dce-core (like _G.DCE, _G.DCERegistry, _G.DCEEventBus, etc.)
-- are NOT accessible from dce-test-suite's global scope.
-- The ONLY reliable cross-resource access mechanism is exports.
-- Consumers MUST use: exports['dce-core']:GetDCEAPI()
-- Consumers MUST use: exports['dce-core']:IsReady()

local Bootstrap = {
    name = "DCE Sprint 1.10 Platform Validation",
    version = "1.0.0",
    startTime = os.time(),
    phases = {},
    phaseModules = {},
    results = {
        passed = 0,
        failed = 0,
        skipped = 0,
        errors = {},
    },
    phaseResults = {},
    harness = nil,
}

-- ============================================================================
-- Canonical SDK Reference (resolved once, used by all phases)
-- ============================================================================

local canonicalDCE = nil

--- Get the canonical DCE SDK via exports['dce-core']:GetDCEAPI()
function Bootstrap.GetDCE()
    if canonicalDCE then return canonicalDCE end
    local ok, result = pcall(function()
        return exports['dce-core']:GetDCEAPI()
    end)
    if ok and type(result) == "table" then
        canonicalDCE = result
    end
    return canonicalDCE
end

-- ============================================================================
-- Diagnostic Helpers
-- ============================================================================

local function Banner(msg)
    print("^2[DCE Test Suite] " .. tostring(msg) .. "^0")
end

local function Warn(msg)
    print("^3[DCE Test Suite] " .. tostring(msg) .. "^0")
end

local function Error(msg)
    print("^1[DCE Test Suite] " .. tostring(msg) .. "^0")
end

-- ============================================================================
-- Cached Core API (populated via exports, not globals)
-- ============================================================================

local dceCoreResource = "dce-core"

-- ============================================================================
-- Phase 1: Resource State Verification
-- ============================================================================

local function CheckCoreResourceState()
    local coreState = GetResourceState("dce-core")
    Banner("Core resource state: " .. tostring(coreState))

    if coreState ~= "started" then
        Error("FATAL: dce-core is not started (state=" .. tostring(coreState) .. ")")
        Error("Ensure dce-core is listed BEFORE dce-test-suite in server.cfg")
        return false
    end

    return true
end

-- ============================================================================
-- Phase 2: Wait for DCE READY with timeout reporting
-- Uses exports only - the canonical SDK access method.
-- ============================================================================

local function WaitForDCE()
    local timeout = 30000 -- 30 seconds
    local interval = 100 -- check every 100ms
    local reportInterval = 5000 -- report every 5 seconds
    local elapsed = 0
    local lastReport = 0

    Banner("Waiting for DCE Core to reach READY...")
    Banner("Using exports['dce-core']:IsReady() to detect readiness")

    while true do
        Citizen.Wait(interval)
        elapsed = elapsed + interval

        -- Try the canonical SDK method: export IsReady()
        local coreReady = false
        local ok, result = pcall(function()
            return exports[dceCoreResource]:IsReady()
        end)
        if ok and result == true then
            coreReady = true
        end

        -- Fallback: try DCE.IsReady() via GetDCEAPI
        if not coreReady then
            local dce = Bootstrap.GetDCE()
            if dce and type(dce.IsReady) == "function" then
                local ok2, ready = pcall(dce.IsReady)
                if ok2 and ready then
                    coreReady = true
                end
            end
        end

        -- Fallback: try DCE.GetVersion (old-style detection)
        if not coreReady then
            local dce = Bootstrap.GetDCE()
            if dce and type(dce.GetVersion) == "function" then
                coreReady = true
            end
        end

        if coreReady then
            Banner("DCE Core READY detected via SDK!")
            return true
        end

        -- Report progress every 5 seconds
        if elapsed - lastReport >= reportInterval then
            local seconds = math.floor(elapsed / 1000)
            Warn("Waiting for DCE... " .. seconds .. " seconds")

            -- Report detected state via SDK (non-authoritative diagnostic)
            local dce = Bootstrap.GetDCE()
            local components = {
                IsReadyExport = ok or false,
                DCEViaExports = dce ~= nil,
            }

            -- Try to get more diagnostic info if DCE is partially available
            if dce then
                components["DCE.GetVersion"] = type(dce.GetVersion) == "function"
                components["DCE.IsReady"] = type(dce.IsReady) == "function"
                components["DCE.GetService"] = type(dce.GetService) == "function"
            end

            local available = {}
            local missing = {}
            for name, present in pairs(components) do
                if present then
                    table.insert(available, name)
                else
                    table.insert(missing, name)
                end
            end

            Warn("  Available via SDK: " .. table.concat(available, ", "))
            if #missing > 0 then
                Warn("  Not available: " .. table.concat(missing, ", "))
            end

            lastReport = elapsed
        end

        if elapsed >= timeout then
            Error("FATAL: DCE never reached READY after " .. (timeout / 1000) .. " seconds")

            -- Final state dump (diagnostic only)
            Error("Current detected state via SDK:")
            local dce = Bootstrap.GetDCE()
            Error("  [SDK] exports['dce-core']:GetDCEAPI(): " .. (dce ~= nil and "OK" or "FAIL"))
            if dce then
                Error("  [SDK] DCE.GetVersion: " .. (type(dce.GetVersion) == "function" and "OK" or "MISSING"))
                Error("  [SDK] DCE.IsReady: " .. (type(dce.IsReady) == "function" and "OK" or "MISSING"))
                Error("  [SDK] DCE.GetService: " .. (type(dce.GetService) == "function" and "OK" or "MISSING"))
            end

            return false
        end
    end

    return true
end

-- ============================================================================
-- Phase 3: Initialize Harness
-- ============================================================================

local function InitializeHarness()
    local dce = Bootstrap.GetDCE()
    if not dce then
        Error("FATAL: Could not get DCE API even though IsReady returned true")
        return false
    end

    Banner("Core detected via SDK")
    Banner("SDK Version: " .. (dce.GetVersion and dce.GetVersion() or "unknown"))

    -- The harness module is loaded via fxmanifest, so _G.DCETestHarness
    -- should exist. But we verify explicitly.
    if not _G.DCETestHarness then
        Error("FATAL: Test harness (DCETestHarness) not loaded")
        return false
    end

    Bootstrap.harness = _G.DCETestHarness
    Banner("Initializing Harness...")

    -- Validate harness components
    local harness = Bootstrap.harness
    if not harness then
        Error("FATAL: Harness is nil after assignment")
        return false
    end
    local checks = {
        {"Harness exists", true},
        {"Assert function", type(harness.Assert) == "function"},
        {"NewPhaseResult function", type(harness.NewPhaseResult) == "function"},
        {"FinalizePhaseResult function", type(harness.FinalizePhaseResult) == "function"},
        {"GenerateReport function", type(harness.GenerateReport) == "function"},
        {"ValidateSDK function", type(harness.ValidateSDK) == "function"},
    }

    local allValid = true
    for _, check in ipairs(checks) do
        if check[2] then
            Banner("  [OK] " .. check[1])
        else
            Error("  [FAIL] " .. check[1])
            allValid = false
        end
    end

    if not allValid then
        Error("FATAL: Harness validation failed")
        return false
    end

    Banner("Harness Initialized")
    return true
end

-- ============================================================================
-- Phase 4: Register Phase Modules (Explicit Registration)
-- ============================================================================

local function RegisterPhases()
    Banner("Registering Phases...")

    -- Explicit phase registration table
    -- Each entry: { name, globalKey }
    -- The global is set by the phase file when loaded via fxmanifest
    local phaseDefinitions = {
        { name = "Phase 1: SDK Stress Testing",         key = "DCEPhase1" },
        { name = "Phase 2: Plugin Stress Testing",       key = "DCEPhase2" },
        { name = "Phase 3: Event Bus Load Testing",      key = "DCEPhase3" },
        { name = "Phase 4: Scheduler & Runtime Validation", key = "DCEPhase4" },
        { name = "Phase 5: Registry Integrity",          key = "DCEPhase5" },
        { name = "Phase 6: Memory Validation",           key = "DCEPhase6" },
        { name = "Phase 7: Failure Injection",           key = "DCEPhase7" },
        { name = "Phase 8: Startup Scalability",         key = "DCEPhase8" },
        { name = "Phase 9: SDK Documentation Validation", key = "DCEPhase9" },
        { name = "Phase 10: Platform Certification",     key = "DCEPhase10" },
    }

    local registered = 0
    local failed = 0

    for _, def in ipairs(phaseDefinitions) do
        local phaseModule = _G[def.key]
        if phaseModule and type(phaseModule.Run) == "function" then
            table.insert(Bootstrap.phaseModules, {
                name = def.name,
                module = phaseModule,
            })
            registered = registered + 1
            Banner("  [OK] " .. def.name)
        else
            Error("  [FAIL] " .. def.name .. " (module not found or missing Run function)")
            failed = failed + 1
        end
    end

    Banner(registered .. " phases registered" .. (failed > 0 and (", " .. failed .. " failed") or ""))

    if registered == 0 then
        Error("FATAL: No phases registered")
        return false
    end

    return true
end

-- ============================================================================
-- Phase 5: Run All Phases
-- ============================================================================

local function RunAllPhases()
    Banner("Beginning validation...")

    for _, phaseDef in ipairs(Bootstrap.phaseModules) do
        Banner("=== " .. phaseDef.name .. " ===")

        local ok, phaseResults = pcall(phaseDef.module.Run, Bootstrap)
        if ok then
            table.insert(Bootstrap.phaseResults, phaseResults)
            Bootstrap.results.passed = Bootstrap.results.passed + (phaseResults.passed or 0)
            Bootstrap.results.failed = Bootstrap.results.failed + (phaseResults.failed or 0)
            Bootstrap.results.skipped = Bootstrap.results.skipped + (phaseResults.skipped or 0)
            Banner("Phase completed: " .. phaseDef.name)
        else
            table.insert(Bootstrap.results.errors, phaseDef.name .. ": " .. tostring(phaseResults))
            Error("Phase FAILED: " .. phaseDef.name .. " - " .. tostring(phaseResults))
            Bootstrap.results.failed = Bootstrap.results.failed + 1
        end
    end
end

-- ============================================================================
-- Phase 6: Generate Reports
-- ============================================================================

local function GenerateReports()
    if Bootstrap.harness and Bootstrap.harness.GenerateReport then
        Bootstrap.harness.GenerateReport(Bootstrap)
    end
end

-- ============================================================================
-- Phase 7: Print Final Summary
-- ============================================================================

local function PrintSummary()
    Banner("========================================")
    Banner("Validation Complete")
    Banner("Passed: " .. Bootstrap.results.passed)
    Banner("Failed: " .. Bootstrap.results.failed)
    Banner("Skipped: " .. Bootstrap.results.skipped)
    if #Bootstrap.results.errors > 0 then
        Error("Errors: " .. #Bootstrap.results.errors)
        for _, e in ipairs(Bootstrap.results.errors) do
            Error("  - " .. tostring(e))
        end
    end
    Banner("========================================")
end

-- ============================================================================
-- Bootstrap Thread — Single Authoritative Entry Point
-- ============================================================================

local function BootstrapSuite()
    Banner("========================================")
    Banner("DCE Sprint 1.10 — Platform Validation")
    Banner("========================================")
    Banner("Resource Loaded")
    Banner("Bootstrap Thread Started")

    -- Step 1: Verify dce-core resource state
    if not CheckCoreResourceState() then
        return
    end

    -- Step 2: Wait for DCE to reach READY via SDK exports
    if not WaitForDCE() then
        return
    end

    -- Step 3: Initialize the test harness
    if not InitializeHarness() then
        return
    end

    -- Step 4: Register all phase modules explicitly
    if not RegisterPhases() then
        return
    end

    -- Step 5: Run SDK validation as a pre-check
    Banner("SDK Validation...")
    local sdkResults = Bootstrap.harness.ValidateSDK()
    if sdkResults then
        Banner("SDK Baseline: " .. sdkResults.passed .. " passed, " .. sdkResults.failed .. " failed")
    end

    -- Step 6: Run all test phases
    RunAllPhases()

    -- Step 7: Generate certification reports
    GenerateReports()

    -- Step 8: Print final summary
    PrintSummary()

    Banner("Finished")
end

-- ============================================================================
-- Startup — Create the bootstrap thread
-- ============================================================================

-- Use an explicit runtime thread. No reliance on module loading side effects.
Citizen.CreateThread(function()
    -- Small initial delay to ensure the runtime is settled
    Citizen.Wait(0)

    local ok, err = pcall(BootstrapSuite)
    if not ok then
        Error("FATAL: Bootstrap crashed: " .. tostring(err))
        Error("Stack trace:")
        Error(debug and debug.traceback and debug.traceback() or "unavailable")
    end
end)

-- ============================================================================
-- Expose the bootstrap table globally for diagnostics
-- ============================================================================

_G.DCETestSuite = Bootstrap

return Bootstrap